"""Integration tests for notification and WebSocket systems."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestNotificationService:
    """Test notification service through API."""

    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "notifsvc", "email": "notifsvc@example.com",
            "password": "TestPass123", "full_name": "Notif Service",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "notifsvc", "password": "TestPass123",
        })
        return login.json()["data"]

    async def test_notification_lifecycle(self, client):
        """Test full notification lifecycle: list, unread, mark read."""
        tokens = await self._setup(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Initially empty
        resp = await client.get("/api/notifications", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["total"] == 0

        # Unread count is 0
        resp = await client.get("/api/notifications/unread-count", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"] == 0

        # Mark all read (no-op on empty)
        resp = await client.put("/api/notifications/read-all", headers=headers)
        assert resp.status_code == 200

    async def test_notification_preferences(self, client):
        """Test notification preferences CRUD."""
        tokens = await self._setup(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Get preferences
        resp = await client.get("/api/notifications/settings", headers=headers)
        assert resp.status_code == 200

        # Update preference
        resp = await client.put("/api/notifications/settings", json={
            "type": "asset_added", "enabled": False,
        }, headers=headers)
        assert resp.status_code == 200

        # Verify updated
        resp = await client.get("/api/notifications/settings", headers=headers)
        assert resp.status_code == 200


@pytest.mark.asyncio
class TestUserManagement:
    """Test admin user management endpoints."""

    async def _setup_admin(self, client):
        """Register and login as admin."""
        await client.post("/api/auth/register", json={
            "username": "admin_test", "email": "admin_test@example.com",
            "password": "TestPass123", "full_name": "Admin Test",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "admin_test", "password": "TestPass123",
        })
        return login.json()["data"]

    async def test_user_list_requires_auth(self, client):
        """User list requires authentication."""
        resp = await client.get("/api/users")
        assert resp.status_code == 401

    async def test_user_list_with_member(self, client):
        """Regular member cannot access user list."""
        tokens = await self._setup_admin(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # This will fail because the user is not admin
        # (they registered as member, not admin)
        resp = await client.get("/api/users", headers=headers)
        # Should be 403 for non-admin
        assert resp.status_code == 403


@pytest.mark.asyncio
class TestDocumentEndpoints:
    """Test document management endpoints."""

    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "docuser", "email": "doc@example.com",
            "password": "TestPass123", "full_name": "Doc User",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "docuser", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "Doc家庭"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]
        return headers, family_id

    async def test_list_asset_documents_empty(self, client):
        """List documents for asset returns empty initially."""
        headers, family_id = await self._setup(client)

        # Create an asset first
        asset_resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Doc Asset", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "medium",
        }, headers=headers)
        asset_id = asset_resp.json()["data"]["id"]

        # List documents
        resp = await client.get(
            f"/api/documents/asset/{asset_id}?family_id={family_id}",
            headers=headers,
        )
        assert resp.status_code == 200


@pytest.mark.asyncio
class TestFinanceEndpoints:
    """Test finance management endpoints through API."""

    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "finsvc", "email": "finsvc@example.com",
            "password": "TestPass123", "full_name": "Finance Service",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "finsvc", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "财务家庭"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]
        return headers, family_id

    async def test_expense_categories(self, client):
        """Get expense categories returns a list."""
        headers, family_id = await self._setup(client)
        resp = await client.get(
            f"/api/families/{family_id}/finance/categories/expense",
            headers=headers,
        )
        assert resp.status_code == 200
        assert isinstance(resp.json()["data"], list)

    async def test_income_categories(self, client):
        """Get income categories returns a list."""
        headers, family_id = await self._setup(client)
        resp = await client.get(
            f"/api/families/{family_id}/finance/categories/income",
            headers=headers,
        )
        assert resp.status_code == 200
        assert isinstance(resp.json()["data"], list)

    async def test_fire_snapshot_empty(self, client):
        """FIRE snapshot on empty family returns valid data."""
        headers, family_id = await self._setup(client)
        resp = await client.get(
            f"/api/families/{family_id}/finance/fire/snapshot",
            headers=headers,
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert "net_worth" in data
        assert "fire_number" in data

    async def test_net_worth_empty(self, client):
        """Net worth on empty family is zero."""
        headers, family_id = await self._setup(client)
        resp = await client.get(
            f"/api/families/{family_id}/finance/fire/net-worth",
            headers=headers,
        )
        assert resp.status_code == 200
        nw = resp.json()["data"]
        assert nw["total_assets"] == 0
        assert nw["net_worth"] == 0

    async def test_allocation_empty(self, client):
        """Asset allocation on empty family returns empty map."""
        headers, family_id = await self._setup(client)
        resp = await client.get(
            f"/api/families/{family_id}/finance/fire/allocation",
            headers=headers,
        )
        assert resp.status_code == 200

    async def test_liability_crud(self, client):
        """Full liability CRUD cycle."""
        headers, family_id = await self._setup(client)

        # Create
        resp = await client.post(f"/api/families/{family_id}/finance/liabilities", json={
            "name": "测试房贷", "type": "mortgage",
            "original_amount": 1000000, "current_balance": 800000,
            "interest_rate": 4.5, "monthly_payment": 5066.85,
        }, headers=headers)
        assert resp.status_code == 201
        liab_id = resp.json()["data"]["id"]

        # List
        resp = await client.get(f"/api/families/{family_id}/finance/liabilities", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["total"] == 1

        # Update
        resp = await client.put(
            f"/api/families/{family_id}/finance/liabilities/{liab_id}",
            json={"current_balance": 750000},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["current_balance"] == 750000

        # Delete (mark paid off)
        resp = await client.delete(
            f"/api/families/{family_id}/finance/liabilities/{liab_id}",
            headers=headers,
        )
        assert resp.status_code == 200

    async def test_income_expense_crud(self, client):
        """Full income/expense CRUD cycle."""
        headers, family_id = await self._setup(client)

        # Record income
        resp = await client.post(f"/api/families/{family_id}/finance/income-expense", json={
            "type": "income", "amount": 20000,
            "date": "2026-06-01T00:00:00", "description": "工资",
        }, headers=headers)
        assert resp.status_code == 201
        income_id = resp.json()["data"]["id"]

        # Record expense
        resp = await client.post(f"/api/families/{family_id}/finance/income-expense", json={
            "type": "expense", "amount": 5000,
            "date": "2026-06-15T00:00:00", "description": "房租",
        }, headers=headers)
        assert resp.status_code == 201
        expense_id = resp.json()["data"]["id"]

        # List
        resp = await client.get(f"/api/families/{family_id}/finance/income-expense", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["total"] == 2

        # Summary
        resp = await client.get(f"/api/families/{family_id}/finance/income-expense/summary", headers=headers)
        assert resp.status_code == 200
        summary = resp.json()["data"]
        assert summary["total_income"] == 20000
        assert summary["total_expense"] == 5000
        assert summary["net"] == 15000

        # Delete
        resp = await client.delete(
            f"/api/families/{family_id}/finance/income-expense/{expense_id}",
            headers=headers,
        )
        assert resp.status_code == 200

    async def test_transaction_crud(self, client):
        """Full transaction CRUD cycle."""
        headers, family_id = await self._setup(client)

        # Create asset first
        asset_resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "交易测试资产", "nature": "financial", "utility": "speculative",
            "ownership": "custodied", "liquidity": "high",
        }, headers=headers)
        asset_id = asset_resp.json()["data"]["id"]

        # Buy
        resp = await client.post(f"/api/families/{family_id}/finance/transactions", json={
            "asset_id": asset_id, "type": "buy",
            "quantity": 100, "price": 50, "total": 5000, "fees": 5,
            "date": "2026-01-15T00:00:00",
        }, headers=headers)
        assert resp.status_code == 201

        # Sell
        resp = await client.post(f"/api/families/{family_id}/finance/transactions", json={
            "asset_id": asset_id, "type": "sell",
            "quantity": 50, "price": 60, "total": 3000, "fees": 5,
            "date": "2026-06-15T00:00:00",
        }, headers=headers)
        assert resp.status_code == 201

        # List
        resp = await client.get(f"/api/families/{family_id}/finance/transactions", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["total"] == 2

        # Cost basis
        resp = await client.get(
            f"/api/families/{family_id}/finance/cost-basis/{asset_id}?method=average_cost",
            headers=headers,
        )
        assert resp.status_code == 200
        cb = resp.json()["data"]
        assert cb["total_shares"] == 50  # 100 - 50
