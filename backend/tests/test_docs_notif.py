"""Tests for document and notification systems."""

from datetime import UTC

import pytest


class TestDocumentSchemas:
    def test_document_response_fields(self):
        from datetime import datetime

        from app.documents.schemas import DocumentResponse
        doc = DocumentResponse(
            id="doc-1",
            family_id="fam-1",
            type="warranty",
            file_name="保修卡.pdf",
            file_path="fam-1/doc-1/保修卡.pdf",
            mime_type="application/pdf",
            file_size=102400,
            created_at=datetime.now(UTC),
        )
        assert doc.type == "warranty"
        assert doc.file_name == "保修卡.pdf"


class TestNotificationSchemas:
    def test_notification_list_structure(self):
        """Verify notification list response structure."""
        from app.notifications.models import Notification
        columns = {c.name for c in Notification.__table__.columns}
        required = {"id", "user_id", "type", "title", "message", "is_read", "created_at"}
        assert required.issubset(columns)

    def test_notification_preference_structure(self):
        from app.notifications.models import NotificationPreference
        columns = {c.name for c in NotificationPreference.__table__.columns}
        required = {"id", "user_id", "notification_type", "enabled"}
        assert required.issubset(columns)


@pytest.mark.asyncio
class TestNotificationIntegration:
    async def _setup(self, client):
        await client.post("/api/auth/register", json={
            "username": "notifuser", "email": "notif@example.com",
            "password": "TestPass123", "full_name": "Notif User",
        })
        login = await client.post("/api/auth/login", json={
            "identifier": "notifuser", "password": "TestPass123",
        })
        return login.json()["data"]

    async def test_notification_list_empty(self, client):
        tokens = await self._setup(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        resp = await client.get("/api/notifications", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"]["total"] == 0

    async def test_unread_count_zero(self, client):
        tokens = await self._setup(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        resp = await client.get("/api/notifications/unread-count", headers=headers)
        assert resp.status_code == 200
        assert resp.json()["data"] == 0

    async def test_mark_all_read_empty(self, client):
        tokens = await self._setup(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        resp = await client.put("/api/notifications/read-all", headers=headers)
        assert resp.status_code == 200

    async def test_notification_settings(self, client):
        tokens = await self._setup(client)
        headers = {"Authorization": f"Bearer {tokens['access_token']}"}

        # Get settings
        resp = await client.get("/api/notifications/settings", headers=headers)
        assert resp.status_code == 200

        # Update setting
        resp = await client.put("/api/notifications/settings", json={
            "type": "asset_added",
            "enabled": False,
        }, headers=headers)
        assert resp.status_code == 200
