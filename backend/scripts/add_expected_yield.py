#!/usr/bin/env python3
"""Add expected_yield and annual_income columns to asset_metadata_financial table.

- expected_yield: Expected annual yield rate for stable products (deposits/bonds)
- annual_income: Actual annual income amount for products with uncertain returns (funds)

Usage:
    uv run python scripts/add_expected_yield.py
"""

import asyncio
import sys

from sqlalchemy import text


async def add_columns():
    """Add columns if they don't exist."""
    from app.database import engine

    async with engine.begin() as conn:
        # Check and add expected_yield column
        result = await conn.execute(text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = 'asset_metadata_financial' "
            "AND column_name = 'expected_yield'"
        ))
        if result.scalar_one_or_none():
            print("[SKIP] Column expected_yield already exists")
        else:
            await conn.execute(text(
                "ALTER TABLE asset_metadata_financial "
                "ADD COLUMN expected_yield DOUBLE PRECISION"
            ))
            print("[OK] Column expected_yield added")

        # Check and add annual_income column
        result = await conn.execute(text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = 'asset_metadata_financial' "
            "AND column_name = 'annual_income'"
        ))
        if result.scalar_one_or_none():
            print("[SKIP] Column annual_income already exists")
        else:
            await conn.execute(text(
                "ALTER TABLE asset_metadata_financial "
                "ADD COLUMN annual_income DOUBLE PRECISION"
            ))
            print("[OK] Column annual_income added")


async def main():
    """Run migration."""
    print("=" * 50)
    print("Add passive income columns")
    print("=" * 50)
    print()

    try:
        await add_columns()
        print()
        print("Migration complete!")
    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
