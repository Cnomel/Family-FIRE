"""Custom exceptions and global exception handlers."""

from typing import Any

from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse

# === Base Exceptions ===

class AppException(Exception):
    """Base application exception."""

    def __init__(
        self,
        message: str,
        code: str = "APP_ERROR",
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: dict[str, Any] | None = None,
    ) -> None:
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details or {}
        super().__init__(message)


class NotFoundError(AppException):
    """Resource not found."""

    def __init__(self, resource: str, identifier: str | int) -> None:
        super().__init__(
            message=f"{resource}不存在: {identifier}",
            code="NOT_FOUND",
            status_code=status.HTTP_404_NOT_FOUND,
            details={"resource": resource, "identifier": str(identifier)},
        )


class DuplicateError(AppException):
    """Duplicate resource."""

    def __init__(self, resource: str, field: str, value: str) -> None:
        super().__init__(
            message=f"{resource}已存在: {field}='{value}'",
            code="DUPLICATE",
            status_code=status.HTTP_409_CONFLICT,
            details={"resource": resource, "field": field, "value": value},
        )


class PermissionDeniedError(AppException):
    """Permission denied."""

    def __init__(self, action: str = "执行此操作") -> None:
        super().__init__(
            message=f"权限不足，无法{action}",
            code="PERMISSION_DENIED",
            status_code=status.HTTP_403_FORBIDDEN,
        )


class ValidationError(AppException):
    """Validation error."""

    def __init__(self, message: str, field: str | None = None) -> None:
        super().__init__(
            message=message,
            code="VALIDATION_ERROR",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            details={"field": field} if field else {},
        )


class RateLimitError(AppException):
    """Rate limit exceeded."""

    def __init__(self, retry_after: int = 60) -> None:
        super().__init__(
            message=f"请求过于频繁，请{retry_after}秒后重试",
            code="RATE_LIMIT_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            details={"retry_after": retry_after},
        )


class AuthenticationError(AppException):
    """Authentication failed."""

    def __init__(self, message: str = "认证失败") -> None:
        super().__init__(
            message=message,
            code="AUTHENTICATION_ERROR",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )


class AccountLockedError(AppException):
    """Account locked due to too many failed attempts."""

    def __init__(self, lockout_minutes: int = 30) -> None:
        super().__init__(
            message=f"账号已锁定，请{lockout_minutes}分钟后重试",
            code="ACCOUNT_LOCKED",
            status_code=status.HTTP_423_LOCKED,
            details={"lockout_minutes": lockout_minutes},
        )


class FamilyLimitError(AppException):
    """Family creation limit exceeded."""

    def __init__(self, max_families: int) -> None:
        super().__init__(
            message=f"家庭数量已达上限({max_families})",
            code="FAMILY_LIMIT_EXCEEDED",
            status_code=status.HTTP_400_BAD_REQUEST,
            details={"max_families": max_families},
        )


# === Exception Handlers ===

async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """Handle application exceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": exc.code,
                "message": exc.message,
                "details": exc.details,
            },
        },
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """Handle HTTP exceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": "HTTP_ERROR",
                "message": exc.detail if isinstance(exc.detail, str) else str(exc.detail),
            },
        },
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle unhandled exceptions."""
    from app.common.logging import get_logger

    logger = get_logger("exception")
    logger.error("Unhandled exception", exc_info=exc, path=request.url.path)

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "服务器内部错误",
            },
        },
    )
