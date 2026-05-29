"""FastAPI application entry point."""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.common.exceptions import (
    AppException,
    app_exception_handler,
)
from app.common.logging import get_logger, setup_logging
from app.common.middleware import (
    CORSMiddleware,
    RateLimitMiddleware,
    RequestIDMiddleware,
    RequestLoggingMiddleware,
)
from app.config import get_settings

logger = get_logger("main")
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    # Startup
    setup_logging(debug=settings.DEBUG)
    logger.info("starting_app", version=settings.APP_VERSION)

    # Initialize Redis connection pool
    # Initialize MinIO client
    # These will be added in subsequent tasks

    yield

    # Shutdown
    from app.database import close_db

    await close_db()
    logger.info("app_shutdown")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""

    app = FastAPI(
        title=settings.APP_NAME,
        description="家庭资产管理系统 — 通过资产关系管理实现FIRE财务独立",
        version=settings.APP_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    # === Middleware (order matters: last added = first executed) ===

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
    )

    # Rate limiting
    app.add_middleware(
        RateLimitMiddleware,
        requests_per_minute=settings.RATE_LIMIT_PER_MINUTE,
    )

    # Request logging
    app.add_middleware(RequestLoggingMiddleware)

    # Request ID
    app.add_middleware(RequestIDMiddleware)

    # === Exception Handlers ===

    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(RequestValidationError, _validation_error_handler)

    # === Routes ===

    @app.get("/health", tags=["系统"])
    async def health_check():
        """健康检查端点"""
        return {
            "status": "ok",
            "version": settings.APP_VERSION,
            "service": settings.APP_NAME,
        }

    # Register API routers
    from app.assets.router import router as assets_router
    from app.auth.router import router as auth_router
    from app.families.router import router as families_router
    from app.finance.router import router as finance_router
    from app.users.router import router as users_router

    app.include_router(auth_router, prefix="/api/auth", tags=["认证"])
    app.include_router(users_router, prefix="/api/users", tags=["用户"])
    app.include_router(families_router, prefix="/api/families", tags=["家庭"])
    app.include_router(assets_router, prefix="/api/families/{family_id}/assets", tags=["资产"])
    app.include_router(finance_router, prefix="/api/families/{family_id}/finance", tags=["财务"])

    # Will be added in subsequent tasks
    # from app.documents.router import router as documents_router
    # from app.notifications.router import router as notifications_router

    # app.include_router(documents_router, prefix="/api/documents", tags=["文档"])
    # app.include_router(notifications_router, prefix="/api/notifications", tags=["通知"])

    return app


async def _validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Handle request validation errors with Chinese messages."""
    errors = []
    for error in exc.errors():
        field = " -> ".join(str(loc) for loc in error["loc"])
        message = error["msg"]
        # Translate common validation messages
        if "field required" in message.lower():
            message = f"字段 '{field}' 是必填的"
        elif "value is not a valid" in message.lower():
            message = f"字段 '{field}' 格式不正确"
        errors.append({"field": field, "message": message})

    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "请求数据验证失败",
                "details": errors,
            },
        },
    )


# Create the app instance
app = create_app()
