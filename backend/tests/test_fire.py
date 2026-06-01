"""Tests for FIRE calculation engine."""

import pytest

from app.finance.fire_service import run_monte_carlo


class TestMonteCarlo:
    def test_already_at_fire(self):
        result = run_monte_carlo(
            net_worth=1000000,
            annual_savings=50000,
            fire_number=800000,
        )
        assert result["success_rate"] == 1.0
        assert result["median_years"] == 0

    def test_needs_saving(self):
        result = run_monte_carlo(
            net_worth=100000,
            annual_savings=50000,
            fire_number=1000000,
            expected_return=0.07,
            volatility=0.15,
            simulations=500,
        )
        assert 0 < result["success_rate"] <= 1
        assert result["median_years"] > 0

    def test_paths_generated(self):
        result = run_monte_carlo(
            net_worth=50000,
            annual_savings=30000,
            fire_number=500000,
            simulations=100,
        )
        assert len(result["sample_paths"]) <= 20

    def test_percentile_ordering(self):
        result = run_monte_carlo(
            net_worth=100000,
            annual_savings=40000,
            fire_number=800000,
            simulations=500,
        )
        if result["success_rate"] < 1.0:
            assert result["p10_years"] <= result["median_years"]
            assert result["median_years"] <= result["p90_years"]


@pytest.mark.asyncio
class TestFIREIntegration:
    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "fireuser", "email": "fire@example.com",
            "password": "TestPass123", "full_name": "Fire User",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "fireuser", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "FIRE家庭"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]

        # Add some assets
        await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Stock Portfolio", "nature": "financial", "utility": "productive",
            "ownership": "custodied", "liquidity": "high", "purchase_price": 500000,
        }, headers=headers)
        await client.post(f"/api/families/{family_id}/assets", json={
            "name": "House", "nature": "tangible", "utility": "essential",
            "ownership": "owned", "liquidity": "low", "purchase_price": 2000000,
        }, headers=headers)

        # Add income
        await client.post(f"/api/families/{family_id}/finance/income-expense", json={
            "type": "income", "amount": 30000, "date": "2026-05-01T00:00:00", "description": "工资",
        }, headers=headers)

        return headers, family_id

    async def test_fire_snapshot(self, client):
        headers, family_id = await self._setup(client)
        resp = await client.get(f"/api/families/{family_id}/finance/fire/snapshot", headers=headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert "net_worth" in data
        assert "fire_number" in data
        assert "fi_ratio" in data
        assert "years_to_fire" in data
        assert "savings_rate" in data

    async def test_net_worth(self, client):
        headers, family_id = await self._setup(client)
        resp = await client.get(f"/api/families/{family_id}/finance/fire/net-worth", headers=headers)
        assert resp.status_code == 200
        nw = resp.json()["data"]
        # net-worth 端点返回所有资产的净资产
        assert nw["total_assets"] == 2500000
        assert nw["net_worth"] == 2500000

    async def test_allocation(self, client):
        headers, family_id = await self._setup(client)
        resp = await client.get(f"/api/families/{family_id}/finance/fire/allocation", headers=headers)
        assert resp.status_code == 200
        allocation = resp.json()["data"]
        # 只包含金融资产，按工具类型分组（测试中无 metadata，归为 other）
        assert "other" in allocation

    async def test_monte_carlo_endpoint(self, client):
        headers, family_id = await self._setup(client)
        resp = await client.post(f"/api/families/{family_id}/finance/fire/monte-carlo", json={
            "fire_number": 5000000,
            "expected_return": 0.07,
            "volatility": 0.15,
            "simulations": 100,
        }, headers=headers)
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert "success_rate" in data
        assert "median_years" in data
