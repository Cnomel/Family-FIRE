"""Security utilities: JWT tokens, password hashing, token blacklist."""

from datetime import datetime, timedelta
from enum import StrEnum
from typing import Any

import bcrypt
from jose import JWTError, jwt

from app.config import get_settings
from app.common.utils import utcnow

settings = get_settings()


class Role(StrEnum):
    """User roles with hierarchical permissions."""
    ADMIN = "admin"
    FAMILY_ADMIN = "family_admin"
    MEMBER = "member"


def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    password_bytes = password.encode("utf-8")
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password_bytes, salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8"),
    )


def create_access_token(
    data: dict[str, Any],
    expires_delta: timedelta | None = None,
) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    expire = utcnow() + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(
    data: dict[str, Any],
    expires_delta: timedelta | None = None,
) -> str:
    """Create a JWT refresh token."""
    to_encode = data.copy()
    expire = utcnow() + (
        expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict[str, Any] | None:
    """Decode and validate a JWT token. Returns payload or None if invalid."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except JWTError:
        return None


def validate_password_strength(password: str) -> tuple[bool, str]:
    """Validate password meets minimum requirements.

    Returns:
        Tuple of (is_valid, error_message)
    """
    if len(password) < settings.PASSWORD_MIN_LENGTH:
        return False, f"密码长度不能少于{settings.PASSWORD_MIN_LENGTH}位"

    if not any(c.isupper() for c in password):
        return False, "密码必须包含大写字母"

    if not any(c.islower() for c in password):
        return False, "密码必须包含小写字母"

    if not any(c.isdigit() for c in password):
        return False, "密码必须包含数字"

    return True, ""


def is_username_format(identifier: str) -> bool:
    """Check if identifier is a username (not email)."""
    return "@" not in identifier


def is_email_format(identifier: str) -> bool:
    """Check if identifier is an email."""
    return "@" in identifier
