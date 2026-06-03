"""Lifecycle calculation engine with 6 trajectory calculators.

Each calculator computes the current value of an asset based on its lifecycle trajectory.
"""

from datetime import datetime
from typing import Any

from app.common.logging import get_logger
from app.common.utils import utcnow

logger = get_logger("lifecycle")


def _ensure_naive(dt: datetime) -> datetime:
    """Ensure datetime is naive (strip timezone if present).

    This is needed because PostgreSQL TIMESTAMP WITHOUT TIME ZONE
    requires naive datetimes, and asyncpg rejects timezone-aware ones.
    """
    if dt.tzinfo is not None:
        return dt.replace(tzinfo=None)
    return dt


def compute_current_value(
    trajectory: str,
    purchase_price: float,
    purchase_date: datetime | None,
    config: dict[str, Any] | None,
    current_market_price: float | None = None,
    current_quantity: float | None = None,
    initial_quantity: float | None = None,
) -> float:
    """Compute current value based on lifecycle trajectory.

    Args:
        trajectory: One of appreciating/depreciating/consumable/expiring/volatile/stable
        purchase_price: Original purchase price
        purchase_date: When the asset was purchased
        config: Trajectory-specific configuration
        current_market_price: For volatile assets
        current_quantity: For consumable assets
        initial_quantity: For consumable assets

    Returns:
        Current estimated value
    """
    if not config:
        config = {}

    today = utcnow()

    # Ensure purchase_date is naive
    if purchase_date:
        purchase_date = _ensure_naive(purchase_date)

    match trajectory:
        case "depreciating":
            return _compute_depreciating(purchase_price, purchase_date, config, today)
        case "consumable":
            return _compute_consumable(purchase_price, current_quantity, initial_quantity)
        case "expiring":
            return _compute_expiring(config, today)
        case "volatile":
            return _compute_volatile(current_market_price, current_quantity, purchase_price)
        case "appreciating":
            return _compute_appreciating(purchase_price, purchase_date, config, today)
        case "stable":
            return purchase_price
        case _:
            logger.warning("unknown_trajectory", trajectory=trajectory)
            return purchase_price


def _compute_depreciating(
    purchase_price: float,
    purchase_date: datetime | None,
    config: dict[str, Any],
    today: datetime,
) -> float:
    """Compute depreciating asset value.

    Config:
        method: straight_line | declining_balance
        rate: Annual depreciation rate (e.g., 0.15 = 15%/year)
        salvage_value: Minimum floor value
        useful_life_years: Total useful life in years
    """
    if not purchase_date:
        return purchase_price

    method = config.get("method", "straight_line")
    rate = config.get("rate", 0.15)
    salvage_value = config.get("salvage_value", 0)
    useful_life_years = config.get("useful_life_years", 5)

    age_years = (today - purchase_date).days / 365.25

    if method == "straight_line":
        annual_depreciation = (purchase_price - salvage_value) / useful_life_years
        total_depreciation = annual_depreciation * age_years
        value = purchase_price - total_depreciation
    elif method == "declining_balance":
        value = purchase_price * ((1 - rate) ** age_years)
    else:
        value = purchase_price

    return max(value, salvage_value)


def _compute_consumable(
    purchase_price: float,
    current_quantity: float | None,
    initial_quantity: float | None,
) -> float:
    """Compute consumable asset value.

    Value = purchase_price * (current_qty / initial_qty)
    """
    if current_quantity is None or initial_quantity is None or initial_quantity == 0:
        return purchase_price

    ratio = current_quantity / initial_quantity
    return purchase_price * max(0, min(1, ratio))


def _compute_expiring(
    config: dict[str, Any],
    today: datetime,
) -> float:
    """Compute expiring asset value (insurance, subscriptions, warranties).

    Config:
        renewal_cost: Cost per renewal period
        end_date: Expiration date (ISO string)
        total_days: Total coverage period in days
    """
    renewal_cost = config.get("renewal_cost", 0)
    end_date_str = config.get("end_date")

    if not end_date_str:
        return renewal_cost

    try:
        end_date = datetime.fromisoformat(end_date_str.replace("Z", "+00:00"))
        end_date = _ensure_naive(end_date)
    except (ValueError, AttributeError):
        return renewal_cost

    remaining_days = max(0, (end_date - today).days)
    total_days = config.get("total_days", 365)

    if total_days <= 0:
        return 0

    return renewal_cost * (remaining_days / total_days)


def _compute_volatile(
    current_market_price: float | None,
    current_quantity: float | None,
    purchase_price: float,
) -> float:
    """Compute volatile asset value (stocks, crypto).

    Value = current_market_price * quantity
    Falls back to purchase_price if market price unavailable.
    """
    if current_market_price is not None and current_quantity is not None:
        return current_market_price * current_quantity

    return purchase_price


def _compute_appreciating(
    purchase_price: float,
    purchase_date: datetime | None,
    config: dict[str, Any],
    today: datetime,
) -> float:
    """Compute appreciating asset value.

    Config:
        method: fixed_rate | manual
        annual_rate: Annual appreciation rate (e.g., 0.03 = 3%/year)
        last_appraisal_value: Manual appraisal value
        last_appraisal_date: Manual appraisal date (ISO string)
    """
    method = config.get("method", "fixed_rate")

    if method == "manual":
        last_value = config.get("last_appraisal_value")
        if last_value is not None:
            return last_value
        return purchase_price

    # fixed_rate
    annual_rate = config.get("annual_rate", 0.03)

    if not purchase_date:
        return purchase_price * (1 + annual_rate)

    age_years = (today - purchase_date).days / 365.25
    return purchase_price * ((1 + annual_rate) ** age_years)


def compute_value_history(
    trajectory: str,
    purchase_price: float,
    purchase_date: datetime | None,
    config: dict[str, Any] | None,
    months: int = 12,
) -> list[dict[str, Any]]:
    """Generate value history for the past N months.

    Returns list of {date, value} dicts.
    """
    if not purchase_date or not config:
        return []

    from dateutil.relativedelta import relativedelta

    # Ensure purchase_date is naive
    purchase_date = _ensure_naive(purchase_date)

    history = []
    today = utcnow()

    for i in range(months, -1, -1):
        date = today - relativedelta(months=i)

        # Skip dates before purchase
        if date < purchase_date:
            continue

        value = compute_current_value(
            trajectory=trajectory,
            purchase_price=purchase_price,
            purchase_date=purchase_date,
            config=config,
        )

        history.append({
            "date": date.strftime("%Y-%m-%d"),
            "value": round(value, 2),
        })

    return history


# ============================================================
# Relationship type definitions
# ============================================================

RELATIONSHIP_TYPES = {
    "component_of": {"label": "组成部分", "label_en": "Component of", "direction": "child→parent"},
    "contains": {"label": "包含", "label_en": "Contains", "direction": "parent→child"},
    "requires": {"label": "需要", "label_en": "Requires", "direction": "dependent→dependency"},
    "manages": {"label": "管理", "label_en": "Manages", "direction": "manager→managed"},
    "provides": {"label": "提供", "label_en": "Provides", "direction": "provider→service"},
    "protects": {"label": "保护", "label_en": "Protects", "direction": "protector→protected"},
    "funds": {"label": "资助", "label_en": "Funds", "direction": "funder→funded"},
    "secures": {"label": "担保", "label_en": "Secures", "direction": "collateral→secured"},
    "accesses": {"label": "访问", "label_en": "Accesses", "direction": "user→resource"},
    "substitutes": {"label": "替代", "label_en": "Substitutes", "direction": "old↔new"},
}
