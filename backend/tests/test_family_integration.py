"""Integration tests for the complete family management flow."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestFamilyManagementFlow:
    """Test complete family lifecycle through the API."""

    async def _register_and_login(self, client: AsyncClient, username: str = "familyuser") -> dict:
        """Helper to register and login."""
        await client.post("/api/auth/register", json={
            "username": username,
            "email": f"{username}@example.com",
            "password": "TestPass123",
            "full_name": f"{username} User",
        })
        login_resp = await client.post("/api/auth/login", json={
            "identifier": username,
            "password": "TestPass123",
        })
        return login_resp.json()["data"]

    async def test_create_family(self, client: AsyncClient):
        """Create a family and verify it appears in user's family list."""
        tokens = await self._register_and_login(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Create family
        response = await client.post("/api/families", json={
            "name": "我的家庭",
            "description": "测试家庭",
        }, headers=headers)
        assert response.status_code == 201
        family = response.json()["data"]
        assert family["name"] == "我的家庭"
        assert family["member_count"] == 1
        family_id = family["id"]

        # Verify in list
        list_resp = await client.get("/api/families", headers=headers)
        assert list_resp.status_code == 200
        families = list_resp.json()["data"]["families"]
        assert len(families) == 1
        assert families[0]["id"] == family_id

    async def test_family_invite_and_join(self, client: AsyncClient):
        """Test invite code generation and family joining."""
        # User 1 creates family
        tokens1 = await self._register_and_login(client, "admin_user")
        headers1 = {"Authorization": f"Bearer {tokens1['access_token']}"}

        create_resp = await client.post("/api/families", json={
            "name": "邀请测试家庭",
        }, headers=headers1)
        family_id = create_resp.json()["data"]["id"]

        # Generate invite code
        invite_resp = await client.post(f"/api/families/{family_id}/invite", headers=headers1)
        assert invite_resp.status_code == 200
        invite_code = invite_resp.json()["data"]["invite_code"]
        assert len(invite_code) == 6

        # User 2 joins family
        tokens2 = await self._register_and_login(client, "member_user")
        headers2 = {"Authorization": f"Bearer {tokens2['access_token']}"}

        join_resp = await client.post("/api/families/join", json={
            "invite_code": invite_code,
        }, headers=headers2)
        assert join_resp.status_code == 200
        assert join_resp.json()["data"]["member_count"] == 2

        # Verify User 2 sees the family
        list_resp = await client.get("/api/families", headers=headers2)
        families = list_resp.json()["data"]["families"]
        assert len(families) == 1
        assert families[0]["id"] == family_id

    async def test_family_detail_shows_members(self, client: AsyncClient):
        """Family detail should show all members."""
        tokens = await self._register_and_login(client, "detailuser")
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        create_resp = await client.post("/api/families", json={
            "name": "详情测试",
        }, headers=headers)
        family_id = create_resp.json()["data"]["id"]

        detail_resp = await client.get(f"/api/families/{family_id}", headers=headers)
        assert detail_resp.status_code == 200
        detail = detail_resp.json()["data"]
        assert len(detail["members"]) == 1
        assert detail["members"][0]["role"] == "admin"

    async def test_non_member_cannot_access_family(self, client: AsyncClient):
        """Non-member should not be able to access family."""
        tokens1 = await self._register_and_login(client, "owner_user")
        headers1 = {"Authorization": f"Bearer {tokens1['access_token']}"}

        create_resp = await client.post("/api/families", json={
            "name": "私有家庭",
        }, headers=headers1)
        family_id = create_resp.json()["data"]["id"]

        # Another user tries to access
        tokens2 = await self._register_and_login(client, "outsider_user")
        headers2 = {"Authorization": f"Bearer {tokens2['access_token']}"}

        detail_resp = await client.get(f"/api/families/{family_id}", headers=headers2)
        assert detail_resp.status_code == 403

    async def test_member_cannot_remove_others(self, client: AsyncClient):
        """Regular member should not be able to remove others."""
        # Admin creates family
        tokens1 = await self._register_and_login(client, "admin_rm")
        headers1 = {"Authorization": f"Bearer {tokens1['access_token']}"}

        create_resp = await client.post("/api/families", json={"name": "权限测试"}, headers=headers1)
        family_id = create_resp.json()["data"]["id"]

        # Generate invite and have member join
        invite_resp = await client.post(f"/api/families/{family_id}/invite", headers=headers1)
        invite_code = invite_resp.json()["data"]["invite_code"]

        tokens2 = await self._register_and_login(client, "member_rm")
        headers2 = {"Authorization": f"Bearer {tokens2['access_token']}"}
        await client.post("/api/families/join", json={"invite_code": invite_code}, headers=headers2)

        # Get admin's user_id
        me_resp = await client.get("/api/auth/me", headers=headers1)
        admin_id = me_resp.json()["data"]["id"]

        # Member tries to remove admin - should fail
        remove_resp = await client.delete(
            f"/api/families/{family_id}/members/{admin_id}",
            headers=headers2,
        )
        assert remove_resp.status_code == 403

    async def test_update_family_info(self, client: AsyncClient):
        """Admin can update family info."""
        tokens = await self._register_and_login(client, "updateuser")
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        create_resp = await client.post("/api/families", json={"name": "原名"}, headers=headers)
        family_id = create_resp.json()["data"]["id"]

        update_resp = await client.put(f"/api/families/{family_id}", json={
            "name": "新名称",
            "description": "新描述",
        }, headers=headers)
        assert update_resp.status_code == 200
        assert update_resp.json()["data"]["name"] == "新名称"

    async def test_delete_family(self, client: AsyncClient):
        """Admin can delete family."""
        tokens = await self._register_and_login(client, "deleteuser")
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        create_resp = await client.post("/api/families", json={"name": "待删除"}, headers=headers)
        family_id = create_resp.json()["data"]["id"]

        delete_resp = await client.delete(f"/api/families/{family_id}", headers=headers)
        assert delete_resp.status_code == 200

        # Verify family is gone from list
        list_resp = await client.get("/api/families", headers=headers)
        families = list_resp.json()["data"]["families"]
        assert len(families) == 0
