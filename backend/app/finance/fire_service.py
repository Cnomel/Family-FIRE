"""FIRE (Financial Independence, Retire Early) calculation engine.

Core metrics:
- Net worth (assets - liabilities)
- Liquid net worth
- Savings rate
- FIRE number (annual expenses / withdrawal rate)
- Financial independence ratio
- Years to FIRE
- Asset allocation analysis
- Monte Carlo simulation
"""

import random
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.assets.models import Asset, AssetFinancial
from app.common.logging import get_logger
from app.families.models import FamilyMember
from app.finance.models import IncomeExpenseRecord, Liability

logger = get_logger("fire_engine")

DEFAULT_WITHDRAWAL_RATE = 0.04  # 4% rule
DEFAULT_EXPECTED_RETURN = 0.07  # 7% annual return
DEFAULT_INFLATION = 0.03  # 3% inflation
MONTE_CARLO_SIMULATIONS = 1000


async def _verify_family_member(db: AsyncSession, family_id: str, user_id: str) -> None:
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise Exception("权限不足")


async def compute_net_worth(db: AsyncSession, family_id: str) -> dict[str, Any]:
    """Compute net worth breakdown."""
    # Total asset value
    asset_stmt = (
        select(func.coalesce(func.sum(AssetFinancial.current_value), 0))
        .join(Asset, Asset.id == AssetFinancial.asset_id)
        .where(Asset.family_id == family_id, Asset.status == "active")
    )
    asset_result = await db.execute(asset_stmt)
    total_assets = asset_result.scalar()

    # Liquid assets (instant + high liquidity)
    liquid_stmt = (
        select(func.coalesce(func.sum(AssetFinancial.current_value), 0))
        .join(Asset, Asset.id == AssetFinancial.asset_id)
        .where(
            Asset.family_id == family_id,
            Asset.status == "active",
            Asset.liquidity.in_(["instant", "high"]),
        )
    )
    liquid_result = await db.execute(liquid_stmt)
    liquid_assets = liquid_result.scalar()

    # Total liability
    liab_stmt = (
        select(func.coalesce(func.sum(Liability.current_balance), 0))
        .where(Liability.family_id == family_id, Liability.status == "active")
    )
    liab_result = await db.execute(liab_stmt)
    total_liabilities = liab_result.scalar()

    net_worth = total_assets - total_liabilities

    return {
        "total_assets": total_assets,
        "liquid_assets": liquid_assets,
        "semi_liquid_assets": 0,  # medium liquidity
        "illiquid_assets": total_assets - liquid_assets,
        "total_liabilities": total_liabilities,
        "net_worth": net_worth,
        "liquid_net_worth": liquid_assets - total_liabilities,
    }


async def compute_asset_allocation(db: AsyncSession, family_id: str) -> dict[str, float]:
    """Compute asset allocation by nature."""
    stmt = (
        select(Asset.nature, func.sum(AssetFinancial.current_value).label("value"))
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id)
        .where(Asset.family_id == family_id, Asset.status == "active")
        .group_by(Asset.nature)
    )
    result = await db.execute(stmt)
    rows = result.all()

    total = sum(row.value for row in rows) or 1
    return {row.nature: round(row.value / total, 4) for row in rows}


async def compute_monthly_summary(
    db: AsyncSession, family_id: str, months: int = 12
) -> dict[str, Any]:
    """Compute monthly income/expense summary."""
    from datetime import timedelta
    cutoff = datetime.utcnow() - timedelta(days=months * 30)

    # Income
    income_stmt = (
        select(func.coalesce(func.sum(IncomeExpenseRecord.amount), 0))
        .where(
            IncomeExpenseRecord.family_id == family_id,
            IncomeExpenseRecord.type == "income",
            IncomeExpenseRecord.date >= cutoff,
        )
    )
    income_result = await db.execute(income_stmt)
    total_income = income_result.scalar()

    # Expense
    expense_stmt = (
        select(func.coalesce(func.sum(IncomeExpenseRecord.amount), 0))
        .where(
            IncomeExpenseRecord.family_id == family_id,
            IncomeExpenseRecord.type == "expense",
            IncomeExpenseRecord.date >= cutoff,
        )
    )
    expense_result = await db.execute(expense_stmt)
    total_expense = expense_result.scalar()

    monthly_income = total_income / max(months, 1)
    monthly_expense = total_expense / max(months, 1)
    annual_expense = monthly_expense * 12

    savings_rate = (monthly_income - monthly_expense) / monthly_income if monthly_income > 0 else 0

    return {
        "total_income": total_income,
        "total_expense": total_expense,
        "monthly_income": round(monthly_income, 2),
        "monthly_expense": round(monthly_expense, 2),
        "annual_expense": round(annual_expense, 2),
        "savings_rate": round(savings_rate, 4),
        "months": months,
    }


