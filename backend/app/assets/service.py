"""Asset management service with search, stats, and duplicate detection."""

import uuid
from typing import Any

from sqlalchemy import and_, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.assets.models import (
    Asset,
    AssetFinancial,
    AssetLifecycle,
    AssetMetadataAccount,
    AssetMetadataConsumable,
    AssetMetadataElectronics,
    AssetMetadataFinancial,
    AssetMetadataFurniture,
    AssetMetadataInsurance,
    AssetMetadataRealEstate,
    AssetMetadataSubscription,
    AssetMetadataVehicle,
)
from app.assets.schemas import (
    AssetDetailResponse,
    AssetFilterParams,
    AssetFinancialResponse,
    AssetListResponse,
    AssetResponse,
    AssetStatsResponse,
    BulkActionRequest,
    CreateAssetRequest,
    UpdateAssetRequest,
)
from app.common.exceptions import DuplicateError, NotFoundError, PermissionDeniedError
from app.common.logging import get_logger
from app.families.models import FamilyMember

logger = get_logger("asset_service")

# Map metadata_type to model classes
METADATA_MODELS = {
    "vehicle": AssetMetadataVehicle,
    "real_estate": AssetMetadataRealEstate,
    "electronics": AssetMetadataElectronics,
    "furniture": AssetMetadataFurniture,
    "insurance": AssetMetadataInsurance,
    "financial": AssetMetadataFinancial,
    "subscription": AssetMetadataSubscription,
    "account": AssetMetadataAccount,
    "consumable": AssetMetadataConsumable,
}


