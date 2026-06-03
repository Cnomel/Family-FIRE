#!/usr/bin/env python3
"""Database initialization script.

Creates all tables and inserts seed data.
Safe to run multiple times (idempotent).

Includes:
- All database tables
- System settings
- Expense/income categories (支付宝/随手记标准)
- Asset categories (per family)
- Budget templates (per family)
- Admin user

Usage:
    uv run python scripts/init_db.py
"""

import asyncio
import sys
import uuid

from sqlalchemy import select, func
from sqlmodel import SQLModel


def _uuid() -> str:
    return str(uuid.uuid4())


# ============================================================
# Asset Categories (家庭级别)
# ============================================================

SYSTEM_ASSET_CATEGORIES = [
    {"name": "投资", "icon": "trending_up", "color": "#4CAF50", "sort_order": 1},
    {"name": "房产", "icon": "home", "color": "#2196F3", "sort_order": 2},
    {"name": "车辆", "icon": "directions_car", "color": "#FF9800", "sort_order": 3},
    {"name": "保险", "icon": "security", "color": "#9C27B0", "sort_order": 4},
    {"name": "收藏", "icon": "diamond", "color": "#E91E63", "sort_order": 5},
    {"name": "数码", "icon": "devices", "color": "#00BCD4", "sort_order": 6},
    {"name": "家居", "icon": "weekend", "color": "#795548", "sort_order": 7},
    {"name": "其他", "icon": "category", "color": "#607D8B", "sort_order": 8},
]


# ============================================================
# Expense Templates (固定支出项 - 家庭级别)
# ============================================================

SYSTEM_EXPENSE_TEMPLATES = [
    {"name": "房租/房贷", "icon": "home", "sort_order": 1, "expected_min": 0, "expected_max": 0},
    {"name": "水电燃气", "icon": "bolt", "sort_order": 2, "expected_min": 0, "expected_max": 0},
    {"name": "通讯费", "icon": "phone", "sort_order": 3, "expected_min": 0, "expected_max": 0},
    {"name": "餐饮", "icon": "restaurant", "sort_order": 4, "expected_min": 0, "expected_max": 0},
    {"name": "交通", "icon": "directions_car", "sort_order": 5, "expected_min": 0, "expected_max": 0},
    {"name": "保险", "icon": "security", "sort_order": 6, "expected_min": 0, "expected_max": 0},
    {"name": "日用品", "icon": "shopping_cart", "sort_order": 7, "expected_min": 0, "expected_max": 0},
    {"name": "医疗", "icon": "local_hospital", "sort_order": 8, "expected_min": 0, "expected_max": 0},
    {"name": "教育", "icon": "school", "sort_order": 9, "expected_min": 0, "expected_max": 0},
    {"name": "娱乐", "icon": "movie", "sort_order": 10, "expected_min": 0, "expected_max": 0},
]


# ============================================================
# Income Templates (固定收入项 - 家庭级别)
# ============================================================

SYSTEM_INCOME_TEMPLATES = [
    {"name": "工资", "icon": "work", "sort_order": 1},
    {"name": "奖金", "icon": "card_giftcard", "sort_order": 2},
    {"name": "投资收益", "icon": "trending_up", "sort_order": 3},
    {"name": "兼职", "icon": "business_center", "sort_order": 4},
]


# ============================================================
# Table Creation
# ============================================================

async def create_tables():
    """Create all database tables."""
    from app.database import engine

    # Import all models to register them with SQLModel metadata
    from app.users.models import User, SystemSettings  # noqa: F401
    from app.families.models import Family, FamilyMember  # noqa: F401
    from app.assets.models import (  # noqa: F401
        Asset, AssetCategory, AssetFinancial, AssetLifecycle, AssetRelationship,
        AssetMetadataVehicle, AssetMetadataRealEstate, AssetMetadataElectronics,
        AssetMetadataFurniture, AssetMetadataInsurance, AssetMetadataFinancial,
        AssetMetadataSubscription, AssetMetadataAccount, AssetMetadataConsumable,
    )
    from app.finance.models import (  # noqa: F401
        Liability, Transaction, ExpenseCategory, IncomeCategory,
        IncomeExpenseRecord, PriceSnapshot,
        ExpenseTemplate, IncomeTemplate, MonthlyBudgetRecord,
    )
    from app.documents.models import AssetDocument  # noqa: F401
    from app.notifications.models import Notification, NotificationPreference  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)

    print("[OK] All tables created/verified")


# ============================================================
# Seed Operations
# ============================================================

