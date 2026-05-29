"""Alembic environment configuration for async PostgreSQL."""

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config
from sqlmodel import SQLModel

from app.config import get_settings

# Import ALL models so Alembic can detect them for migration generation
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

config = context.config
settings = get_settings()

# Override sqlalchemy.url with our settings
config.set_main_option("sqlalchemy.url", settings.sync_database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Use SQLModel's metadata for migration detection
target_metadata = SQLModel.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        render_as_batch=True,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations in 'online' mode with async engine."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