async def _verify_family_member(db: AsyncSession, family_id: str, user_id: str) -> None:
    """Verify user is a member of the family."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭的资产")


async def _check_duplicate(db: AsyncSession, family_id: str, name: str, nature: str) -> None:
    """Check for potential duplicate assets."""
    stmt = select(Asset).where(
        Asset.family_id == family_id,
        Asset.name == name,
        Asset.nature == nature,
        Asset.status == "active",
    )
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise DuplicateError("资产", "名称+类型", f"{name} ({nature})")


async def _find_asset_by_ticker(
    db: AsyncSession, family_id: str, ticker: str
) -> Asset | None:
    """Find an existing financial asset by ticker code."""
    from app.assets.models import AssetMetadataFinancial

    stmt = (
        select(Asset)
        .join(AssetMetadataFinancial, AssetMetadataFinancial.asset_id == Asset.id)
        .where(
            Asset.family_id == family_id,
            Asset.nature == "financial",
            Asset.status == "active",
            AssetMetadataFinancial.ticker == ticker,
        )
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def _find_asset_by_name(
    db: AsyncSession, family_id: str, name: str
) -> Asset | None:
    """Find an existing financial asset by name."""
    stmt = select(Asset).where(
        Asset.family_id == family_id,
        Asset.name == name,
        Asset.nature == "financial",
        Asset.status == "active",
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def _add_purchase_to_existing_asset(
    db: AsyncSession, existing_asset: Asset, user_id: str, data: CreateAssetRequest
) -> AssetResponse:
    """Add a new purchase transaction to an existing financial asset."""
    from app.finance.models import Transaction

    # Create a buy transaction
    shares = data.metadata.get("shares", 0) if data.metadata else 0
    transaction = Transaction(
        id=str(uuid.uuid4()),
        asset_id=existing_asset.id,
        family_id=existing_asset.family_id,
        created_by=user_id,
        type="buy",
        quantity=float(shares) if shares else None,
        price=data.purchase_price / float(shares) if shares and data.purchase_price else None,
        total=data.purchase_price,
        date=data.purchase_date or utcnow(),
    )
    db.add(transaction)
    await db.flush()

    # Sync asset financial data
    await _sync_asset_financial(db, existing_asset.id)

    logger.info(
        "purchase_added_to_existing_asset",
        asset_id=existing_asset.id,
        ticker=data.metadata.get("ticker"),
        shares=shares,
        total=data.purchase_price,
    )

    # Return the updated asset
    financial_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == existing_asset.id)
    financial_result = await db.execute(financial_stmt)
    financial = financial_result.scalar_one_or_none()

    return _asset_to_response(existing_asset, financial)


async def _sync_asset_financial(db: AsyncSession, asset_id: str) -> None:
    """Sync asset financial data based on transactions."""
    from app.finance.models import Transaction
    from app.assets.models import AssetFinancial, AssetMetadataFinancial

    # Calculate net shares and cost from transactions
    buy_shares = (await db.execute(
        select(func.coalesce(func.sum(Transaction.quantity), 0))
        .where(Transaction.asset_id == asset_id, Transaction.type == "buy")
    )).scalar() or 0

    sell_shares = (await db.execute(
        select(func.coalesce(func.sum(Transaction.quantity), 0))
        .where(Transaction.asset_id == asset_id, Transaction.type == "sell")
    )).scalar() or 0

    buy_total = (await db.execute(
        select(func.coalesce(func.sum(Transaction.total), 0))
        .where(Transaction.asset_id == asset_id, Transaction.type == "buy")
    )).scalar() or 0

    net_shares = buy_shares - sell_shares

    # Calculate remaining cost
    if buy_shares > 0 and sell_shares > 0:
        avg_buy_price = buy_total / buy_shares
        cost_of_sold = avg_buy_price * sell_shares
        remaining_cost = buy_total - cost_of_sold
    else:
        remaining_cost = buy_total

    # Update AssetMetadataFinancial
    metadata_stmt = select(AssetMetadataFinancial).where(AssetMetadataFinancial.asset_id == asset_id)
    metadata_result = await db.execute(metadata_stmt)
    metadata = metadata_result.scalar_one_or_none()

    current_price = None
    if metadata:
        metadata.shares = net_shares if net_shares > 0 else None
        metadata.average_cost_basis = (remaining_cost / net_shares) if net_shares > 0 else None
        # Update current_price from latest transaction
        last_tx = (await db.execute(
            select(Transaction)
            .where(Transaction.asset_id == asset_id, Transaction.price.isnot(None))
            .order_by(Transaction.date.desc())
            .limit(1)
        )).scalar_one_or_none()
        if last_tx and last_tx.price:
            metadata.current_price = last_tx.price
            current_price = last_tx.price
        else:
            current_price = metadata.current_price
        await db.flush()

    # Update AssetFinancial.current_value based on market price
    financial_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    financial_result = await db.execute(financial_stmt)
    financial = financial_result.scalar_one_or_none()

    if financial:
        # 优先使用市场价计算，没有则用成本价
        if current_price and net_shares > 0:
            financial.current_value = current_price * net_shares
        else:
            financial.current_value = remaining_cost
        await db.flush()


def _asset_to_response(asset: Asset, financial: AssetFinancial | None = None) -> AssetResponse:
    """Convert Asset model to response."""
    tags = asset.tags if asset.tags else None
    return AssetResponse(
        id=asset.id,
        name=asset.name,
        description=asset.description,
        nature=asset.nature,
        utility=asset.utility,
        ownership=asset.ownership,
        liquidity=asset.liquidity,
        tags=tags,
        status=asset.status,
        financial=AssetFinancialResponse(
            purchase_price=financial.purchase_price if financial else 0,
            purchase_date=financial.purchase_date if financial else None,
            currency=financial.currency if financial else "CNY",
            current_value=financial.current_value if financial else 0,
            last_valuation_date=financial.last_valuation_date if financial else None,
            total_cost_of_ownership=financial.total_cost_of_ownership if financial else 0,
            monthly_carrying_cost=financial.monthly_carrying_cost if financial else 0,
        ) if financial else None,
        created_at=asset.created_at,
    )


async def create_asset(
    db: AsyncSession, family_id: str, user_id: str, data: CreateAssetRequest
) -> AssetResponse:
    """Create a new asset or add transaction to existing financial asset.

    For financial assets, check if similar asset already exists:
    1. First check by ticker (if provided)
    2. Then check by name + nature

    If found, add a transaction to the existing asset instead of creating a new one.

    Raises:
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    # For financial assets, try to find existing asset to merge
    if data.nature == "financial":
        existing_asset = None
        ticker = data.metadata.get("ticker") if data.metadata else None

        # Try to find by ticker first
        if ticker:
            existing_asset = await _find_asset_by_ticker(db, family_id, ticker)

        # If not found by ticker, try by name
        if not existing_asset:
            existing_asset = await _find_asset_by_name(db, family_id, data.name)

        if existing_asset:
            # Add transaction to existing asset
            return await _add_purchase_to_existing_asset(
                db, existing_asset, user_id, data
            )

    # For non-financial assets or no existing asset found, create new
    # Check duplicate by name for non-financial assets
    if data.nature != "financial":
        await _check_duplicate(db, family_id, data.name, data.nature)

    asset_id = str(uuid.uuid4())

    # Create asset
    asset = Asset(
        id=asset_id,
        family_id=family_id,
        created_by=user_id,
        name=data.name,
        description=data.description,
        nature=data.nature,
        utility=data.utility,
        ownership=data.ownership,
        liquidity=data.liquidity,
        tags=data.tags,
        custom_fields=data.custom_fields,
        status="active",
    )
    db.add(asset)

    # Create financial record
    financial = AssetFinancial(
        id=str(uuid.uuid4()),
        asset_id=asset_id,
        purchase_price=data.purchase_price,
        purchase_date=data.purchase_date,
        currency=data.currency,
        current_value=data.purchase_price,  # Initial value = purchase price
    )
    db.add(financial)

    # Create lifecycle record
    lifecycle = AssetLifecycle(
        id=str(uuid.uuid4()),
        asset_id=asset_id,
        trajectory=_infer_trajectory(data.nature, data.utility),
    )
    db.add(lifecycle)

    # Create type-specific metadata if provided
    if data.metadata_type and data.metadata:
        model_class = METADATA_MODELS.get(data.metadata_type)
        if model_class:
            meta = model_class(
                id=str(uuid.uuid4()),
                asset_id=asset_id,
                **data.metadata,
            )
            db.add(meta)

    await db.flush()
    logger.info("asset_created", asset_id=asset_id, family_id=family_id, name=data.name)

    return _asset_to_response(asset, financial)


