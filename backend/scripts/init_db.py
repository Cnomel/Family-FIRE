#!/usr/bin/env python3
"""Database initialization script.

Creates all tables and inserts seed data.
Safe to run multiple times (idempotent).

Usage:
    uv run python scripts/init_db.py
"""

import asyncio
import sys

from sqlalchemy import text
from sqlmodel import SQLModel


async def create_tables():
    """Create all database tables."""
    from app.database import engine

    # Import all models to register them with SQLModel metadata
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

    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)

    print("[OK] All tables created/verified")


async def seed_data():
    """Insert seed data (skip if already exists)."""
    from app.database import async_session_factory
    from app.users.models import SystemSettings, User
    from app.finance.models import ExpenseCategory, IncomeCategory
    from app.common.security import hash_password
    from sqlalchemy import select, func

    async with async_session_factory() as session:
        # Check if seed data already exists
        settings_count = await session.execute(
            select(func.count()).select_from(SystemSettings)
        )
        if settings_count.scalar() > 0:
            print("[SKIP] Seed data already exists, skipping...")
            await session.close()
            return

        # Import and run seed
        from app.common.seed import (
            seed_system_settings,
            seed_expense_categories,
            seed_income_categories,
        )

        # Seed system settings
        await seed_system_settings(session)
        print("[OK] System settings seeded")

        # Seed categories
        await seed_expense_categories(session)
        print("[OK] Expense categories seeded")

        await seed_income_categories(session)
        print("[OK] Income categories seeded")

        # Create admin user if not exists
        admin_stmt = select(User).where(User.username == "admin")
        admin_result = await session.execute(admin_stmt)
        if not admin_result.scalar_one_or_none():
            import uuid
            admin = User(
                id=str(uuid.uuid4()),
                username="admin",
                email="admin@familyfire.local",
                hashed_password=hash_password("Admin@123456"),
                full_name="系统管理员",
                role="admin",
                is_active=True,
                is_verified=True,
            )
            session.add(admin)
            print("[OK] Admin user created (admin / Admin@123456)")
        else:
            print("[SKIP] Admin user already exists")

        await session.commit()


async def main():
    """Run full database initialization."""
    print("=" * 50)
    print("Family Fire - Database Initialization")
    print("=" * 50)
    print()

    try:
        # Step 1: Create tables
        print("[1/2] Creating tables...")
        await create_tables()

        # Step 2: Seed data
        print("[2/2] Seeding data...")
        await seed_data()

        print()
        print("=" * 50)
        print("Database initialization complete!")
        print("=" * 50)
        print()
        print("Default admin login:")
        print("  Username: admin")
        print("  Password: Admin@123456")
        print()

    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
