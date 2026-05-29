"""Integration tests for asset management flow."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestAssetManagementFlow:
    """Test complete asset lifecycle through the API."""

    async def _setup_family(self, client: AsyncClient) -> tuple[dict, str]:
        """Helper to create a user and family, return (tokens, family_id)."""
        await client.post("/api/auth/register", json={
            "username": "assetuser",
            "email": "asset@example.com",
            "password": "TestPass123",
            "full_name": "Asset User",
        })
        login_resp = await client.post("/api/auth/login", json={
            "identifier": "assetuser",
            "password": "TestPass123",
        })
        tokens = login_resp.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        family_resp = await client.post("/api/families", json={
            "name": "资产测试家庭",
        }, headers=headers)
        family_id = family_resp.json()["data"]["id"]

        return tokens, family_id

    async def test_create_asset_with_metadata(self, client: AsyncClient):
        """Create a vehicle asset with type-specific metadata."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        response = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "2024 Toyota Camry",
            "nature": "tangible",
            "utility": "essential",
            "ownership": "owned",
            "liquidity": "low",
            "purchase_price": 200000,
            "purchase_date": "2024-01-15T00:00:00",
            "currency": "CNY",
            "tags": ["车辆", "通勤"],
            "metadata_type": "vehicle",
            "metadata": {
                "type": "car",
                "make": "Toyota",
                "model": "Camry",
                "year": 2024,
                "mileage": 12000,
                "fuel_type": "hybrid",
            },
        }, headers=headers)

        assert response.status_code == 201
        asset = response.json()["data"]
        assert asset["name"] == "2024 Toyota Camry"
        assert asset["nature"] == "tangible"
        assert asset["tags"] == ["车辆", "通勤"]
        assert asset["financial"]["purchase_price"] == 200000

    async def test_create_financial_asset(self, client: AsyncClient):
        """Create a stock asset with financial metadata."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        response = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "贵州茅台",
            "nature": "financial",
            "utility": "speculative",
            "ownership": "custodied",
            "liquidity": "high",
            "purchase_price": 180000,
            "tags": ["A股", "白酒"],
            "metadata_type": "financial",
            "metadata": {
                "instrument_type": "stock",
                "ticker": "600519.SH",
                "exchange": "SSE",
                "shares": 100,
                "average_cost_basis": 1800,
                "current_price": 1888,
                "price_currency": "CNY",
            },
        }, headers=headers)

        assert response.status_code == 201
        asset = response.json()["data"]
        assert asset["nature"] == "financial"
        assert asset["liquidity"] == "high"

    async def test_create_consumable_asset(self, client: AsyncClient):
        """Create a consumable asset."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        response = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "维达抽纸",
            "nature": "tangible",
            "utility": "consumable",
            "ownership": "owned",
            "liquidity": "instant",
            "purchase_price": 29.9,
            "tags": ["日用品", "消耗品"],
            "metadata_type": "consumable",
            "metadata": {
                "type": "hygiene",
                "brand": "维达",
                "initial_quantity": 24,
                "current_quantity": 24,
                "unit": "包",
                "cost_per_unit": 1.25,
                "reorder_threshold": 6,
            },
        }, headers=headers)

        assert response.status_code == 201
        assert response.json()["data"]["nature"] == "tangible"

    async def test_list_assets_with_filters(self, client: AsyncClient):
        """List assets with various filters."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create multiple assets
        assets_data = [
            {"name": "Car", "nature": "tangible", "utility": "essential", "ownership": "owned", "liquidity": "low"},
            {"name": "Stock", "nature": "financial", "utility": "speculative", "ownership": "custodied", "liquidity": "high"},
            {"name": "Netflix", "nature": "service", "utility": "lifestyle", "ownership": "subscribed", "liquidity": "instant"},
        ]
        for data in assets_data:
            await client.post(f"/api/families/{family_id}/assets", json=data, headers=headers)

        # Filter by nature
        resp = await client.get(
            f"/api/families/{family_id}/assets?nature=tangible",
            headers=headers,
        )
        assert resp.status_code == 200
        assets = resp.json()["data"]["assets"]
        assert all(a["nature"] == "tangible" for a in assets)

        # Filter by liquidity
        resp = await client.get(
            f"/api/families/{family_id}/assets?liquidity=high",
            headers=headers,
        )
        assert resp.status_code == 200
        assets = resp.json()["data"]["assets"]
        assert all(a["liquidity"] == "high" for a in assets)

        # Search by name
        resp = await client.get(
            f"/api/families/{family_id}/assets?search=Netflix",
            headers=headers,
        )
        assert resp.status_code == 200
        assets = resp.json()["data"]["assets"]
        assert len(assets) == 1
        assert assets[0]["name"] == "Netflix"

    async def test_asset_update_and_archive(self, client: AsyncClient):
        """Update asset and then archive it."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create
        create_resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "To Update",
            "nature": "tangible",
            "utility": "lifestyle",
            "ownership": "owned",
            "liquidity": "medium",
        }, headers=headers)
        asset_id = create_resp.json()["data"]["id"]

        # Update
        update_resp = await client.put(
            f"/api/families/{family_id}/assets/{asset_id}",
            json={"name": "Updated Name", "tags": ["updated"]},
            headers=headers,
        )
        assert update_resp.status_code == 200
        assert update_resp.json()["data"]["name"] == "Updated Name"

        # Archive
        delete_resp = await client.delete(
            f"/api/families/{family_id}/assets/{asset_id}",
            headers=headers,
        )
        assert delete_resp.status_code == 200

        # Verify archived (default list only shows active)
        list_resp = await client.get(f"/api/families/{family_id}/assets", headers=headers)
        assets = list_resp.json()["data"]["assets"]
        assert all(a["id"] != asset_id for a in assets)

    async def test_asset_stats(self, client: AsyncClient):
        """Get asset statistics."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create assets with different classifications
        await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Tangible 1", "nature": "tangible", "utility": "essential",
            "ownership": "owned", "liquidity": "low", "purchase_price": 100000,
        }, headers=headers)
        await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Financial 1", "nature": "financial", "utility": "speculative",
            "ownership": "custodied", "liquidity": "high", "purchase_price": 50000,
        }, headers=headers)

        stats_resp = await client.get(f"/api/families/{family_id}/assets/stats", headers=headers)
        assert stats_resp.status_code == 200
        stats = stats_resp.json()["data"]
        assert stats["total_count"] == 2
        assert stats["total_value"] == 150000
        assert "tangible" in stats["by_nature"]
        assert "financial" in stats["by_nature"]

    async def test_tag_management(self, client: AsyncClient):
        """Add and remove tags."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create asset
        create_resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Taggable", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "medium",
        }, headers=headers)
        asset_id = create_resp.json()["data"]["id"]

        # Add tag
        add_resp = await client.post(
            f"/api/families/{family_id}/assets/{asset_id}/tags",
            json={"tag": "重要"},
            headers=headers,
        )
        assert add_resp.status_code == 200

        # Get tags list
        tags_resp = await client.get(f"/api/families/{family_id}/assets/tags", headers=headers)
        assert tags_resp.status_code == 200
        tags = tags_resp.json()["data"]
        assert any(t["tag"] == "重要" for t in tags)

        # Remove tag
        del_resp = await client.delete(
            f"/api/families/{family_id}/assets/{asset_id}/tags/重要",
            headers=headers,
        )
        assert del_resp.status_code == 200

    async def test_bulk_archive(self, client: AsyncClient):
        """Bulk archive multiple assets."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create 3 assets
        ids = []
        for i in range(3):
            resp = await client.post(f"/api/families/{family_id}/assets", json={
                "name": f"Bulk {i}", "nature": "tangible", "utility": "lifestyle",
                "ownership": "owned", "liquidity": "medium",
            }, headers=headers)
            ids.append(resp.json()["data"]["id"])

        # Bulk archive
        bulk_resp = await client.post(f"/api/families/{family_id}/assets/bulk", json={
            "asset_ids": ids,
            "action": "archive",
        }, headers=headers)
        assert bulk_resp.status_code == 200
        assert bulk_resp.json()["data"]["success_count"] == 3

    async def test_duplicate_detection(self, client: AsyncClient):
        """Creating duplicate asset should be rejected."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        asset_data = {
            "name": "Same Name",
            "nature": "tangible",
            "utility": "lifestyle",
            "ownership": "owned",
            "liquidity": "medium",
        }

        # First creation should succeed
        resp1 = await client.post(f"/api/families/{family_id}/assets", json=asset_data, headers=headers)
        assert resp1.status_code == 201

        # Second creation with same name+nature should fail
        resp2 = await client.post(f"/api/families/{family_id}/assets", json=asset_data, headers=headers)
        assert resp2.status_code == 409

    async def test_relationship_crud(self, client: AsyncClient):
        """Create and query asset relationships."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create two assets
        resp1 = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "TV", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "low",
        }, headers=headers)
        tv_id = resp1.json()["data"]["id"]

        resp2 = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Remote", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "low",
        }, headers=headers)
        remote_id = resp2.json()["data"]["id"]

        # Create relationship: Remote requires TV
        rel_resp = await client.post(
            f"/api/families/{family_id}/assets/{remote_id}/relationships",
            json={
                "target_asset_id": tv_id,
                "type": "requires",
                "is_optional": False,
                "lifecycle_linked": True,
            },
            headers=headers,
        )
        assert rel_resp.status_code == 201

        # Query relationships
        get_resp = await client.get(
            f"/api/families/{family_id}/assets/{remote_id}/relationships",
            headers=headers,
        )
        assert get_resp.status_code == 200
        rels = get_resp.json()["data"]
        assert len(rels) == 1
        assert rels[0]["type"] == "requires"

        # Get relationship graph
        graph_resp = await client.get(
            f"/api/families/{family_id}/assets/relationship-graph",
            headers=headers,
        )
        assert graph_resp.status_code == 200
        graph = graph_resp.json()["data"]
        assert graph["node_count"] == 2
        assert graph["edge_count"] == 1

    async def test_lifecycle_computation(self, client: AsyncClient):
        """Get lifecycle computation for a depreciating asset."""
        tokens, family_id = await self._setup_family(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create a depreciating asset
        create_resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Depreciating Car",
            "nature": "tangible",
            "utility": "essential",
            "ownership": "owned",
            "liquidity": "low",
            "purchase_price": 200000,
            "purchase_date": "2024-01-15T00:00:00",
        }, headers=headers)
        asset_id = create_resp.json()["data"]["id"]

        # Get lifecycle
        lc_resp = await client.get(
            f"/api/families/{family_id}/assets/{asset_id}/lifecycle",
            headers=headers,
        )
        assert lc_resp.status_code == 200
        lc = lc_resp.json()["data"]
        assert lc["trajectory"] == "depreciating"
        assert lc["purchase_price"] == 200000
        assert "computed_value" in lc

    async def test_cross_family_isolation(self, client: AsyncClient):
        """Users should only see assets from their own families."""
        # User 1 creates family 1 with asset
        await client.post("/api/auth/register", json={
            "username": "user1_iso", "email": "u1@example.com",
            "password": "TestPass123", "full_name": "User 1",
        })
        login1 = await client.post("/api/auth/login", json={
            "identifier": "user1_iso", "password": "TestPass123",
        })
        tokens1 = login1.json()["data"]
        headers1 = {"Authorization": f"Bearer {tokens1['access_token']}"}

        family1_resp = await client.post("/api/families", json={"name": "Family 1"}, headers=headers1)
        family1_id = family1_resp.json()["data"]["id"]

        await client.post(f"/api/families/{family1_id}/assets", json={
            "name": "Private Asset", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "medium",
        }, headers=headers1)

        # User 2 creates family 2
        await client.post("/api/auth/register", json={
            "username": "user2_iso", "email": "u2@example.com",
            "password": "TestPass123", "full_name": "User 2",
        })
        login2 = await client.post("/api/auth/login", json={
            "identifier": "user2_iso", "password": "TestPass123",
        })
        tokens2 = login2.json()["data"]
        headers2 = {"Authorization": f"Bearer {tokens2['access_token']}"}

        family2_resp = await client.post("/api/families", json={"name": "Family 2"}, headers=headers2)
        family2_id = family2_resp.json()["data"]["id"]

        # User 2 should NOT see User 1's assets
        resp = await client.get(f"/api/families/{family1_id}/assets", headers=headers2)
        assert resp.status_code == 403

        # User 2's family should be empty
        resp2 = await client.get(f"/api/families/{family2_id}/assets", headers=headers2)
        assert resp2.status_code == 200
        assert resp2.json()["data"]["total"] == 0