async def seed_system_settings(session) -> None:
    """Seed system settings."""
    from app.users.models import SystemSettings

    settings = [
        {"key": "max_families_per_user", "value": "3", "description": "每个用户可创建的最大家庭数"},
        {"key": "invite_code_expiry_days", "value": "7", "description": "邀请码有效天数"},
        {"key": "login_max_attempts", "value": "5", "description": "登录最大失败次数"},
        {"key": "login_lockout_minutes", "value": "30", "description": "登录锁定分钟数"},
        {"key": "max_upload_size_mb", "value": "20", "description": "最大上传文件大小(MB)"},
    ]

    for setting_data in settings:
        setting = SystemSettings(
            id=_uuid(),
            key=setting_data["key"],
            value=setting_data["value"],
            description=setting_data["description"],
        )
        session.add(setting)

    await session.flush()
    print("[OK] System settings seeded")


async def seed_expense_categories(session) -> None:
    """Seed expense categories (参考支付宝/随手记标准)."""
    from app.finance.models import ExpenseCategory

    categories = [
        # === 餐饮美食 ===
        {"name": "餐饮美食", "name_en": "Food & Dining", "icon": "food", "sort_order": 1, "children": [
            {"name": "早餐", "name_en": "Breakfast", "icon": "breakfast", "sort_order": 1},
            {"name": "午餐", "name_en": "Lunch", "icon": "lunch", "sort_order": 2},
            {"name": "晚餐", "name_en": "Dinner", "icon": "dinner", "sort_order": 3},
            {"name": "零食饮料", "name_en": "Snacks & Drinks", "icon": "snack", "sort_order": 4},
            {"name": "外卖", "name_en": "Takeout", "icon": "takeout", "sort_order": 5},
            {"name": "聚餐", "name_en": "Dining Out", "icon": "restaurant", "sort_order": 6},
        ]},
        # === 交通出行 ===
        {"name": "交通出行", "name_en": "Transportation", "icon": "transport", "sort_order": 2, "children": [
            {"name": "公共交通", "name_en": "Public Transit", "icon": "bus", "sort_order": 1},
            {"name": "打车", "name_en": "Taxi/Rideshare", "icon": "taxi", "sort_order": 2},
            {"name": "加油", "name_en": "Gas", "icon": "gas", "sort_order": 3},
            {"name": "停车", "name_en": "Parking", "icon": "parking", "sort_order": 4},
            {"name": "高速费", "name_en": "Toll", "icon": "toll", "sort_order": 5},
            {"name": "保养维修", "name_en": "Maintenance", "icon": "car_repair", "sort_order": 6},
        ]},
        # === 购物消费 ===
        {"name": "购物消费", "name_en": "Shopping", "icon": "shopping", "sort_order": 3, "children": [
            {"name": "日用品", "name_en": "Daily Necessities", "icon": "daily", "sort_order": 1},
            {"name": "服装鞋帽", "name_en": "Clothing", "icon": "clothing", "sort_order": 2},
            {"name": "数码电子", "name_en": "Electronics", "icon": "electronics", "sort_order": 3},
            {"name": "家居家装", "name_en": "Home & Furniture", "icon": "home", "sort_order": 4},
            {"name": "美妆护肤", "name_en": "Beauty", "icon": "beauty", "sort_order": 5},
        ]},
        # === 居住生活 ===
        {"name": "居住生活", "name_en": "Housing", "icon": "housing", "sort_order": 4, "children": [
            {"name": "房租", "name_en": "Rent", "icon": "rent", "sort_order": 1},
            {"name": "房贷", "name_en": "Mortgage", "icon": "mortgage", "sort_order": 2},
            {"name": "水电燃气", "name_en": "Utilities", "icon": "utilities", "sort_order": 3},
            {"name": "物业费", "name_en": "Property Management", "icon": "property", "sort_order": 4},
            {"name": "宽带通讯", "name_en": "Internet & Phone", "icon": "internet", "sort_order": 5},
        ]},
        # === 医疗健康 ===
        {"name": "医疗健康", "name_en": "Healthcare", "icon": "healthcare", "sort_order": 5, "children": [
            {"name": "门诊", "name_en": "Clinic", "icon": "clinic", "sort_order": 1},
            {"name": "药品", "name_en": "Medicine", "icon": "medicine", "sort_order": 2},
            {"name": "体检", "name_en": "Checkup", "icon": "checkup", "sort_order": 3},
            {"name": "保险", "name_en": "Insurance", "icon": "insurance", "sort_order": 4},
        ]},
        # === 教育培训 ===
        {"name": "教育培训", "name_en": "Education", "icon": "education", "sort_order": 6, "children": [
            {"name": "学费", "name_en": "Tuition", "icon": "tuition", "sort_order": 1},
            {"name": "书籍", "name_en": "Books", "icon": "books", "sort_order": 2},
            {"name": "培训课程", "name_en": "Courses", "icon": "courses", "sort_order": 3},
        ]},
        # === 休闲娱乐 ===
        {"name": "休闲娱乐", "name_en": "Entertainment", "icon": "entertainment", "sort_order": 7, "children": [
            {"name": "电影演出", "name_en": "Movies & Shows", "icon": "movie", "sort_order": 1},
            {"name": "旅游度假", "name_en": "Travel", "icon": "travel", "sort_order": 2},
            {"name": "运动健身", "name_en": "Sports & Fitness", "icon": "fitness", "sort_order": 3},
            {"name": "游戏充值", "name_en": "Gaming", "icon": "gaming", "sort_order": 4},
            {"name": "会员订阅", "name_en": "Subscriptions", "icon": "subscription", "sort_order": 5},
        ]},
        # === 人情往来 ===
        {"name": "人情往来", "name_en": "Social & Gifts", "icon": "social", "sort_order": 8, "children": [
            {"name": "红包", "name_en": "Red Envelope", "icon": "red_envelope", "sort_order": 1},
            {"name": "礼物", "name_en": "Gifts", "icon": "gift", "sort_order": 2},
            {"name": "请客", "name_en": "Treating", "icon": "treat", "sort_order": 3},
            {"name": "份子钱", "name_en": "Wedding/Baby Gift", "icon": "wedding", "sort_order": 4},
        ]},
        # === 金融支出 ===
        {"name": "金融支出", "name_en": "Financial", "icon": "financial", "sort_order": 9, "children": [
            {"name": "利息支出", "name_en": "Interest", "icon": "interest", "sort_order": 1},
            {"name": "手续费", "name_en": "Fees", "icon": "fees", "sort_order": 2},
            {"name": "投资亏损", "name_en": "Investment Loss", "icon": "loss", "sort_order": 3},
        ]},
        # === 其他支出 ===
        {"name": "其他支出", "name_en": "Other Expenses", "icon": "other", "sort_order": 10, "children": []},
    ]

    for cat_data in categories:
        parent_id = _uuid()
        parent = ExpenseCategory(
            id=parent_id,
            name=cat_data["name"],
            name_en=cat_data["name_en"],
            icon=cat_data["icon"],
            sort_order=cat_data["sort_order"],
            is_system=True,
        )
        session.add(parent)

        for child_data in cat_data.get("children", []):
            child = ExpenseCategory(
                id=_uuid(),
                name=child_data["name"],
                name_en=child_data["name_en"],
                icon=child_data["icon"],
                parent_id=parent_id,
                sort_order=child_data["sort_order"],
                is_system=True,
            )
            session.add(child)

    await session.flush()
    print("[OK] Expense categories seeded")


