#!/usr/bin/env python3
"""Seed budget templates for existing families.

Creates system preset expense and income templates for all families.

Usage:
    uv run python scripts/seed_budget_templates.py
"""

import asyncio
import sys
import uuid

from sqlalchemy import select, func

# System preset expense templates
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

# System preset income templates
SYSTEM_INCOME_TEMPLATES = [
    {"name": "工资", "icon": "work", "sort_order": 1},
    {"name": "奖金", "icon": "card_giftcard", "sort_order": 2},
    {"name": "投资收益", "icon": "trending_up", "sort_order": 3},
    {"name": "兼职", "icon": "business_center", "sort_order": 4},
]


async def seed_budget_templates():
    """Create system preset budget templates for all families."""
    from app.database import async_session_factory
    from app.families.models import Family
    from app.finance.models import ExpenseTemplate, IncomeTemplate

    async with async_session_factory() as session:
        # Get all families
        families_stmt = select(Family)
        families_result = await session.execute(families_stmt)
        families = families_result.scalars().all()

        if not families:
            print("[SKIP] No families found")
            return

        total_expense = 0
        total_income = 0

        for family in families:
            # Check if templates already exist for this family
            existing_expense = await session.execute(
                select(func.count()).select_from(ExpenseTemplate).where(
                    ExpenseTemplate.family_id == family.id,
                    ExpenseTemplate.is_system == True,
                )
            )
            if existing_expense.scalar() > 0:
                print(f"[SKIP] Family {family.name} already has system templates")
                continue

            # Create expense templates
            for template_data in SYSTEM_EXPENSE_TEMPLATES:
                template = ExpenseTemplate(
                    id=str(uuid.uuid4()),
                    family_id=family.id,
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
                total_expense += 1

            # Create income templates
            for template_data in SYSTEM_INCOME_TEMPLATES:
                template = IncomeTemplate(
                    id=str(uuid.uuid4()),
                    family_id=family.id,
                    name=template_data["name"],
                    icon=template_data["icon"],
                    is_fixed=True,
                    is_system=True,
                    sort_order=template_data["sort_order"],
                    is_active=True,
                    created_by="system",
                )
                session.add(template)
                total_income += 1

            print(f"[OK] Created templates for family: {family.name}")

        await session.commit()
        print(f"\n[SUMMARY] Created {total_expense} expense templates, {total_income} income templates")


async def main():
    """Run budget templates seeding."""
    print("=" * 50)
    print("Family Fire - Seed Budget Templates")
    print("=" * 50)
    print()

    try:
        await seed_budget_templates()
        print()
        print("=" * 50)
        print("Budget templates seeding complete!")
        print("=" * 50)

    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
