"""Authentication API router."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import service as auth_service
from app.auth.dependencies import CurrentUser
from app.auth.schemas import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserResponse,
)
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db

router = APIRouter()


@router.post(
    "/register",
    response_model=SuccessResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="用户注册",
    description="注册新用户（用户名+邮箱+密码）",
)
async def register(
    data: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    user = await auth_service.register(db, data)
    return SuccessResponse(data=user, message="注册成功")


@router.post(
    "/login",
    response_model=SuccessResponse[TokenResponse],
    summary="用户登录",
    description="使用用户名或邮箱登录",
)
async def login(
    data: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    tokens = await auth_service.login(db, data)
    return SuccessResponse(data=tokens, message="登录成功")


@router.post(
    "/refresh",
    response_model=SuccessResponse[TokenResponse],
    summary="刷新Token",
    description="使用刷新Token获取新的访问Token",
)
async def refresh_token(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    tokens = await auth_service.refresh_token(db, data.refresh_token)
    return SuccessResponse(data=tokens, message="Token刷新成功")


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="用户登出",
    description="登出当前用户（Token将被加入黑名单）",
)
async def logout(
    current_user: CurrentUser,
):
    # Token blacklisting will be implemented with Redis in Task 9
    return MessageResponse(message="登出成功")


@router.get(
    "/me",
    response_model=SuccessResponse[UserResponse],
    summary="获取当前用户",
    description="获取当前登录用户的详细信息",
)
async def get_me(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    user = await auth_service.get_current_user_info(db, current_user.id)
    return SuccessResponse(data=user)


@router.put(
    "/me",
    response_model=SuccessResponse[UserResponse],
    summary="更新个人信息",
    description="更新当前用户的姓名和头像",
)
async def update_me(
    data: UpdateProfileRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    user = await auth_service.update_profile(db, current_user.id, data)
    return SuccessResponse(data=user, message="更新成功")


@router.put(
    "/password",
    response_model=MessageResponse,
    summary="修改密码",
    description="修改当前用户的密码",
)
async def change_password(
    data: ChangePasswordRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await auth_service.change_password(db, current_user.id, data)
    return MessageResponse(message="密码修改成功")


@router.post(
    "/password/forgot",
    response_model=MessageResponse,
    summary="忘记密码",
    description="发送密码重置邮件（实际发送逻辑待实现）",
)
async def forgot_password(
    data: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    await auth_service.generate_password_reset_token(db, data.email)
    # TODO: Send email with reset link containing the token
    # For now, always return success to prevent email enumeration
    return MessageResponse(message="如果该邮箱已注册，重置链接将发送到您的邮箱")


@router.post(
    "/password/reset",
    response_model=MessageResponse,
    summary="重置密码",
    description="使用重置Token重置密码",
)
async def reset_password(
    data: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    await auth_service.reset_password(db, data.token, data.new_password)
    return MessageResponse(message="密码重置成功")
