"""Asset management service with search, stats, and duplicate detection."""

import uuid
from typing import Any

from sqlalchemy import and_, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.assets.models import (
    Asset,
    AssetCategory,
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
    CategoryResponse,
    CreateAssetRequest,
    CreateCategoryRequest,
    UpdateAssetRequest,
    UpdateCategoryRequest,
)
from app.common.exceptions import DuplicateError, NotFoundError, PermissionDeniedError
from app.common.logging import get_logger
from app.common.utils import utcnow
from app.families.models import FamilyMember
from app.finance.models import Transaction

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
    from app.assets.models import AssetFinancial, AssetMetadataFinancial
    from app.finance.models import Transaction
    from app.finance.providers.price_service import PriceProviderFactory

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

    if metadata:
        metadata.shares = net_shares if net_shares > 0 else None
        metadata.average_cost_basis = (remaining_cost / net_shares) if net_shares > 0 else None

        # 查询最新价格
        ticker = metadata.ticker
        if ticker:
            try:
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
                    providers = ["china_stock", "china_fund", "yahoo"]
                    currency = "CNY"

                result = await PriceProviderFactory.get_price_with_fallback(ticker, providers, currency)
                if result and result.get("price"):
                    metadata.current_price = result["price"]
            except Exception:
                # 查询失败保留原价格
                pass

        await db.flush()

    # Update AssetFinancial - 更新成本和当前价值
    financial_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    financial_result = await db.execute(financial_stmt)
    financial = financial_result.scalar_one_or_none()

    if financial:
        # 更新成本为剩余成本
        financial.purchase_price = remaining_cost

        # 使用实时价格计算当前价值
        current_price = metadata.current_price if metadata else None
        if current_price and net_shares > 0:
            financial.current_value = current_price * net_shares
        else:
            financial.current_value = remaining_cost
        await db.flush()


