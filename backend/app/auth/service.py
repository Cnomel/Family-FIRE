"""Authentication service: register, login, token management, password reset."""

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.schemas import (
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserResponse,
)
from app.common.exceptions import (
    AccountLockedError,
    AuthenticationError,
    DuplicateError,
    NotFoundError,
    ValidationError,
)
from app.common.logging import get_logger
from app.common.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    is_email_format,
    validate_password_strength,
    verify_password,
)
from app.config import get_settings
from app.users.models import User

logger = get_logger("auth_service")
settings = get_settings()


def _user_to_response(user: User) -> UserResponse:
    """Convert User model to UserResponse."""
    return UserResponse(
        id=user.id,
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        avatar_url=user.avatar_url,
        role=user.role,
        is_active=user.is_active,
        is_verified=user.is_verified,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


async def register(db: AsyncSession, data: RegisterRequest) -> UserResponse:
    """Register a new user.

    Raises:
        DuplicateError: If username or email already exists.
        ValidationError: If password is too weak.
    """
    # Validate password strength
    is_valid, error_msg = validate_password_strength(data.password)
    if not is_valid:
        raise ValidationError(error_msg, field="password")

    # Check username uniqueness
    stmt = select(User).where(User.username == data.username)
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise DuplicateError("用户", "用户名", data.username)

    # Check email uniqueness
    stmt = select(User).where(User.email == data.email)
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise DuplicateError("用户", "邮箱", data.email)

    # Create user
    user = User(
        id=str(uuid.uuid4()),
        username=data.username,
        email=data.email,
        hashed_password=hash_password(data.password),
        full_name=data.full_name,
        role="member",
        is_active=True,
        is_verified=False,
    )
    db.add(user)
    await db.flush()

    logger.info("user_registered", user_id=user.id, username=user.username)
    return _user_to_response(user)


async def login(db: AsyncSession, data: LoginRequest) -> TokenResponse:
    """Login with username or email.

    Raises:
        AuthenticationError: If credentials are invalid.
        AccountLockedError: If account is locked.
    """
    identifier = data.identifier.strip()

    # Determine if identifier is email or username
    if is_email_format(identifier):
        stmt = select(User).where(User.email == identifier)
    else:
        stmt = select(User).where(User.username == identifier)

    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        logger.warning("login_failed_user_not_found", identifier=identifier)
        raise AuthenticationError("用户名/邮箱或密码错误")

    # Check if account is locked
    if user.locked_until and user.locked_until > datetime.utcnow():
        remaining = int((user.locked_until - datetime.utcnow()).total_seconds() / 60)
        logger.warning("login_failed_account_locked", user_id=user.id)
        raise AccountLockedError(lockout_minutes=remaining)

    # Check if account is active
    if not user.is_active:
        logger.warning("login_failed_account_disabled", user_id=user.id)
        raise AuthenticationError("账号已被禁用")

    # Verify password
    if not verify_password(data.password, user.hashed_password):
        # Increment login attempts
        user.login_attempts += 1
        if user.login_attempts >= settings.LOGIN_MAX_ATTEMPTS:
            user.locked_until = datetime.utcnow() + timedelta(
                minutes=settings.LOGIN_LOCKOUT_MINUTES
            )
            user.login_attempts = 0
            logger.warning("account_locked", user_id=user.id, attempts=user.login_attempts)
        await db.flush()
        raise AuthenticationError("用户名/邮箱或密码错误")

    # Reset login attempts on successful login
    user.login_attempts = 0
    user.locked_until = None
    user.last_login_at = datetime.utcnow()
    await db.flush()

    # Generate tokens
    token_data = {"sub": user.id, "username": user.username, "role": user.role}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    logger.info("user_logged_in", user_id=user.id, username=user.username)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


async def refresh_token(db: AsyncSession, refresh_token_str: str) -> TokenResponse:
    """Refresh access token using refresh token.

    Raises:
        AuthenticationError: If refresh token is invalid or expired.
    """
    payload = decode_token(refresh_token_str)
    if not payload or payload.get("type") != "refresh":
        raise AuthenticationError("无效的刷新Token")

    user_id = payload.get("sub")
    if not user_id:
        raise AuthenticationError("无效的Token")

    # Verify user still exists and is active
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise AuthenticationError("用户不存在或已被禁用")

    # Generate new tokens
    token_data = {"sub": user.id, "username": user.username, "role": user.role}
    new_access_token = create_access_token(token_data)
    new_refresh_token = create_refresh_token(token_data)

    logger.info("token_refreshed", user_id=user.id)

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


async def get_user_by_id(db: AsyncSession, user_id: str) -> User:
    """Get user by ID.

    Raises:
        NotFoundError: If user not found.
    """
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    if not user:
        raise NotFoundError("用户", user_id)
    return user


async def get_current_user_info(db: AsyncSession, user_id: str) -> UserResponse:
    """Get current user information."""
    user = await get_user_by_id(db, user_id)
    return _user_to_response(user)


async def update_profile(db: AsyncSession, user_id: str, data: UpdateProfileRequest) -> UserResponse:
    """Update user profile."""
    user = await get_user_by_id(db, user_id)

    if data.full_name is not None:
        user.full_name = data.full_name
    if data.avatar_url is not None:
        user.avatar_url = data.avatar_url

    await db.flush()
    logger.info("profile_updated", user_id=user_id)
    return _user_to_response(user)


async def change_password(db: AsyncSession, user_id: str, data: ChangePasswordRequest) -> None:
    """Change user password.

    Raises:
        NotFoundError: If user not found.
        AuthenticationError: If old password is wrong.
        ValidationError: If new password is too weak.
    """
    user = await get_user_by_id(db, user_id)

    # Verify old password
    if not verify_password(data.old_password, user.hashed_password):
        raise AuthenticationError("当前密码错误")

    # Validate new password strength
    is_valid, error_msg = validate_password_strength(data.new_password)
    if not is_valid:
        raise ValidationError(error_msg, field="new_password")

    # Update password
    user.hashed_password = hash_password(data.new_password)
    await db.flush()
    logger.info("password_changed", user_id=user_id)


async def generate_password_reset_token(db: AsyncSession, email: str) -> str | None:
    """Generate password reset token. Returns token or None if user not found."""
    stmt = select(User).where(User.email == email)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        # Don't reveal if email exists
        logger.warning("password_reset_requested_unknown_email", email=email)
        return None

    # Generate a short-lived token
    token = create_access_token(
        {"sub": user.id, "type": "password_reset"},
        expires_delta=timedelta(hours=1),
    )
    logger.info("password_reset_token_generated", user_id=user.id)
    return token


async def reset_password(db: AsyncSession, token: str, new_password: str) -> None:
    """Reset password using reset token.

    Raises:
        AuthenticationError: If token is invalid.
        ValidationError: If new password is too weak.
    """
    payload = decode_token(token)
    if not payload or payload.get("type") != "password_reset":
        raise AuthenticationError("无效或过期的重置Token")

    user_id = payload.get("sub")
    user = await get_user_by_id(db, user_id)

    # Validate new password
    is_valid, error_msg = validate_password_strength(new_password)
    if not is_valid:
        raise ValidationError(error_msg, field="new_password")

    user.hashed_password = hash_password(new_password)
    user.login_attempts = 0
    user.locked_until = None
    await db.flush()
    logger.info("password_reset", user_id=user_id)
