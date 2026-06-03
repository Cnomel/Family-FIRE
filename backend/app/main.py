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

    # CORS — 使用 FastAPI 内置的 CORSMiddleware，更可靠
    from fastapi.middleware.cors import CORSMiddleware as FastAPICORSMiddleware
    app.add_middleware(
        FastAPICORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
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

    @app.get("/api/version/check", tags=["系统"])
    async def check_version(current_version: str | None = None):
        """检查应用版本更新

        Args:
            current_version: 当前客户端版本号，如 v0.1.0-beta.1

        Returns:
            版本信息，包含最新版本、下载链接、更新日志等
        """
        # TODO: 后续可以从数据库或配置文件读取版本信息
        # 目前使用硬编码的版本信息
        latest_version = "v0.1.0-beta.1"
        min_supported_version = "v0.1.0-beta.1"

        # 判断是否需要更新
        need_update = _compare_versions(current_version, latest_version) < 0 if current_version else False
        force_update = _compare_versions(current_version, min_supported_version) < 0 if current_version else False

        return {
            "latest_version": latest_version,
            "min_supported_version": min_supported_version,
            "need_update": need_update,
            "force_update": force_update,
            "download_url": f"{settings.BASE_URL}/downloads/family-fire-{latest_version}.apk" if need_update else None,
            "release_notes": "1. 新增收支管理系统\n2. 支持月度预算和年度统计\n3. 优化FIRE计算逻辑\n4. 修复已知问题",
            "release_date": "2024-01-15",
        }

    # WebSocket endpoint
    from fastapi import Query

    from app.notifications.websocket import handle_websocket

    @app.websocket("/ws")
    async def websocket_endpoint(websocket, token: str = Query(None)):
        """WebSocket连接端点（实时通知）"""
        await handle_websocket(websocket, token)

    # Register API routers
    from app.assets.router import router as assets_router
    from app.auth.router import router as auth_router
    from app.documents.router import router as documents_router
    from app.families.router import router as families_router
    from app.finance.router import router as finance_router
    from app.notifications.router import router as notifications_router
    from app.users.router import router as users_router

    app.include_router(auth_router, prefix="/api/auth", tags=["认证"])
    app.include_router(users_router, prefix="/api/users", tags=["用户"])
    app.include_router(families_router, prefix="/api/families", tags=["家庭"])
    app.include_router(assets_router, prefix="/api/families/{family_id}/assets", tags=["资产"])
    app.include_router(finance_router, prefix="/api/families/{family_id}/finance", tags=["财务"])
    app.include_router(documents_router, prefix="/api/documents", tags=["文档"])
    app.include_router(notifications_router, prefix="/api/notifications", tags=["通知"])

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


def _compare_versions(version1: str, version2: str) -> int:
    """比较两个版本号

    Args:
        version1: 版本号1，如 v0.1.0-beta.1
        version2: 版本号2，如 v0.1.0-beta.2

    Returns:
        -1: version1 < version2
         0: version1 == version2
         1: version1 > version2
    """
    if not version1 or not version2:
        return 0

    # 移除 'v' 前缀和 '-beta' 后缀
    def normalize(v: str) -> list:
        v = v.lstrip('v')
        # 分离主版本号和beta版本号
        parts = v.split('-')
        main_version = parts[0]
        beta_version = parts[1] if len(parts) > 1 else ''

        # 解析主版本号
        main_parts = [int(x) for x in main_version.split('.') if x.isdigit()]

        # 解析beta版本号
        beta_num = 0
        if beta_version and beta_version.startswith('beta'):
            beta_num = int(beta_version.replace('beta', '')) if beta_version.replace('beta', '').isdigit() else 0

        return [*main_parts, beta_num]

    v1_parts = normalize(version1)
    v2_parts = normalize(version2)

    # 补齐长度
    max_len = max(len(v1_parts), len(v2_parts))
    v1_parts.extend([0] * (max_len - len(v1_parts)))
    v2_parts.extend([0] * (max_len - len(v2_parts)))

    for i in range(max_len):
        if v1_parts[i] < v2_parts[i]:
            return -1
        elif v1_parts[i] > v2_parts[i]:
            return 1

    return 0