def _asset_to_response(
    asset: Asset,
    financial: AssetFinancial | None = None,
    creator_name: str | None = None,
    instrument_type: str | None = None,
    category_name: str | None = None,
    category_icon: str | None = None,
    category_color: str | None = None,
) -> AssetResponse:
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
        instrument_type=instrument_type,
        category_id=asset.category_id,
        category_name=category_name,
        category_icon=category_icon,
        category_color=category_color,
        created_by=asset.created_by,
        created_by_name=creator_name,
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
    # 只有有 ticker 的金融资产（股票、基金、ETF）才合并，定期/国债等不合并
    if data.nature == "financial":
        existing_asset = None
        ticker = data.metadata.get("ticker") if data.metadata else None

        # 只有有 ticker 时才查找已有资产（股票/基金支持多次买入同一标的）
        if ticker:
            existing_asset = await _find_asset_by_ticker(db, family_id, ticker)

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

    # For financial assets with shares, create an initial buy transaction
    if data.nature == "financial" and data.metadata:
        shares = data.metadata.get("shares")
        if shares and shares > 0:
            # Calculate price per share
            price_per_share = data.purchase_price / shares if shares > 0 else 0

            # 移除时区信息，确保是 naive datetime
            tx_date = data.purchase_date or utcnow()
            if tx_date.tzinfo:
                tx_date = tx_date.replace(tzinfo=None)

            transaction = Transaction(
                id=str(uuid.uuid4()),
                asset_id=asset_id,
                family_id=family_id,
                created_by=user_id,
                type="buy",
                date=tx_date,
                quantity=shares,
                price=price_per_share,
                total=data.purchase_price,
                notes="初始买入",
            )
            db.add(transaction)
            await db.flush()

            # Sync financial values only when we have transactions
            await _sync_asset_financial(db, asset_id)

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

    # Get creator name
    creator_name = None
    if asset.created_by:
        from app.users.models import User
        user_stmt = select(User.full_name, User.username).where(User.id == asset.created_by)
        user_result = await db.execute(user_stmt)
        user_row = user_result.first()
        if user_row:
            creator_name = user_row.full_name or user_row.username

    # Get category info
    category_name = None
    category_icon = None
    category_color = None
    if asset.category_id:
        cat_stmt = select(AssetCategory).where(AssetCategory.id == asset.category_id)
        cat_result = await db.execute(cat_stmt)
        category = cat_result.scalar_one_or_none()
        if category:
            category_name = category.name
            category_icon = category.icon
            category_color = category.color

    # Get relationships
    from app.assets.models import AssetRelationship
    rel_stmt = select(AssetRelationship).where(
        or_(
            AssetRelationship.source_asset_id == asset_id,
            AssetRelationship.target_asset_id == asset_id,
        )
    )
    rel_result = await db.execute(rel_stmt)
    relationships = rel_result.scalars().all()

    rel_list = []
    for rel in relationships:
        rel_list.append({
            "id": rel.id,
            "source_asset_id": rel.source_asset_id,
            "target_asset_id": rel.target_asset_id,
            "type": rel.type,
            "is_optional": rel.is_optional,
            "lifecycle_linked": rel.lifecycle_linked,
            "extra_data": rel.extra_data,
        })

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
        relationships=rel_list,
        category_id=asset.category_id,
        category_name=category_name,
        category_icon=category_icon,
        category_color=category_color,
        created_by=asset.created_by,
        created_by_name=creator_name,
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

    # Get unique creator IDs
    creator_ids = list({asset.created_by for asset in assets if asset.created_by})

    # Batch query creator names
    creator_names = {}
    if creator_ids:
        from app.users.models import User
        user_stmt = select(User.id, User.full_name, User.username).where(User.id.in_(creator_ids))
        user_result = await db.execute(user_stmt)
        for row in user_result.all():
            creator_names[row.id] = row.full_name or row.username

    # Get unique category IDs
    category_ids = list({asset.category_id for asset in assets if asset.category_id})

    # Batch query category info
    category_info = {}
    if category_ids:
        cat_stmt = select(AssetCategory).where(AssetCategory.id.in_(category_ids))
        cat_result = await db.execute(cat_stmt)
        for cat in cat_result.scalars().all():
            category_info[cat.id] = {
                'name': cat.name,
                'icon': cat.icon,
                'color': cat.color,
            }

    # Get financial info and metadata for each asset
    responses = []
    for asset in assets:
        fin_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset.id)
        fin_result = await db.execute(fin_stmt)
        financial = fin_result.scalar_one_or_none()

        # Get instrument_type from metadata for financial assets
        instrument_type = None
        if asset.nature == 'financial':
            meta_stmt = select(AssetMetadataFinancial.instrument_type).where(
                AssetMetadataFinancial.asset_id == asset.id
            )
            meta_result = await db.execute(meta_stmt)
            instrument_type_row = meta_result.scalar_one_or_none()
            if instrument_type_row:
                instrument_type = instrument_type_row

        creator_name = creator_names.get(asset.created_by)
        cat_info = category_info.get(asset.category_id, {})
        responses.append(_asset_to_response(
            asset, financial, creator_name, instrument_type,
            category_name=cat_info.get('name'),
            category_icon=cat_info.get('icon'),
            category_color=cat_info.get('color'),
        ))

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
    if data.category_id is not None:
        asset.category_id = data.category_id
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

    # Get category info
    category_name = None
    category_icon = None
    category_color = None
    if asset.category_id:
        cat_stmt = select(AssetCategory).where(AssetCategory.id == asset.category_id)
        cat_result = await db.execute(cat_stmt)
        category = cat_result.scalar_one_or_none()
        if category:
            category_name = category.name
            category_icon = category.icon
            category_color = category.color

    return _asset_to_response(
        asset, financial,
        category_name=category_name,
        category_icon=category_icon,
        category_color=category_color,
    )


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


# ============================================================
# Category Management
# ============================================================

async def create_category(
    db: AsyncSession, family_id: str, user_id: str, data: CreateCategoryRequest
) -> CategoryResponse:
    """Create a new asset category."""
    await _verify_family_member(db, family_id, user_id)

    category = AssetCategory(
        id=str(uuid.uuid4()),
        family_id=family_id,
        name=data.name,
        icon=data.icon,
        color=data.color,
        sort_order=0,
        is_system=False,
        created_by=user_id,
    )
    db.add(category)
    await db.flush()

    return CategoryResponse(
        id=category.id,
        name=category.name,
        icon=category.icon,
        color=category.color,
        sort_order=category.sort_order,
        is_system=category.is_system,
        asset_count=0,
        total_value=0,
        created_at=category.created_at,
    )


