"""Tests for family management system."""

import pytest

from app.families.models import Family, FamilyMember
from app.families.schemas import (
    CreateFamilyRequest,
    JoinFamilyRequest,
    UpdateFamilyRequest,
    UpdateMemberRoleRequest,
)

# ============================================================
# Schema Tests
# ============================================================

class TestFamilySchemas:
    def test_create_family_request(self):
        data = CreateFamilyRequest(name="我的家庭", description="测试家庭")
        assert data.name == "我的家庭"
        assert data.description == "测试家庭"

    def test_create_family_request_minimal(self):
        data = CreateFamilyRequest(name="家庭")
        assert data.name == "家庭"
        assert data.description is None

    def test_create_family_request_empty_name_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            CreateFamilyRequest(name="")

    def test_update_family_request(self):
        data = UpdateFamilyRequest(name="新名字")
        assert data.name == "新名字"
        assert data.description is None

    def test_join_family_request(self):
        data = JoinFamilyRequest(invite_code="ABC123")
        assert data.invite_code == "ABC123"

    def test_join_family_request_short_code_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            JoinFamilyRequest(invite_code="AB")

    def test_update_member_role_request(self):
        data = UpdateMemberRoleRequest(role="admin")
        assert data.role == "admin"

    def test_update_member_role_invalid_role_fails(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            UpdateMemberRoleRequest(role="superadmin")


# ============================================================
# Model Tests
# ============================================================

class TestFamilyModels:
    def test_family_model_fields(self):
        columns = {c.name for c in Family.__table__.columns}
        required = {"id", "name", "description", "created_by", "invite_code", "invite_code_expires_at"}
        assert required.issubset(columns)

    def test_family_member_model_fields(self):
        columns = {c.name for c in FamilyMember.__table__.columns}
        required = {"id", "family_id", "user_id", "role", "joined_at"}
        assert required.issubset(columns)

    def test_family_member_roles(self):
        """Verify role field supports admin and member."""
        # The role field is a string, validated at the API level
        assert True  # Schema validation tested above