async def seed_income_categories(session) -> None:
    """Seed income categories."""
    from app.finance.models import IncomeCategory

    categories = [
        {"name": "工资薪金", "name_en": "Salary & Wages", "icon": "salary", "sort_order": 1, "children": []},
        {"name": "奖金", "name_en": "Bonus", "icon": "bonus", "sort_order": 2, "children": []},
        {"name": "投资收益", "name_en": "Investment Returns", "icon": "investment", "sort_order": 3, "children": [
            {"name": "利息收入", "name_en": "Interest", "icon": "interest", "sort_order": 1},
            {"name": "股息分红", "name_en": "Dividends", "icon": "dividend", "sort_order": 2},
            {"name": "资本利得", "name_en": "Capital Gains", "icon": "capital_gain", "sort_order": 3},
        ]},
        {"name": "副业收入", "name_en": "Side Income", "icon": "side_job", "sort_order": 4, "children": []},
        {"name": "租金收入", "name_en": "Rental Income", "icon": "rental", "sort_order": 5, "children": []},
        {"name": "报销", "name_en": "Reimbursement", "icon": "reimbursement", "sort_order": 6, "children": []},
        {"name": "其他收入", "name_en": "Other Income", "icon": "other", "sort_order": 7, "children": []},
    ]

    for cat_data in categories:
        parent_id = _uuid()
        parent = IncomeCategory(
            id=parent_id,
            name=cat_data["name"],
            name_en=cat_data["name_en"],
            icon=cat_data["icon"],
            sort_order=cat_data["sort_order"],
            is_system=True,
        )
        session.add(parent)

        for child_data in cat_data.get("children", []):
            child = IncomeCategory(
                id=_uuid(),
                name=child_data["name"],
                name_en=child_data["name_en"],
                icon=child_data["icon"],
                parent_id=parent_id,
                sort_order=child_data["sort_order"],
                is_system=True,
            )
            session.add(child)

    await session.flush()
    print("[OK] Income categories seeded")


