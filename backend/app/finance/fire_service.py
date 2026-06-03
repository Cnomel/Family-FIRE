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
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.assets.models import Asset, AssetFinancial
from app.common.logging import get_logger
from app.common.utils import utcnow
from app.families.models import FamilyMember
from app.finance.models import Liability, MonthlyBudgetRecord

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
    """Compute net worth breakdown (all assets)."""
    # Total asset value (all assets)
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


async def compute_financial_net_worth(db: AsyncSession, family_id: str) -> dict[str, Any]:
    """Compute net worth based on financial assets only (for FIRE calculations)."""
    # Total financial asset value (stocks, funds, deposits, etc.)
    asset_stmt = (
        select(func.coalesce(func.sum(AssetFinancial.current_value), 0))
        .join(Asset, Asset.id == AssetFinancial.asset_id)
        .where(
            Asset.family_id == family_id,
            Asset.status == "active",
            Asset.nature == "financial",
        )
    )
    asset_result = await db.execute(asset_stmt)
    total_assets = asset_result.scalar()

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
        "total_liabilities": total_liabilities,
        "net_worth": net_worth,
    }


async def compute_asset_allocation(db: AsyncSession, family_id: str) -> dict[str, float]:
    """Compute financial asset allocation by instrument type."""
    from app.assets.models import AssetMetadataFinancial

    stmt = (
        select(
            AssetMetadataFinancial.instrument_type,
            func.sum(AssetFinancial.current_value).label("value"),
        )
        .join(Asset, Asset.id == AssetFinancial.asset_id)
        .outerjoin(AssetMetadataFinancial, AssetMetadataFinancial.asset_id == Asset.id)
        .where(
            Asset.family_id == family_id,
            Asset.status == "active",
            Asset.nature == "financial",
        )
        .group_by(AssetMetadataFinancial.instrument_type)
    )
    result = await db.execute(stmt)
    rows = result.all()

    total = sum(row.value for row in rows) or 1
    allocation = {}
    for row in rows:
        key = row.instrument_type or "other"
        allocation[key] = round(row.value / total, 4)
    return allocation


async def compute_monthly_summary(
    db: AsyncSession, family_id: str, months: int = 12
) -> dict[str, Any]:
    """Compute monthly income/expense summary using budget templates."""
    from datetime import timedelta

    from app.finance.models import ExpenseTemplate, IncomeTemplate

    # Get current year-month and calculate start month
    now = utcnow()
    current_year_month = f"{now.year}-{now.month:02d}"

    # Calculate start month
    start_date = now - timedelta(days=months * 30)
    start_year_month = f"{start_date.year}-{start_date.month:02d}"

    # Get all templates for expected values
    expense_templates_stmt = select(ExpenseTemplate).where(
        ExpenseTemplate.family_id == family_id,
        ExpenseTemplate.is_active.is_(True),
    )
    expense_templates_result = await db.execute(expense_templates_stmt)
    expense_templates = expense_templates_result.scalars().all()

    income_templates_stmt = select(IncomeTemplate).where(
        IncomeTemplate.family_id == family_id,
        IncomeTemplate.is_active.is_(True),
    )
    income_templates_result = await db.execute(income_templates_stmt)
    _ = income_templates_result.scalars().all()

    # Calculate expected monthly expense from templates (using average)
    expected_monthly_expense = sum(
        (t.expected_min + t.expected_max) / 2 for t in expense_templates
    )

    # Get actual records for the period
    records_stmt = select(MonthlyBudgetRecord).where(
        MonthlyBudgetRecord.family_id == family_id,
        MonthlyBudgetRecord.year_month >= start_year_month,
        MonthlyBudgetRecord.year_month <= current_year_month,
    )
    records_result = await db.execute(records_stmt)
    records = records_result.scalars().all()

    # Calculate actual totals
    total_income = sum(r.actual_amount for r in records if r.template_type == "income")
    total_expense = sum(r.actual_amount for r in records if r.template_type == "expense")

    # Calculate months with data
    months_with_data = len({r.year_month for r in records}) or 1

    monthly_income = total_income / months_with_data
    monthly_expense = total_expense / months_with_data
    annual_expense = monthly_expense * 12

    # If no actual data, use expected values
    if total_expense == 0 and expected_monthly_expense > 0:
        monthly_expense = expected_monthly_expense
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
        "expected_monthly_expense": round(expected_monthly_expense, 2),
    }


