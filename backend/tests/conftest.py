"""Test configuration and fixtures."""

import asyncio
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

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
        DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/family_fire_test",
        REDIS_URL="redis://localhost:6379/1",
        DEBUG=True,
        JWT_SECRET_KEY="test-secret-key-for-testing-only",
    )


@pytest_asyncio.fixture
async def test_db(test_settings: Settings) -> AsyncGenerator[AsyncSession, None]:
    """Provide a test database session."""
    test_engine = create_async_engine(
        test_settings.DATABASE_URL,
        echo=False,
    )

    test_session_factory = sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with test_session_factory() as session:
        yield session
        await session.rollback()

    await test_engine.dispose()


@pytest_asyncio.fixture
async def client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Provide a test HTTP client."""

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


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