async def seed_admin_user(session) -> None:
    """Create default admin user if not exists."""
    from app.users.models import User
    from app.common.security import hash_password

    admin_stmt = select(User).where(User.username == "admin")
    admin_result = await session.execute(admin_stmt)
    if not admin_result.scalar_one_or_none():
        admin = User(
            id=_uuid(),
            username="admin",
            email="admin@familyfire.local",
            hashed_password=hash_password("Admin@123456"),
            full_name="系统管理员",
            role="admin",
            is_active=True,
            is_verified=True,
        )
        session.add(admin)
        await session.flush()
        print("[OK] Admin user created (admin / Admin@123456)")
    else:
        print("[SKIP] Admin user already exists")


async def seed_family_data(session, family_id: str, family_name: str) -> None:
    """Seed system data for a specific family."""
    from app.assets.models import AssetCategory
    from app.finance.models import ExpenseTemplate, IncomeTemplate

    # Seed asset categories
    existing_cats = await session.execute(
        select(func.count()).select_from(AssetCategory).where(
            AssetCategory.family_id == family_id,
            AssetCategory.is_system.is_(True),
        )
    )
    if existing_cats.scalar() == 0:
        for cat_data in SYSTEM_ASSET_CATEGORIES:
            category = AssetCategory(
                id=_uuid(),
                family_id=family_id,
                name=cat_data["name"],
                icon=cat_data["icon"],
                color=cat_data["color"],
                sort_order=cat_data["sort_order"],
                is_system=True,
                created_by=None,
            )
            session.add(category)
        print(f"[OK] Asset categories seeded for family: {family_name}")

    # Seed expense templates
    existing_expense = await session.execute(
        select(func.count()).select_from(ExpenseTemplate).where(
            ExpenseTemplate.family_id == family_id,
            ExpenseTemplate.is_system.is_(True),
        )
    )
    if existing_expense.scalar() == 0:
        for template_data in SYSTEM_EXPENSE_TEMPLATES:
            template = ExpenseTemplate(
                id=_uuid(),
                family_id=family_id,
                name=template_data["name"],
                icon=template_data["icon"],
                expected_min=template_data["expected_min"],
                expected_max=template_data["expected_max"],
                is_fixed=True,
                is_system=True,
                sort_order=template_data["sort_order"],
                is_active=True,
                created_by="system",
            )
            session.add(template)
        print(f"[OK] Expense templates seeded for family: {family_name}")

    # Seed income templates
    existing_income = await session.execute(
        select(func.count()).select_from(IncomeTemplate).where(
            IncomeTemplate.family_id == family_id,
            IncomeTemplate.is_system.is_(True),
        )
    )
    if existing_income.scalar() == 0:
        for template_data in SYSTEM_INCOME_TEMPLATES:
            template = IncomeTemplate(
                id=_uuid(),
                family_id=family_id,
                name=template_data["name"],
                icon=template_data["icon"],
                is_fixed=True,
                is_system=True,
                sort_order=template_data["sort_order"],
                is_active=True,
                created_by="system",
            )
            session.add(template)
        print(f"[OK] Income templates seeded for family: {family_name}")


async def seed_all_families(session) -> None:
    """Seed system data for all existing families."""
    from app.families.models import Family

    families_stmt = select(Family)
    families_result = await session.execute(families_stmt)
    families = families_result.scalars().all()

    if not families:
        print("[SKIP] No families found, skipping family-level seed data")
        return

    for family in families:
        await seed_family_data(session, family.id, family.name)


async def seed_data():
    """Insert all seed data (skip if already exists)."""
    from app.database import async_session_factory

    async with async_session_factory() as session:
        # Check if seed data already exists
        from app.users.models import SystemSettings
        settings_count = await session.execute(
            select(func.count()).select_from(SystemSettings)
        )
        if settings_count.scalar() > 0:
            print("[SKIP] Seed data already exists, skipping global seed...")
        else:
            # Seed global data
            await seed_system_settings(session)
            await seed_expense_categories(session)
            await seed_income_categories(session)

        # Always check and seed admin user
        await seed_admin_user(session)

        # Seed family-level data
        await seed_all_families(session)

        await session.commit()


# ============================================================
# Main
# ============================================================

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
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
