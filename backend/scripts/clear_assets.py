#!/usr/bin/env python3
"""Clear all asset data from database.

This script deletes all data from asset-related tables.
Use with caution - this operation cannot be undone!

Usage:
    uv run python scripts/clear_assets.py
"""

import asyncio
import sys

from sqlalchemy import text


async def clear_assets():
    """Delete all asset data."""
    from app.database import engine

    async with engine.begin() as conn:
        # Delete in correct order to respect foreign keys
        tables = [
            'asset_relationships',
            'asset_documents',
            'asset_lifecycles',
            'asset_financial',
            'asset_metadata_vehicle',
            'asset_metadata_real_estate',
            'asset_metadata_electronics',
            'asset_metadata_furniture',
            'asset_metadata_insurance',
            'asset_metadata_financial',
            'asset_metadata_subscription',
            'asset_metadata_account',
            'asset_metadata_consumable',
            'transactions',
            'price_snapshots',
            'assets',
        ]
        
        for table in tables:
            result = await conn.execute(text(f"DELETE FROM {table}"))
            print(f"[OK] Cleared {table}: {result.rowcount} rows deleted")


async def main():
    """Run clear operation."""
    print("=" * 50)
    print("Clear Asset Data")
    print("=" * 50)
    print()
    print("WARNING: This will delete ALL asset data!")
    print()
    
    confirm = input("Type 'yes' to confirm: ")
    if confirm.lower() != 'yes':
        print("Cancelled.")
        return
    
    print()
    try:
        await clear_assets()
        print()
        print("All asset data has been cleared!")
    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
