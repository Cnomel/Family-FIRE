"""Test configuration and fixtures using SQLite in-memory database."""

import asyncio
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlmodel import SQLModel

from app.config import Settings
from app.database import get_db
from app.main import app


@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
def test_settings() -> Settings:
    """Get test settings."""
    return Settings(
        DATABASE_URL="sqlite+aiosqlite:///test.db",
        REDIS_URL="redis://localhost:6379/1",
        DEBUG=True,
        JWT_SECRET_KEY="test-secret-key-for-testing-only",
    )


@pytest_asyncio.fixture(scope="session")
async def test_engine(test_settings):
    """Create test database engine and tables."""
    # Import all models to register them
    from app.users.models import User, SystemSettings  # noqa: F401
    from app.families.models import Family, FamilyMember  # noqa: F401
    from app.assets.models import (  # noqa: F401
        Asset, AssetFinancial, AssetLifecycle, AssetRelationship,
        AssetMetadataVehicle, AssetMetadataRealEstate, AssetMetadataElectronics,
        AssetMetadataFurniture, AssetMetadataInsurance, AssetMetadataFinancial,
        AssetMetadataSubscription, AssetMetadataAccount, AssetMetadataConsumable,
    )
    from app.finance.models import (  # noqa: F401
        Liability, Transaction, ExpenseCategory, IncomeCategory,
        IncomeExpenseRecord, PriceSnapshot,
    )
    from app.documents.models import AssetDocument  # noqa: F401
    from app.notifications.models import Notification, NotificationPreference  # noqa: F401

    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False,
    )

    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)

    yield engine

    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.drop_all)

    await engine.dispose()


@pytest_asyncio.fixture
async def test_db(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Provide a test database session with rollback."""
    test_session_factory = sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with test_session_factory() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Provide a test HTTP client with database override."""

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    # Disable rate limiting for tests
    for middleware in app.user_middleware:
        if hasattr(middleware, "cls") and middleware.cls.__name__ == "RateLimitMiddleware":
            pass
    # Find and disable rate limiter in middleware stack
    from app.common.middleware import RateLimitMiddleware
    for mw in getattr(app, "middleware_stack", []).__class__.__mro__:
        pass

    # Simply set a flag on the app to disable rate limiting
    app.state.rate_limit_disabled = True

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()
    app.state.rate_limit_disabled = False


@pytest.fixture
def mock_redis():
    """Provide a mock Redis client."""
    mock = AsyncMock()
    mock.get = AsyncMock(return_value=None)
    mock.set = AsyncMock(return_value=True)
    mock.delete = AsyncMock(return_value=True)
    mock.exists = AsyncMock(return_value=False)
    mock.expire = AsyncMock(return_value=True)
    return mock


@pytest.fixture
def sample_user_data() -> dict:
    """Provide sample user data for testing."""
    return {
        "username": "testuser",
        "email": "test@example.com",
        "password": "TestPass123",
        "full_name": "测试用户",
    }


@pytest.fixture
def sample_family_data() -> dict:
    """Provide sample family data for testing."""
    return {
        "name": "测试家庭",
        "description": "这是一个测试家庭",
    }