def _infer_trajectory(nature: str, utility: str) -> str:
    """Infer lifecycle trajectory from classification."""
    if nature == "financial" and utility in ("speculative", "productive"):
        return "volatile"
    if nature == "service" or utility == "protective":
        return "expiring"
    if utility == "consumable":
        return "consumable"
    if nature == "tangible" and utility in ("essential", "lifestyle"):
        return "depreciating"
    if nature == "tangible" and utility == "productive":
        return "appreciating"
    return "stable"


async def get_asset_detail(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str
) -> AssetDetailResponse:
    """Get detailed asset information.

    Raises:
        NotFoundError: If asset not found.
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    # Get financial info
    fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    fin_result = await db.execute(fin_stmt)
    financial = fin_result.scalar_one_or_none()

    # Get metadata
    metadata = None
    metadata_type = None
    for type_name, model_class in METADATA_MODELS.items():
        meta_stmt = select(model_class).where(model_class.asset_id == asset_id)
        meta_result = await db.execute(meta_stmt)
        meta = meta_result.scalar_one_or_none()
        if meta:
            metadata_type = type_name
            # Convert to dict, excluding internal fields
            metadata = {k: v for k, v in meta.__dict__.items()
                       if not k.startswith("_") and k not in ("id", "asset_id", "created_at", "updated_at")}
            break

    return AssetDetailResponse(
        id=asset.id,
        name=asset.name,
        description=asset.description,
        nature=asset.nature,
        utility=asset.utility,
        ownership=asset.ownership,
        liquidity=asset.liquidity,
        tags=asset.tags,
        status=asset.status,
        custom_fields=asset.custom_fields,
        financial=AssetFinancialResponse(
            purchase_price=financial.purchase_price if financial else 0,
            purchase_date=financial.purchase_date if financial else None,
            currency=financial.currency if financial else "CNY",
            current_value=financial.current_value if financial else 0,
            last_valuation_date=financial.last_valuation_date if financial else None,
            total_cost_of_ownership=financial.total_cost_of_ownership if financial else 0,
            monthly_carrying_cost=financial.monthly_carrying_cost if financial else 0,
        ) if financial else None,
        metadata=metadata,
        metadata_type=metadata_type,
        created_at=asset.created_at,
    )


async def list_assets(
    db: AsyncSession, family_id: str, user_id: str, filters: AssetFilterParams
) -> AssetListResponse:
    """List assets with filtering and pagination."""
    await _verify_family_member(db, family_id, user_id)

    # Build query
    conditions = [
        Asset.family_id == family_id,
        Asset.status == filters.status,
    ]

    if filters.nature:
        conditions.append(Asset.nature == filters.nature)
    if filters.utility:
        conditions.append(Asset.utility == filters.utility)
    if filters.ownership:
        conditions.append(Asset.ownership == filters.ownership)
    if filters.liquidity:
        conditions.append(Asset.liquidity == filters.liquidity)
    if filters.search:
        search_term = f"%{filters.search}%"
        conditions.append(
            or_(
                Asset.name.ilike(search_term),
                Asset.description.ilike(search_term),
            )
        )

    # Count total
    count_stmt = select(func.count()).select_from(Asset).where(and_(*conditions))
    count_result = await db.execute(count_stmt)
    total = count_result.scalar()

    # Get assets with pagination
    offset = (filters.page - 1) * filters.page_size
    stmt = (
        select(Asset)
        .where(and_(*conditions))
        .order_by(Asset.created_at.desc())
        .offset(offset)
        .limit(filters.page_size)
    )
    result = await db.execute(stmt)
    assets = result.scalars().all()

    # Get financial info for each asset
    responses = []
    for asset in assets:
        fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset.id)
        fin_result = await db.execute(fin_stmt)
        financial = fin_result.scalar_one_or_none()
        responses.append(_asset_to_response(asset, financial))

    return AssetListResponse(
        assets=responses,
        total=total,
        page=filters.page,
        page_size=filters.page_size,
    )


async def update_asset(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str, data: UpdateAssetRequest
) -> AssetResponse:
    """Update an asset.

    Raises:
        NotFoundError: If asset not found.
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    # Update fields
    if data.name is not None:
        asset.name = data.name
    if data.description is not None:
        asset.description = data.description
    if data.nature is not None:
        asset.nature = data.nature
    if data.utility is not None:
        asset.utility = data.utility
    if data.ownership is not None:
        asset.ownership = data.ownership
    if data.liquidity is not None:
        asset.liquidity = data.liquidity
    if data.tags is not None:
        asset.tags = data.tags
    if data.custom_fields is not None:
        asset.custom_fields = data.custom_fields
    if data.status is not None:
        asset.status = data.status

    await db.flush()
    logger.info("asset_updated", asset_id=asset_id)

    # Get financial info
    fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    fin_result = await db.execute(fin_stmt)
    financial = fin_result.scalar_one_or_none()

    return _asset_to_response(asset, financial)