async def list_categories(
    db: AsyncSession, family_id: str, user_id: str
) -> list[CategoryResponse]:
    """List all asset categories for a family."""
    await _verify_family_member(db, family_id, user_id)

    stmt = (
        select(AssetCategory)
        .where(AssetCategory.family_id == family_id)
        .order_by(AssetCategory.sort_order, AssetCategory.created_at)
    )
    result = await db.execute(stmt)
    categories = result.scalars().all()

    responses = []
    for cat in categories:
        # Count assets in this category
        count_stmt = select(func.count()).select_from(Asset).where(
            Asset.category_id == cat.id,
            Asset.status == "active",
        )
        count_result = await db.execute(count_stmt)
        asset_count = count_result.scalar() or 0

        # Sum value of assets in this category
        value_stmt = (
            select(func.coalesce(func.sum(AssetFinancial.current_value), 0))
            .join(Asset, Asset.id == AssetFinancial.asset_id)
            .where(
                Asset.category_id == cat.id,
                Asset.status == "active",
            )
        )
        value_result = await db.execute(value_stmt)
        total_value = value_result.scalar() or 0

        responses.append(CategoryResponse(
            id=cat.id,
            name=cat.name,
            icon=cat.icon,
            color=cat.color,
            sort_order=cat.sort_order,
            is_system=cat.is_system,
            asset_count=asset_count,
            total_value=total_value,
            created_at=cat.created_at,
        ))

    return responses


async def update_category(
    db: AsyncSession, category_id: str, family_id: str, user_id: str, data: UpdateCategoryRequest
) -> CategoryResponse:
    """Update an asset category."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(AssetCategory).where(
        AssetCategory.id == category_id,
        AssetCategory.family_id == family_id,
    )
    result = await db.execute(stmt)
    category = result.scalar_one_or_none()

    if not category:
        raise NotFoundError("分类", category_id)

    if category.is_system:
        raise PermissionDeniedError("系统预设分类不可修改")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(category, field, value)

    await db.flush()

    # Get updated stats
    count_stmt = select(func.count()).select_from(Asset).where(
        Asset.category_id == category.id,
        Asset.status == "active",
    )
    count_result = await db.execute(count_stmt)
    asset_count = count_result.scalar() or 0

    return CategoryResponse(
        id=category.id,
        name=category.name,
        icon=category.icon,
        color=category.color,
        sort_order=category.sort_order,
        is_system=category.is_system,
        asset_count=asset_count,
        total_value=0,
        created_at=category.created_at,
    )


async def delete_category(
    db: AsyncSession, category_id: str, family_id: str, user_id: str
) -> None:
    """Delete an asset category."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(AssetCategory).where(
        AssetCategory.id == category_id,
        AssetCategory.family_id == family_id,
    )
    result = await db.execute(stmt)
    category = result.scalar_one_or_none()

    if not category:
        raise NotFoundError("分类", category_id)

    if category.is_system:
        raise PermissionDeniedError("系统预设分类不可删除")

    # Remove category from assets
    update_stmt = (
        select(Asset)
        .where(Asset.category_id == category_id)
    )
    assets_result = await db.execute(update_stmt)
    assets = assets_result.scalars().all()
    for asset in assets:
        asset.category_id = None

    await db.delete(category)
    await db.flush()


async def init_system_categories(db: AsyncSession, family_id: str) -> None:
    """Initialize system preset categories for a family."""
    # Check if already initialized
    stmt = select(AssetCategory).where(
        AssetCategory.family_id == family_id,
        AssetCategory.is_system.is_(True),
    )
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        return

    system_categories = [
        {"name": "投资", "icon": "trending_up", "color": "#4CAF50", "sort_order": 1},
        {"name": "房产", "icon": "home", "color": "#2196F3", "sort_order": 2},
        {"name": "车辆", "icon": "directions_car", "color": "#FF9800", "sort_order": 3},
        {"name": "保险", "icon": "security", "color": "#9C27B0", "sort_order": 4},
        {"name": "收藏", "icon": "diamond", "color": "#E91E63", "sort_order": 5},
        {"name": "数码", "icon": "devices", "color": "#00BCD4", "sort_order": 6},
        {"name": "家居", "icon": "weekend", "color": "#795548", "sort_order": 7},
        {"name": "其他", "icon": "category", "color": "#607D8B", "sort_order": 8},
    ]

    for cat_data in system_categories:
        category = AssetCategory(
            id=str(uuid.uuid4()),
            family_id=family_id,
            name=cat_data["name"],
            icon=cat_data["icon"],
            color=cat_data["color"],
            sort_order=cat_data["sort_order"],
            is_system=True,
            created_by=None,
        )
        db.add(category)

    await db.flush()