async def compute_fire_metrics(
    db: AsyncSession, family_id: str,
    withdrawal_rate: float = DEFAULT_WITHDRAWAL_RATE,
    expected_return: float = DEFAULT_EXPECTED_RETURN,
) -> dict[str, Any]:
    """Compute all FIRE metrics based on financial assets only."""
    # 总净资产（所有资产，用于首页显示）
    total_nw = await compute_net_worth(db, family_id)
    # 金融净资产（仅金融资产，用于 FIRE 计算）
    financial_nw = await compute_financial_net_worth(db, family_id)
    summary = await compute_monthly_summary(db, family_id)

    annual_expense = summary["annual_expense"]
    net_worth = financial_nw["net_worth"]

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
        "net_worth": total_nw,
        "financial_net_worth": financial_nw,
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
    # 处理空值
    net_worth = net_worth or 0
    annual_savings = annual_savings or 0
    fire_number = fire_number or 0

    if fire_number <= 0 or net_worth >= fire_number:
        return {
            "success_rate": 1.0 if net_worth >= fire_number and fire_number > 0 else 0.0,
            "median_years": 0,
            "p10_years": 0,
            "p90_years": 0,
            "simulations": simulations,
            "sample_paths": [],
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
    """Compute passive income from investments.

    收入来源:
    1. 有 expected_yield 的稳定资产（存款/国债/货币基金）: 使用该收益率计算
    2. 有 annual_income 的资产: 直接使用该金额
    3. 其他金融资产: 根据总收益和持仓时间计算年化收益
    """
    from app.assets.models import AssetMetadataFinancial

    # Get financial assets with metadata
    stmt = (
        select(Asset, AssetFinancial, AssetMetadataFinancial)
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id)
        .outerjoin(AssetMetadataFinancial, AssetMetadataFinancial.asset_id == Asset.id)
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
    now = utcnow()

    for asset, financial, metadata in rows:
        value = financial.current_value if financial else 0
        cost = financial.purchase_price if financial else 0
        purchase_date = financial.purchase_date if financial else None

        if value <= 0:
            continue

        # 确定收益金额和来源
        annual_income = 0
        income_source = None
        yield_rate = None
        holding_days = None
        total_gain = None

        # 判断是否为稳定资产（存款/国债/货币基金）
        is_stable = metadata and metadata.instrument_type in ('cd', 'bond', 'money_market')

        if is_stable and metadata.expected_yield is not None and metadata.expected_yield > 0:
            # 稳定资产使用用户设置的收益率
            yield_rate = metadata.expected_yield
            annual_income = value * (yield_rate / 100)
            income_source = 'stable_yield'
        elif metadata and metadata.annual_income is not None and metadata.annual_income > 0:
            # 使用用户直接输入的年收益金额
            annual_income = metadata.annual_income
            income_source = 'manual'
            yield_rate = round(annual_income / value * 100, 2) if value > 0 else 0
        elif purchase_date and cost > 0:
            # 其他资产：根据总收益和持仓时间计算年化收益
            total_gain = value - cost

            # 计算持仓天数
            if purchase_date.tzinfo:
                purchase_date = purchase_date.replace(tzinfo=None)
            holding_days = (now - purchase_date).days

            if holding_days > 30 and total_gain > 0:
                # 年化收益 = 总收益 / 持仓年数
                holding_years = holding_days / 365
                annual_income = total_gain / holding_years
                yield_rate = round(annual_income / cost * 100, 2) if cost > 0 else 0
                income_source = 'calculated'
            else:
                # 持仓不足30天或亏损，不计算被动收入
                annual_income = 0
                income_source = 'insufficient'
                yield_rate = 0
        else:
            # 无法计算
            annual_income = 0
            income_source = 'unknown'
            yield_rate = 0

        total_annual += annual_income

        source_data = {
            "asset_id": asset.id,
            "asset_name": asset.name,
            "instrument_type": metadata.instrument_type if metadata else None,
            "value": value,
            "cost": cost,
            "yield_rate": yield_rate,
            "income_source": income_source,
            "estimated_annual_income": round(annual_income, 2),
        }

        # 对于非稳定资产，添加额外信息
        if income_source == 'calculated' and total_gain is not None and holding_days is not None:
            source_data["total_gain"] = round(total_gain, 2)
            source_data["holding_days"] = holding_days
            source_data["holding_years"] = round(holding_days / 365, 2)

        sources.append(source_data)

    # 按收入从高到低排序
    sources.sort(key=lambda x: x['estimated_annual_income'], reverse=True)

    return {
        "total_annual": round(total_annual, 2),
        "total_monthly": round(total_annual / 12, 2),
        "sources": sources,
    }
