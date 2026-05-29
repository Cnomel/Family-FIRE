"""Seed data for initial database setup.

Contains:
- Standard expense categories (参考支付宝/随手记)
- Standard income categories
- Default system settings
- Default admin user
"""

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.common.security import hash_password
from app.finance.models import ExpenseCategory, IncomeCategory
from app.users.models import SystemSettings, User


def _uuid() -> str:
    return str(uuid.uuid4())


# ============================================================
# Expense Categories (支出分类 — 参考支付宝/随手记标准)
# ============================================================

EXPENSE_CATEGORIES: list[dict] = [
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


# ============================================================
# Income Categories (收入分类)
# ============================================================

INCOME_CATEGORIES: list[dict] = [
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


# ============================================================
# Default System Settings
# ============================================================

DEFAULT_SETTINGS: list[dict] = [
    {"key": "max_families_per_user", "value": "3", "description": "每个用户可创建的最大家庭数"},
    {"key": "invite_code_expiry_days", "value": "7", "description": "邀请码有效天数"},
    {"key": "login_max_attempts", "value": "5", "description": "登录最大失败次数"},
    {"key": "login_lockout_minutes", "value": "30", "description": "登录锁定分钟数"},
    {"key": "max_upload_size_mb", "value": "20", "description": "最大上传文件大小(MB)"},
]


async def seed_expense_categories(session: AsyncSession) -> None:
    """Seed expense categories."""
    for cat_data in EXPENSE_CATEGORIES:
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


async def seed_income_categories(session: AsyncSession) -> None:
    """Seed income categories."""
    for cat_data in INCOME_CATEGORIES:
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


async def seed_system_settings(session: AsyncSession) -> None:
    """Seed system settings."""
    for setting_data in DEFAULT_SETTINGS:
        setting = SystemSettings(
            id=_uuid(),
            key=setting_data["key"],
            value=setting_data["value"],
            description=setting_data["description"],
        )
        session.add(setting)

    await session.flush()


async def seed_admin_user(session: AsyncSession) -> None:
    """Create default admin user."""
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


async def seed_all(session: AsyncSession) -> None:
    """Run all seed operations."""
    await seed_system_settings(session)
    await seed_admin_user(session)
    await seed_expense_categories(session)
    await seed_income_categories(session)
    await session.commit()
