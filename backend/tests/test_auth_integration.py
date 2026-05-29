"""Integration tests for the complete auth flow.

Tests the actual API endpoints with real request/response cycles.
"""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestAuthRegistrationFlow:
    """Test user registration through the API."""

    async def test_register_success(self, client: AsyncClient):
        """Register a new user and verify response structure."""
        response = await client.post("/api/auth/register", json={
            "username": "testuser",
            "email": "test@example.com",
            "password": "TestPass123",
            "full_name": "测试用户",
        })
        assert response.status_code == 201
        data = response.json()
        assert data["success"] is True
        assert data["data"]["username"] == "testuser"
        assert data["data"]["email"] == "test@example.com"
        assert data["data"]["role"] == "member"
        assert "id" in data["data"]

    async def test_register_duplicate_username(self, client: AsyncClient):
        """Registering with same username should fail."""
        await client.post("/api/auth/register", json={
            "username": "dupuser",
            "email": "first@example.com",
            "password": "TestPass123",
            "full_name": "First",
        })
        response = await client.post("/api/auth/register", json={
            "username": "dupuser",
            "email": "second@example.com",
            "password": "TestPass123",
            "full_name": "Second",
        })
        assert response.status_code == 409
        data = response.json()
        assert "已存在" in data["error"]["message"]

    async def test_register_duplicate_email(self, client: AsyncClient):
        """Registering with same email should fail."""
        await client.post("/api/auth/register", json={
            "username": "user1",
            "email": "same@example.com",
            "password": "TestPass123",
            "full_name": "First",
        })
        response = await client.post("/api/auth/register", json={
            "username": "user2",
            "email": "same@example.com",
            "password": "TestPass123",
            "full_name": "Second",
        })
        assert response.status_code == 409

    async def test_register_weak_password(self, client: AsyncClient):
        """Weak password should be rejected."""
        response = await client.post("/api/auth/register", json={
            "username": "weakuser",
            "email": "weak@example.com",
            "password": "123",  # Too short, no uppercase
            "full_name": "Weak",
        })
        assert response.status_code == 422

    async def test_register_invalid_email(self, client: AsyncClient):
        """Invalid email format should be rejected."""
        response = await client.post("/api/auth/register", json={
            "username": "invalidemail",
            "email": "not-an-email",
            "password": "TestPass123",
            "full_name": "Invalid",
        })
        assert response.status_code == 422


@pytest.mark.asyncio
class TestAuthLoginFlow:
    """Test login flow through the API."""

    async def _register_user(self, client: AsyncClient) -> dict:
        """Helper to register a user."""
        await client.post("/api/auth/register", json={
            "username": "loginuser",
            "email": "login@example.com",
            "password": "TestPass123",
            "full_name": "Login User",
        })

    async def test_login_with_username(self, client: AsyncClient):
        """Login with username should succeed."""
        await self._register_user(client)
        response = await client.post("/api/auth/login", json={
            "identifier": "loginuser",
            "password": "TestPass123",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "access_token" in data["data"]
        assert "refresh_token" in data["data"]
        assert data["data"]["token_type"] == "bearer"

    async def test_login_with_email(self, client: AsyncClient):
        """Login with email should succeed."""
        await self._register_user(client)
        response = await client.post("/api/auth/login", json={
            "identifier": "login@example.com",
            "password": "TestPass123",
        })
        assert response.status_code == 200
        assert response.json()["success"] is True

    async def test_login_wrong_password(self, client: AsyncClient):
        """Wrong password should fail."""
        await self._register_user(client)
        response = await client.post("/api/auth/login", json={
            "identifier": "loginuser",
            "password": "WrongPass123",
        })
        assert response.status_code == 401
        assert "密码错误" in response.json()["error"]["message"]

    async def test_login_nonexistent_user(self, client: AsyncClient):
        """Non-existent user should fail with same error (no user enumeration)."""
        response = await client.post("/api/auth/login", json={
            "identifier": "nonexistent",
            "password": "TestPass123",
        })
        assert response.status_code == 401


@pytest.mark.asyncio
class TestAuthTokenFlow:
    """Test token refresh and authenticated endpoints."""

    async def _register_and_login(self, client: AsyncClient) -> dict:
        """Helper to register, login, and return tokens."""
        await client.post("/api/auth/register", json={
            "username": "tokenuser",
            "email": "token@example.com",
            "password": "TestPass123",
            "full_name": "Token User",
        })
        login_resp = await client.post("/api/auth/login", json={
            "identifier": "tokenuser",
            "password": "TestPass123",
        })
        return login_resp.json()["data"]

    async def test_refresh_token(self, client: AsyncClient):
        """Refresh token should return new tokens."""
        tokens = await self._register_and_login(client)
        response = await client.post("/api/auth/refresh", json={
            "refresh_token": tokens["refresh_token"],
        })
        assert response.status_code == 200
        data = response.json()["data"]
        assert "access_token" in data
        assert "refresh_token" in data

    async def test_get_me_authenticated(self, client: AsyncClient):
        """GET /me with valid token should return user info."""
        tokens = await self._register_and_login(client)
        response = await client.get("/api/auth/me", headers={
            "Authorization": f"Bearer {tokens['access_token']}",
        })
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["username"] == "tokenuser"
        assert data["email"] == "token@example.com"

    async def test_get_me_no_token(self, client: AsyncClient):
        """GET /me without token should return 401."""
        response = await client.get("/api/auth/me")
        assert response.status_code == 401

    async def test_get_me_invalid_token(self, client: AsyncClient):
        """GET /me with invalid token should return 401."""
        response = await client.get("/api/auth/me", headers={
            "Authorization": "Bearer invalid.token.here",
        })
        assert response.status_code == 401

    async def test_update_profile(self, client: AsyncClient):
        """Update profile should work."""
        tokens = await self._register_and_login(client)
        response = await client.put("/api/auth/me", json={
            "full_name": "新名字",
        }, headers={
            "Authorization": f"Bearer {tokens['access_token']}",
        })
        assert response.status_code == 200
        assert response.json()["data"]["full_name"] == "新名字"

    async def test_change_password(self, client: AsyncClient):
        """Change password should work, then login with new password."""
        tokens = await self._register_and_login(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Change password
        response = await client.put("/api/auth/password", json={
            "old_password": "TestPass123",
            "new_password": "NewPass456",
        }, headers=headers)
        assert response.status_code == 200

        # Login with new password
        login_resp = await client.post("/api/auth/login", json={
            "identifier": "tokenuser",
            "password": "NewPass456",
        })
        assert login_resp.status_code == 200

    async def test_change_password_wrong_old(self, client: AsyncClient):
        """Change password with wrong old password should fail."""
        tokens = await self._register_and_login(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        response = await client.put("/api/auth/password", json={
            "old_password": "WrongOldPass",
            "new_password": "NewPass456",
        }, headers=headers)
        assert response.status_code == 401