async def delete_asset(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str
) -> None:
    """Soft delete (archive) an asset.

    Raises:
        NotFoundError: If asset not found.
        PermissionDeniedError: If user is not a family member.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    asset.status = "archived"
    await db.flush()
    logger.info("asset_archived", asset_id=asset_id)


async def bulk_action(
    db: AsyncSession, family_id: str, user_id: str, data: BulkActionRequest
) -> dict[str, Any]:
    """Perform bulk action on multiple assets."""
    await _verify_family_member(db, family_id, user_id)

    success_count = 0
    for asset_id in data.asset_ids:
        stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
        result = await db.execute(stmt)
        asset = result.scalar_one_or_none()

        if not asset:
            continue

        if data.action == "archive":
            asset.status = "archived"
            success_count += 1
        elif data.action == "delete":
            asset.status = "disposed"
            success_count += 1
        elif data.action == "tag" and data.tag:
            tags = asset.tags or []
            if data.tag not in tags:
                tags.append(data.tag)
                asset.tags = tags
            success_count += 1

    await db.flush()
    logger.info("bulk_action", action=data.action, count=success_count)

    return {"success_count": success_count, "total": len(data.asset_ids)}


async def add_tag(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str, tag: str
) -> None:
    """Add a tag to an asset."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    tags = asset.tags or []
    if tag not in tags:
        tags.append(tag)
        asset.tags = tags
        await db.flush()


