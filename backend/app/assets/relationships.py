"""Asset relationship management service."""

import uuid
from typing import Any

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.assets.lifecycle.engine import RELATIONSHIP_TYPES
from app.assets.models import Asset, AssetRelationship
from app.common.exceptions import NotFoundError, PermissionDeniedError
from app.common.logging import get_logger
from app.families.models import FamilyMember

logger = get_logger("relationship_service")


async def _verify_family_member(db: AsyncSession, family_id: str, user_id: str) -> None:
    """Verify user is a member of the family."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭的资产")


async def _verify_asset_in_family(db: AsyncSession, asset_id: str, family_id: str) -> Asset:
    """Verify asset belongs to the family."""
    stmt = select(Asset).where(Asset.id == asset_id, Asset.family_id == family_id)
    result = await db.execute(stmt)
    asset = result.scalar_one_or_none()
    if not asset:
        raise NotFoundError("资产", asset_id)
    return asset


async def create_relationship(
    db: AsyncSession,
    family_id: str,
    user_id: str,
    source_asset_id: str,
    target_asset_id: str,
    rel_type: str,
    is_optional: bool = True,
    lifecycle_linked: bool = False,
) -> dict[str, Any]:
    """Create a relationship between two assets.

    Raises:
        NotFoundError: If either asset not found.
        PermissionDeniedError: If user is not a family member.
        ValueError: If relationship type is invalid.
    """
    await _verify_family_member(db, family_id, user_id)

    if rel_type not in RELATIONSHIP_TYPES:
        raise ValueError(f"无效的关系类型: {rel_type}。有效类型: {', '.join(RELATIONSHIP_TYPES.keys())}")

    if source_asset_id == target_asset_id:
        raise ValueError("不能创建资产与自身的关系")

    # Verify both assets exist and belong to family
    await _verify_asset_in_family(db, source_asset_id, family_id)
    await _verify_asset_in_family(db, target_asset_id, family_id)

    # Check for duplicate relationship
    stmt = select(AssetRelationship).where(
        AssetRelationship.source_asset_id == source_asset_id,
        AssetRelationship.target_asset_id == target_asset_id,
        AssetRelationship.type == rel_type,
    )
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise ValueError("该关系已存在")

    relationship = AssetRelationship(
        id=str(uuid.uuid4()),
        type=rel_type,
        source_asset_id=source_asset_id,
        target_asset_id=target_asset_id,
        is_optional=is_optional,
        lifecycle_linked=lifecycle_linked,
    )
    db.add(relationship)
    await db.flush()

    logger.info(
        "relationship_created",
        rel_id=relationship.id,
        type=rel_type,
        source=source_asset_id,
        target=target_asset_id,
    )

    return {
        "id": relationship.id,
        "type": rel_type,
        "source_asset_id": source_asset_id,
        "target_asset_id": target_asset_id,
        "is_optional": is_optional,
        "lifecycle_linked": lifecycle_linked,
        "type_info": RELATIONSHIP_TYPES[rel_type],
    }


async def get_asset_relationships(
    db: AsyncSession,
    family_id: str,
    user_id: str,
    asset_id: str,
) -> list[dict[str, Any]]:
    """Get all relationships for an asset (both as source and target)."""
    await _verify_family_member(db, family_id, user_id)
    await _verify_asset_in_family(db, asset_id, family_id)

    # Get relationships where asset is source or target
    stmt = select(AssetRelationship).where(
        or_(
            AssetRelationship.source_asset_id == asset_id,
            AssetRelationship.target_asset_id == asset_id,
        )
    )
    result = await db.execute(stmt)
    relationships = result.scalars().all()

    # Get related asset names
    responses = []
    for rel in relationships:
        # Get the "other" asset
        other_id = rel.target_asset_id if rel.source_asset_id == asset_id else rel.source_asset_id
        other_stmt = select(Asset).where(Asset.id == other_id)
        other_result = await db.execute(other_stmt)
        other_asset = other_result.scalar_one_or_none()

        direction = "outgoing" if rel.source_asset_id == asset_id else "incoming"

        responses.append({
            "id": rel.id,
            "type": rel.type,
            "direction": direction,
            "related_asset_id": other_id,
            "related_asset_name": other_asset.name if other_asset else "未知",
            "is_optional": rel.is_optional,
            "lifecycle_linked": rel.lifecycle_linked,
            "type_info": RELATIONSHIP_TYPES.get(rel.type, {}),
        })

    return responses


async def delete_relationship(
    db: AsyncSession,
    family_id: str,
    user_id: str,
    relationship_id: str,
) -> None:
    """Delete a relationship.

    Raises:
        NotFoundError: If relationship not found.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = select(AssetRelationship).where(AssetRelationship.id == relationship_id)
    result = await db.execute(stmt)
    relationship = result.scalar_one_or_none()

    if not relationship:
        raise NotFoundError("资产关系", relationship_id)

    await db.delete(relationship)
    await db.flush()
    logger.info("relationship_deleted", rel_id=relationship_id)


