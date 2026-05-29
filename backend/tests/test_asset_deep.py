"""Tests for asset service and router (high coverage)."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestAssetServiceDeep:
    """Deep integration tests for asset management."""

    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "deepasset", "email": "deepasset@example.com",
            "password": "TestPass123", "full_name": "Deep Asset",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "deepasset", "password": "TestPass123",
        })
        tokens = login.json()["data"]
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}
        family_resp = await client.post("/api/families", json={"name": "深度测试"}, headers=headers)
        family_id = family_resp.json()["data"]["id"]
        return headers, family_id

    async def test_create_all_asset_types(self, client):
        """Create assets of each nature type."""
        headers, family_id = await self._setup(client)

        types = [
            ("tangible", "essential", "owned", "low"),
            ("financial", "speculative", "custodied", "high"),
            ("digital", "lifestyle", "licensed", "medium"),
            ("service", "lifestyle", "subscribed", "instant"),
            ("intangible", "protective", "owned", "fixed"),
        ]

        for nature, utility, ownership, liquidity in types:
            resp = await client.post(f"/api/families/{family_id}/assets", json={
                "name": f"Test {nature}",
                "nature": nature,
                "utility": utility,
                "ownership": ownership,
                "liquidity": liquidity,
                "purchase_price": 1000,
            }, headers=headers)
            assert resp.status_code == 201

        # List all
        resp = await client.get(f"/api/families/{family_id}/assets", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["total"] == 5

    async def test_asset_filtering(self, client):
        """Test all filter combinations."""
        headers, family_id = await self._setup(client)

        # Create diverse assets
        for i, nature in enumerate(["tangible", "financial", "service"]):
            await client.post(f"/api/families/{family_id}/assets", json={
                "name": f"Filter {i}", "nature": nature,
                "utility": "lifestyle", "ownership": "owned", "liquidity": "medium",
            }, headers=headers)

        # Filter by nature
        for nature in ["tangible", "financial", "service"]:
            resp = await client.get(
                f"/api/families/{family_id}/assets?nature={nature}",
                headers=headers,
            )
            assert resp.status_code == 200
            assets = resp.json()["data"]["assets"]
            assert all(a["nature"] == nature for a in assets)

    async def test_asset_search(self, client):
        """Test search functionality."""
        headers, family_id = await self._setup(client)

        await client.post(f"/api/families/{family_id}/assets", json={
            "name": "MacBook Pro", "nature": "tangible",
            "utility": "lifestyle", "ownership": "owned", "liquidity": "medium",
        }, headers=headers)
        await client.post(f"/api/families/{family_id}/assets", json={
            "name": "iPhone 15", "nature": "tangible",
            "utility": "lifestyle", "ownership": "owned", "liquidity": "medium",
        }, headers=headers)

        # Search
        resp = await client.get(
            f"/api/families/{family_id}/assets?search=MacBook",
            headers=headers,
        )
        assert resp.status_code == 200
        assets = resp.json()["data"]["assets"]
        assert len(assets) == 1
        assert "MacBook" in assets[0]["name"]

    async def test_asset_update(self, client):
        """Test asset update."""
        headers, family_id = await self._setup(client)

        resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Original", "nature": "tangible",
            "utility": "lifestyle", "ownership": "owned", "liquidity": "medium",
        }, headers=headers)
        asset_id = resp.json()["data"]["id"]

        # Update
        resp = await client.put(
            f"/api/families/{family_id}/assets/{asset_id}",
            json={"name": "Updated", "tags": ["new-tag"]},
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["name"] == "Updated"

    async def test_asset_archive_and_stats(self, client):
        """Test archive and stats update."""
        headers, family_id = await self._setup(client)

        # Create 2 assets
        resp1 = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Keep", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "medium", "purchase_price": 1000,
        }, headers=headers)
        resp2 = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Archive", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "medium", "purchase_price": 2000,
        }, headers=headers)

        # Stats before
        resp = await client.get(f"/api/families/{family_id}/assets/stats", headers=headers)
        assert resp.json()["data"]["total_count"] == 2

        # Archive one
        asset_id = resp2.json()["data"]["id"]
        await client.delete(f"/api/families/{family_id}/assets/{asset_id}", headers=headers)

        # Stats after
        resp = await client.get(f"/api/families/{family_id}/assets/stats", headers=headers)
        assert resp.json()["data"]["total_count"] == 1

    async def test_tag_operations(self, client):
        """Test tag add/remove/list."""
        headers, family_id = await self._setup(client)

        resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Taggable", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "medium",
        }, headers=headers)
        asset_id = resp.json()["data"]["id"]

        # Add tags
        for tag in ["重要", "通勤", "电子"]:
            resp = await client.post(
                f"/api/families/{family_id}/assets/{asset_id}/tags",
                json={"tag": tag},
                headers=headers,
            )
            assert resp.status_code == 200

        # Get asset detail and verify tags
        resp = await client.get(
            f"/api/families/{family_id}/assets/{asset_id}",
            headers=headers,
        )
        assert resp.status_code == 200
        tags = resp.json()["data"].get("tags") or []
        assert len(tags) >= 1  # At least 1 tag added

        # Remove tag
        resp = await client.delete(
            f"/api/families/{family_id}/assets/{asset_id}/tags/重要",
            headers=headers,
        )
        assert resp.status_code == 200

    async def test_bulk_operations(self, client):
        """Test bulk archive and tag."""
        headers, family_id = await self._setup(client)

        ids = []
        for i in range(3):
            resp = await client.post(f"/api/families/{family_id}/assets", json={
                "name": f"Bulk {i}", "nature": "tangible", "utility": "lifestyle",
                "ownership": "owned", "liquidity": "medium",
            }, headers=headers)
            ids.append(resp.json()["data"]["id"])

        # Bulk tag
        resp = await client.post(f"/api/families/{family_id}/assets/bulk", json={
            "asset_ids": ids, "action": "tag", "tag": "批量标签",
        }, headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["success_count"] == 3

        # Bulk archive
        resp = await client.post(f"/api/families/{family_id}/assets/bulk", json={
            "asset_ids": ids[:2], "action": "archive",
        }, headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["success_count"] == 2

    async def test_lifecycle_endpoint(self, client):
        """Test lifecycle information endpoint."""
        headers, family_id = await self._setup(client)

        resp = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Lifecycle Test", "nature": "tangible", "utility": "essential",
            "ownership": "owned", "liquidity": "low",
            "purchase_price": 100000, "purchase_date": "2024-01-15T00:00:00",
        }, headers=headers)
        asset_id = resp.json()["data"]["id"]

        # Get lifecycle
        resp = await client.get(
            f"/api/families/{family_id}/assets/{asset_id}/lifecycle",
            headers=headers,
        )
        assert resp.status_code == 200
        lc = resp.json()["data"]
        assert lc["trajectory"] == "depreciating"
        assert lc["purchase_price"] == 100000

    async def test_relationship_crud(self, client):
        """Test relationship create and query."""
        headers, family_id = await self._setup(client)

        # Create 2 assets
        r1 = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "TV", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "low",
        }, headers=headers)
        r2 = await client.post(f"/api/families/{family_id}/assets", json={
            "name": "Remote", "nature": "tangible", "utility": "lifestyle",
            "ownership": "owned", "liquidity": "low",
        }, headers=headers)
        tv_id = r1.json()["data"]["id"]
        remote_id = r2.json()["data"]["id"]

        # Create relationship
        resp = await client.post(
            f"/api/families/{family_id}/assets/{remote_id}/relationships",
            json={"target_asset_id": tv_id, "type": "requires"},
            headers=headers,
        )
        assert resp.status_code == 201

        # Query relationships
        resp = await client.get(
            f"/api/families/{family_id}/assets/{remote_id}/relationships",
            headers=headers,
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]) == 1

        # Relationship graph
        resp = await client.get(
            f"/api/families/{family_id}/assets/relationship-graph",
            headers=headers,
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["node_count"] == 2

    async def test_relationship_types(self, client):
        """Get available relationship types."""
        resp = await client.get("/api/families/test/assets/relationship-types")
        assert resp.status_code == 200
        types = resp.json()["data"]
        assert len(types) == 10

    async def test_cross_family_isolation(self, client):
        """Users cannot access other families' assets."""
        # User 1
        await client.post("/api/auth/register", json={
            "username": "iso1", "email": "iso1@example.com",
            "password": "TestPass123", "full_name": "ISO 1",
        })
        login1 = await client.post("/api/auth/login", json={
            "identifier": "iso1", "password": "TestPass123",
        })
        h1 = {"Authorization": f"Bearer {login1.json()['data']['access_token']}"}
        f1 = await client.post("/api/families", json={"name": "F1"}, headers=h1)
        f1_id = f1.json()["data"]["id"]

        # User 2
        await client.post("/api/auth/register", json={
            "username": "iso2", "email": "iso2@example.com",
            "password": "TestPass123", "full_name": "ISO 2",
        })
        login2 = await client.post("/api/auth/login", json={
            "identifier": "iso2", "password": "TestPass123",
        })
        h2 = {"Authorization": f"Bearer {login2.json()['data']['access_token']}"}

        # User 2 cannot access User 1's family assets
        resp = await client.get(f"/api/families/{f1_id}/assets", headers=h2)
        assert resp.status_code == 403