async def compute_fire_metrics(
    db: AsyncSession, family_id: str,
    withdrawal_rate: float = DEFAULT_WITHDRAWAL_RATE,
    expected_return: float = DEFAULT_EXPECTED_RETURN,
) -> dict[str, Any]:
    """Compute all FIRE metrics."""
    nw = await compute_net_worth(db, family_id)
    summary = await compute_monthly_summary(db, family_id)

    annual_expense = summary["annual_expense"]
    net_worth = nw["net_worth"]

    # FIRE number
    fire_number = annual_expense / withdrawal_rate if withdrawal_rate > 0 else 0

    # FI ratio
    fi_ratio = net_worth / fire_number if fire_number > 0 else 0

    # Years to FIRE
    savings_rate = summary["savings_rate"]
    if savings_rate > 0 and expected_return > 0:
        monthly_savings = summary["monthly_income"] * savings_rate
        annual_savings = monthly_savings * 12

        if annual_savings > 0:
            # Simple compound growth calculation
            years = 0
            projected = net_worth
            while projected < fire_number and years < 100:
                projected = projected * (1 + expected_return) + annual_savings
                years += 1
            years_to_fire = years
        else:
            years_to_fire = 999
    else:
        years_to_fire = 999

    # Safe withdrawal amount
    safe_withdrawal = net_worth * withdrawal_rate

    return {
        "net_worth": nw,
        "fire_number": round(fire_number, 2),
        "fi_ratio": round(fi_ratio, 4),
        "years_to_fire": min(years_to_fire, 999),
        "savings_rate": savings_rate,
        "safe_withdrawal_annual": round(safe_withdrawal, 2),
        "safe_withdrawal_monthly": round(safe_withdrawal / 12, 2),
        "annual_expense": annual_expense,
        "withdrawal_rate": withdrawal_rate,
        "expected_return": expected_return,
    }


def run_monte_carlo(
    net_worth: float,
    annual_savings: float,
    fire_number: float,
    expected_return: float = 0.07,
    volatility: float = 0.15,
    simulations: int = MONTE_CARLO_SIMULATIONS,
    max_years: int = 50,
) -> dict[str, Any]:
    """Run Monte Carlo simulation for FIRE projection.

    Uses normal distribution for annual returns.
    """
    if fire_number <= 0 or net_worth >= fire_number:
        return {
            "success_rate": 1.0,
            "median_years": 0,
            "p10_years": 0,
            "p90_years": 0,
            "paths": [],
        }

    years_to_fire = []
    sample_paths = []

    for sim in range(simulations):
        balance = net_worth
        path = [balance]
        years = 0

        for _year in range(max_years):
            # Random return from normal distribution
            annual_return = random.gauss(expected_return, volatility)
            balance = balance * (1 + annual_return) + annual_savings
            balance = max(balance, 0)
            path.append(balance)
            years += 1

            if balance >= fire_number:
                break

        years_to_fire.append(years)
        if sim < 20:  # Keep only 20 sample paths
            sample_paths.append(path)

    years_to_fire.sort()
    success_count = sum(1 for y in years_to_fire if y < max_years)

    return {
        "success_rate": round(success_count / simulations, 4),
        "median_years": years_to_fire[len(years_to_fire) // 2],
        "p10_years": years_to_fire[int(len(years_to_fire) * 0.1)],
        "p90_years": years_to_fire[int(len(years_to_fire) * 0.9)],
        "simulations": simulations,
        "sample_paths": sample_paths,
    }


async def compute_passive_income(db: AsyncSession, family_id: str) -> dict[str, Any]:
    """Compute passive income from investments."""
    # Get financial assets that generate income
    stmt = (
        select(Asset, AssetFinancial)
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id)
        .where(
            Asset.family_id == family_id,
            Asset.status == "active",
            Asset.nature == "financial",
        )
    )
    result = await db.execute(stmt)
    rows = result.all()

    sources = []
    total_annual = 0

    for asset, financial in rows:
        # Estimate dividend/interest income
        # This is simplified - real implementation would use actual dividend data
        value = financial.current_value if financial else 0
        if value > 0:
            estimated_yield = 0.02  # Default 2% estimate
            annual_income = value * estimated_yield
            total_annual += annual_income
            sources.append({
                "asset_id": asset.id,
                "asset_name": asset.name,
                "value": value,
                "estimated_annual_income": round(annual_income, 2),
            })

    return {
        "total_annual": round(total_annual, 2),
        "total_monthly": round(total_annual / 12, 2),
        "sources": sources,
    }