async def get_relationship_graph(
    db: AsyncSession,
    family_id: str,
    user_id: str,
) -> dict[str, Any]:
    """Get the complete relationship graph for a family's assets.

    Returns nodes (assets) and edges (relationships) for visualization.
    """
    await _verify_family_member(db, family_id, user_id)

    # Get all active assets in the family
    assets_stmt = select(Asset).where(
        Asset.family_id == family_id,
        Asset.status == "active",
    )
    assets_result = await db.execute(assets_stmt)
    assets = assets_result.scalars().all()

    # Get all relationships between these assets
    asset_ids = [a.id for a in assets]
    rels_stmt = select(AssetRelationship).where(
        or_(
            AssetRelationship.source_asset_id.in_(asset_ids),
            AssetRelationship.target_asset_id.in_(asset_ids),
        )
    )
    rels_result = await db.execute(rels_stmt)
    relationships = rels_result.scalars().all()

    # Build graph
    nodes = [
        {
            "id": a.id,
            "name": a.name,
            "nature": a.nature,
            "utility": a.utility,
            "status": a.status,
        }
        for a in assets
    ]

    edges = [
        {
            "id": r.id,
            "source": r.source_asset_id,
            "target": r.target_asset_id,
            "type": r.type,
            "label": RELATIONSHIP_TYPES.get(r.type, {}).get("label", r.type),
        }
        for r in relationships
    ]

    return {
        "nodes": nodes,
        "edges": edges,
        "node_count": len(nodes),
        "edge_count": len(edges),
    }


async def analyze_insurance_gaps(
    db: AsyncSession,
    family_id: str,
    user_id: str,
) -> list[dict[str, Any]]:
    """Find high-value tangible assets without insurance coverage."""
    await _verify_family_member(db, family_id, user_id)

    # Get assets with value > 5000 that are tangible
    from app.assets.models import AssetFinancial

    stmt = (
        select(Asset, AssetFinancial)
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id)
        .where(
            Asset.family_id == family_id,
            Asset.status == "active",
            Asset.nature == "tangible",
            AssetFinancial.current_value > 5000,
        )
    )
    result = await db.execute(stmt)
    high_value_assets = result.all()

    # Get assets that have insurance coverage (via 'protects' relationship)
    covered_stmt = select(AssetRelationship.target_asset_id).where(
        AssetRelationship.type == "protects",
        AssetRelationship.target_asset_id.in_([a.id for a, _ in high_value_assets]),
    )
    covered_result = await db.execute(covered_stmt)
    covered_ids = set(covered_result.scalars().all())

    # Find gaps
    gaps = []
    for asset, financial in high_value_assets:
        if asset.id not in covered_ids:
            gaps.append({
                "asset_id": asset.id,
                "asset_name": asset.name,
                "current_value": financial.current_value if financial else 0,
                "nature": asset.nature,
                "utility": asset.utility,
            })

    return gaps


def get_relationship_types() -> dict[str, Any]:
    """Get all available relationship types with descriptions."""
    return RELATIONSHIP_TYPES
