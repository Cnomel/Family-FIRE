"""Price update tasks for Celery."""

import asyncio
from datetime import datetime

from celery import shared_task

from app.finance.providers.price_service import PriceProviderFactory


@shared_task
def update_all_prices():
    """Update prices for all financial assets.

    Runs daily at 15:05 (after A-share market close).
    """
    return asyncio.run(_update_all_prices_async())


async def _update_all_prices_async():
    """Async implementation of price update."""
    from sqlalchemy import select

    from app.assets.models import AssetMetadataFinancial
    from app.database import async_session_factory

    updated_count = 0
    failed_count = 0

    async with async_session_factory() as db:
        # Get all financial assets with ticker
        stmt = (
            select(AssetMetadataFinancial)
            .where(AssetMetadataFinancial.ticker.isnot(None))
        )
        result = await db.execute(stmt)
        metadata_list = result.scalars().all()

        for metadata in metadata_list:
            try:
                ticker = metadata.ticker
                if not ticker:
                    continue

                # Determine provider based on ticker
                is_chinese_stock = len(ticker) == 6 and ticker.isdigit() and ticker[0] in ('6', '0', '3')
                is_chinese_fund = len(ticker) == 6 and ticker.isdigit() and ticker[0] in ('1', '2', '5')

                if is_chinese_stock:
                    providers = ["china_stock"]
                    currency = "CNY"
                elif is_chinese_fund:
                    providers = ["china_fund"]
                    currency = "CNY"
                else:
                    # Try multiple providers
                    providers = ["china_stock", "china_fund", "yahoo"]
                    currency = "CNY"

                # Get price
                result = await PriceProviderFactory.get_price_with_fallback(
                    ticker, providers, currency
                )

                if result and result.get("price"):
                    # Update current price
                    metadata.current_price = result["price"]
                    updated_count += 1
                else:
                    failed_count += 1

            except Exception as e:
                print(f"Failed to update price for {metadata.ticker}: {e}")
                failed_count += 1

        # Commit changes
        await db.commit()

    return {
        "updated": updated_count,
        "failed": failed_count,
        "timestamp": datetime.now().isoformat(),
    }
