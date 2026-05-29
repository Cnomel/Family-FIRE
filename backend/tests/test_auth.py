"""Tests for authentication system."""


import pytest

from app.auth.schemas import (
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    UpdateProfileRequest,
)
from app.common.security import (
    Role,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    is_email_format,
    is_username_format,
    validate_password_strength,
    verify_password,
)

# ============================================================
# Security Utils Tests
# ============================================================

class TestPasswordHashing:
    def test_hash_and_verify(self):
        password = "TestPass123"
        hashed = hash_password(password)
        assert hashed != password
        assert verify_password(password, hashed)

    def test_wrong_password_fails(self):
        hashed = hash_password("correct_password")
        assert not verify_password("wrong_password", hashed)

    def test_different_hashes(self):
        h1 = hash_password("same_password")
        h2 = hash_password("same_password")
        assert h1 != h2  # bcrypt uses random salt


class TestPasswordValidation:
    def test_valid_password(self):
        is_valid, msg = validate_password_strength("TestPass123")
        assert is_valid is True
        assert msg == ""

    def test_too_short(self):
        is_valid, msg = validate_password_strength("Sh0rt")
        assert is_valid is False
        assert "不能少于" in msg

    def test_no_uppercase(self):
        is_valid, msg = validate_password_strength("testpass123")
        assert is_valid is False
        assert "大写字母" in msg

    def test_no_lowercase(self):
        is_valid, msg = validate_password_strength("TESTPASS123")
        assert is_valid is False
        assert "小写字母" in msg

    def test_no_digit(self):
        is_valid, msg = validate_password_strength("TestPassword")
        assert is_valid is False
        assert "数字" in msg


class TestJWTToken:
    def test_create_and_decode_access_token(self):
        data = {"sub": "user123", "username": "testuser", "role": "member"}
        token = create_access_token(data)
        payload = decode_token(token)
        assert payload is not None
        assert payload["sub"] == "user123"
        assert payload["type"] == "access"

    def test_create_and_decode_refresh_token(self):
        data = {"sub": "user123", "username": "testuser", "role": "member"}
        token = create_refresh_token(data)
        payload = decode_token(token)
        assert payload is not None
        assert payload["sub"] == "user123"
        assert payload["type"] == "refresh"

    def test_invalid_token_returns_none(self):
        payload = decode_token("invalid.token.here")
        assert payload is None

    def test_expired_token_returns_none(self):
        from datetime import timedelta
        data = {"sub": "user123"}
        token = create_access_token(data, expires_delta=timedelta(seconds=-1))
        payload = decode_token(token)
        assert payload is None


class TestIdentifierDetection:
    def test_username_format(self):
        assert is_username_format("testuser") is True
        assert is_username_format("user_123") is True
        assert is_username_format("中文用户") is True

    def test_email_format(self):
        assert is_email_format("test@example.com") is True
        assert is_email_format("user@domain.org") is True

    def test_not_email(self):
        assert is_email_format("testuser") is False
        assert is_email_format("no_at_sign") is False


class TestRoles:
    def test_role_values(self):
        assert Role.ADMIN == "admin"
        assert Role.FAMILY_ADMIN == "family_admin"
        assert Role.MEMBER == "member"

    def test_role_hierarchy(self):
        assert Role.ADMIN.value == "admin"
        assert Role.FAMILY_ADMIN.value == "family_admin"
        assert Role.MEMBER.value == "member"


# ============================================================
# Schema Validation Tests
# ============================================================

class TestAuthSchemas:
    def test_register_request_valid(self):
        data = RegisterRequest(
            username="testuser",
            email="test@example.com",
            password="TestPass123",
            full_name="测试用户",
        )
        assert data.username == "testuser"
        assert data.email == "test@example.com"

    def test_register_request_username_too_short(self):
        from pydantic import ValidationError as PydanticValidationError
        with pytest.raises(PydanticValidationError):
            RegisterRequest(
                username="ab",
                email="test@example.com",
                password="TestPass123",
                full_name="测试用户",
            )

    def test_login_request_valid(self):
        data = LoginRequest(identifier="testuser", password="TestPass123")
        assert data.identifier == "testuser"

    def test_login_request_email_identifier(self):
        data = LoginRequest(identifier="test@example.com", password="TestPass123")
        assert data.identifier == "test@example.com"

    def test_change_password_request(self):
        data = ChangePasswordRequest(
            old_password="OldPass123",
            new_password="NewPass456",
        )
        assert data.old_password == "OldPass123"

    def test_update_profile_request(self):
        data = UpdateProfileRequest(full_name="新名字")
        assert data.full_name == "新名字"
        assert data.avatar_url is None