async def remove_tag(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str, tag: str
) -> None:
    """Remove a tag from an asset."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()

    if not asset:
        raise NotFoundError("资产", asset_id)

    tags = asset.tags or []
    if tag in tags:
        tags.remove(tag)
        asset.tags = tags
        await db.flush()


async def get_all_tags(
    db: AsyncSession, family_id: str, user_id: str
) -> list[dict[str, Any]]:
    """Get all unique tags used in the family's assets."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Asset.tags).where(
        Asset.family_id == family_id,
        Asset.status == "active",
        Asset.tags.isnot(None),
    )
    result = await db.execute(stmt)
    all_tags = result.scalars().all()

    # Count tag usage
    tag_counts: dict[str, int] = {}
    for tags in all_tags:
        if isinstance(tags, list):
            for tag in tags:
                tag_counts[tag] = tag_counts.get(tag, 0) + 1

    return [{"tag": tag, "count": count} for tag, count in sorted(tag_counts.items(), key=lambda x: -x[1])]


async def get_asset_stats(
    db: AsyncSession, family_id: str, user_id: str
) -> AssetStatsResponse:
    """Get asset statistics grouped by dimensions."""
    await _verify_family_member(db, family_id, user_id)

    # Get all active assets with financial info
    stmt = (
        select(Asset, AssetFinancial)
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id, isouter=True)
        .where(Asset.family_id == family_id, Asset.status == "active")
    )
    result = await db.execute(stmt)
    rows = result.all()

    total_count = len(rows)
    total_value = 0
    by_nature: dict[str, dict] = {}
    by_utility: dict[str, dict] = {}
    by_ownership: dict[str, dict] = {}
    by_liquidity: dict[str, dict] = {}

    for asset, financial in rows:
        value = financial.current_value if financial else 0
        total_value += value

        # Group by nature
        if asset.nature not in by_nature:
            by_nature[asset.nature] = {"count": 0, "value": 0}
        by_nature[asset.nature]["count"] += 1
        by_nature[asset.nature]["value"] += value

        # Group by utility
        if asset.utility not in by_utility:
            by_utility[asset.utility] = {"count": 0, "value": 0}
        by_utility[asset.utility]["count"] += 1
        by_utility[asset.utility]["value"] += value

        # Group by ownership
        if asset.ownership not in by_ownership:
            by_ownership[asset.ownership] = {"count": 0, "value": 0}
        by_ownership[asset.ownership]["count"] += 1
        by_ownership[asset.ownership]["value"] += value

        # Group by liquidity
        if asset.liquidity not in by_liquidity:
            by_liquidity[asset.liquidity] = {"count": 0, "value": 0}
        by_liquidity[asset.liquidity]["count"] += 1
        by_liquidity[asset.liquidity]["value"] += value

    return AssetStatsResponse(
        total_count=total_count,
        total_value=total_value,
        by_nature=by_nature,
        by_utility=by_utility,
        by_ownership=by_ownership,
        by_liquidity=by_liquidity,
    )
