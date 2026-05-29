"""Finance service: liability, income/expense, transactions, cost basis."""

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import NotFoundError, PermissionDeniedError
from app.common.logging import get_logger
from app.families.models import FamilyMember
from app.finance.models import (
    ExpenseCategory,
    IncomeCategory,
    IncomeExpenseRecord,
    Liability,
    PriceSnapshot,
    Transaction,
)
from app.finance.schemas import (
    CostBasisInfo,
    CreateIncomeExpenseRequest,
    CreateLiabilityRequest,
    CreateTransactionRequest,
    IncomeExpenseResponse,
    IncomeExpenseSummary,
    LiabilityResponse,
    TransactionResponse,
    UpdateIncomeExpenseRequest,
    UpdateLiabilityRequest,
)

logger = get_logger("finance_service")


async def _verify_family_member(db: AsyncSession, family_id: str, user_id: str) -> None:
    """Verify user is a member of the family."""
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭的财务数据")


# ============================================================
# Liability Management
# ============================================================

def calculate_monthly_payment(
    principal: float,
    annual_rate: float,
    months: int,
    method: str = "equal_installment",
) -> float:
    """Calculate monthly payment for a loan.

    Args:
        principal: Loan principal
        annual_rate: Annual interest rate (percentage, e.g., 4.5 for 4.5%)
        months: Total number of monthly payments
        method: 'equal_installment' (等额本息) or 'equal_principal' (等额本金)

    Returns:
        Monthly payment amount
    """
    if annual_rate <= 0 or months <= 0:
        return principal / max(months, 1)

    monthly_rate = annual_rate / 100 / 12

    if method == "equal_installment":
        # 等额本息: M = P * [r(1+r)^n] / [(1+r)^n - 1]
        factor = (1 + monthly_rate) ** months
        return principal * monthly_rate * factor / (factor - 1)
    else:
        # 等额本金: 每月递减
        monthly_principal = principal / months
        first_month_interest = principal * monthly_rate
        return monthly_principal + first_month_interest


async def create_liability(
    db: AsyncSession, family_id: str, user_id: str, data: CreateLiabilityRequest
) -> LiabilityResponse:
    """Create a new liability."""
    await _verify_family_member(db, family_id, user_id)

    liability = Liability(
        id=str(uuid.uuid4()),
        family_id=family_id,
        created_by=user_id,
        asset_id=data.asset_id,
        type=data.type,
        name=data.name,
        lender=data.lender,
        original_amount=data.original_amount,
        current_balance=data.current_balance,
        interest_rate=data.interest_rate,
        monthly_payment=data.monthly_payment,
        start_date=data.start_date,
        end_date=data.end_date,
        payment_day=data.payment_day,
        notes=data.notes,
        status="active",
    )
    db.add(liability)
    await db.flush()

    logger.info("liability_created", liability_id=liability.id, type=data.type, name=data.name)
    return _liability_to_response(liability)


async def list_liabilities(
    db: AsyncSession, family_id: str, user_id: str
) -> dict[str, Any]:
    """List all liabilities for a family."""
    await _verify_family_member(db, family_id, user_id)

    stmt = (
        select(Liability)
        .where(Liability.family_id == family_id, Liability.status == "active")
        .order_by(Liability.created_at.desc())
    )
    result = await db.execute(stmt)
    liabilities = result.scalars().all()

    responses = [_liability_to_response(liab) for liab in liabilities]
    total_balance = sum(liab.current_balance for liab in liabilities)

    return {
        "liabilities": responses,
        "total": len(responses),
        "total_balance": total_balance,
    }


async def update_liability(
    db: AsyncSession, liability_id: str, family_id: str, user_id: str, data: UpdateLiabilityRequest
) -> LiabilityResponse:
    """Update a liability."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Liability).where(Liability.id == liability_id, Liability.family_id == family_id)
    result = await db.execute(stmt)
    liability = result.scalar_one_or_none()

    if not liability:
        raise NotFoundError("负债", liability_id)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(liability, field, value)

    await db.flush()
    return _liability_to_response(liability)


async def delete_liability(
    db: AsyncSession, liability_id: str, family_id: str, user_id: str
) -> None:
    """Delete (mark as paid off) a liability."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(Liability).where(Liability.id == liability_id, Liability.family_id == family_id)
    result = await db.execute(stmt)
    liability = result.scalar_one_or_none()

    if not liability:
        raise NotFoundError("负债", liability_id)

    liability.status = "paid_off"
    liability.current_balance = 0
    await db.flush()
    logger.info("liability_paid_off", liability_id=liability_id)


def _liability_to_response(liab: Liability) -> LiabilityResponse:
    return LiabilityResponse(
        id=liab.id,
        name=liab.name,
        type=liab.type,
        lender=liab.lender,
        original_amount=liab.original_amount,
        current_balance=liab.current_balance,
        interest_rate=liab.interest_rate,
        monthly_payment=liab.monthly_payment,
        start_date=liab.start_date,
        end_date=liab.end_date,
        payment_day=liab.payment_day,
        status=liab.status,
        asset_id=liab.asset_id,
        notes=liab.notes,
        created_at=liab.created_at,
    )


# ============================================================
# Income & Expense Management
# ============================================================

async def create_income_expense(
    db: AsyncSession, family_id: str, user_id: str, data: CreateIncomeExpenseRequest
) -> IncomeExpenseResponse:
    """Record an income or expense."""
    await _verify_family_member(db, family_id, user_id)

    record = IncomeExpenseRecord(
        id=str(uuid.uuid4()),
        family_id=family_id,
        user_id=user_id,
        type=data.type,
        category_id=data.category_id,
        subcategory_id=data.subcategory_id,
        amount=data.amount,
        currency=data.currency,
        date=data.date,
        description=data.description,
        notes=data.notes,
        is_recurring=data.is_recurring,
        recurring_config=data.recurring_config,
    )
    db.add(record)
    await db.flush()

    logger.info("income_expense_created", type=data.type, amount=data.amount)
    return _ie_to_response(record)


async def list_income_expense(
    db: AsyncSession, family_id: str, user_id: str,
    record_type: str | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    page: int = 1,
    page_size: int = 20,
) -> dict[str, Any]:
    """List income/expense records with filtering."""
    await _verify_family_member(db, family_id, user_id)

    conditions = [IncomeExpenseRecord.family_id == family_id]
    if record_type:
        conditions.append(IncomeExpenseRecord.type == record_type)
    if start_date:
        conditions.append(IncomeExpenseRecord.date >= start_date)
    if end_date:
        conditions.append(IncomeExpenseRecord.date <= end_date)

    # Count
    count_stmt = select(func.count()).select_from(IncomeExpenseRecord).where(and_(*conditions))
    count_result = await db.execute(count_stmt)
    total = count_result.scalar()

    # Get records
    offset = (page - 1) * page_size
    stmt = (
        select(IncomeExpenseRecord)
        .where(and_(*conditions))
        .order_by(IncomeExpenseRecord.date.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(stmt)
    records = result.scalars().all()

    return {
        "records": [_ie_to_response(r) for r in records],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


async def get_income_expense_summary(
    db: AsyncSession, family_id: str, user_id: str,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> IncomeExpenseSummary:
    """Get income/expense summary."""
    await _verify_family_member(db, family_id, user_id)

    conditions = [IncomeExpenseRecord.family_id == family_id]
    if start_date:
        conditions.append(IncomeExpenseRecord.date >= start_date)
    if end_date:
        conditions.append(IncomeExpenseRecord.date <= end_date)

    # Income total
    income_stmt = (
        select(func.coalesce(func.sum(IncomeExpenseRecord.amount), 0))
        .where(and_(IncomeExpenseRecord.type == "income", *conditions))
    )
    income_result = await db.execute(income_stmt)
    total_income = income_result.scalar()

    # Expense total
    expense_stmt = (
        select(func.coalesce(func.sum(IncomeExpenseRecord.amount), 0))
        .where(and_(IncomeExpenseRecord.type == "expense", *conditions))
    )
    expense_result = await db.execute(expense_stmt)
    total_expense = expense_result.scalar()

    # By category
    cat_stmt = (
        select(
            IncomeExpenseRecord.type,
            IncomeExpenseRecord.category_id,
            func.sum(IncomeExpenseRecord.amount).label("total"),
            func.count().label("count"),
        )
        .where(and_(*conditions))
        .group_by(IncomeExpenseRecord.type, IncomeExpenseRecord.category_id)
    )
    cat_result = await db.execute(cat_stmt)
    by_category = [
        {"type": row.type, "category_id": row.category_id, "total": row.total, "count": row.count}
        for row in cat_result.all()
    ]

    net = total_income - total_expense
    savings_rate = net / total_income if total_income > 0 else 0

    return IncomeExpenseSummary(
        total_income=total_income,
        total_expense=total_expense,
        net=net,
        savings_rate=round(savings_rate, 4),
        period_start=start_date,
        period_end=end_date,
        by_category=by_category,
    )


async def update_income_expense(
    db: AsyncSession, record_id: str, family_id: str, user_id: str,
    data: UpdateIncomeExpenseRequest,
) -> IncomeExpenseResponse:
    """Update an income/expense record."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(IncomeExpenseRecord).where(
        IncomeExpenseRecord.id == record_id,
        IncomeExpenseRecord.family_id == family_id,
    )
    result = await db.execute(stmt)
    record = result.scalar_one_or_none()

    if not record:
        raise NotFoundError("收支记录", record_id)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(record, field, value)

    await db.flush()
    return _ie_to_response(record)


async def delete_income_expense(
    db: AsyncSession, record_id: str, family_id: str, user_id: str
) -> None:
    """Delete an income/expense record."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(IncomeExpenseRecord).where(
        IncomeExpenseRecord.id == record_id,
        IncomeExpenseRecord.family_id == family_id,
    )
    result = await db.execute(stmt)
    record = result.scalar_one_or_none()

    if not record:
        raise NotFoundError("收支记录", record_id)

    await db.delete(record)
    await db.flush()


def _ie_to_response(r: IncomeExpenseRecord) -> IncomeExpenseResponse:
    return IncomeExpenseResponse(
        id=r.id,
        type=r.type,
        category_id=r.category_id,
        subcategory_id=r.subcategory_id,
        amount=r.amount,
        currency=r.currency,
        date=r.date,
        description=r.description,
        is_recurring=r.is_recurring,
        created_at=r.created_at,
    )


# ============================================================
# Investment Transactions
# ============================================================

async def create_transaction(
    db: AsyncSession, family_id: str, user_id: str, data: CreateTransactionRequest
) -> TransactionResponse:
    """Record an investment transaction."""
    await _verify_family_member(db, family_id, user_id)

    transaction = Transaction(
        id=str(uuid.uuid4()),
        asset_id=data.asset_id,
        family_id=family_id,
        created_by=user_id,
        type=data.type,
        quantity=data.quantity,
        price=data.price,
        total=data.total,
        fees=data.fees,
        date=data.date,
        notes=data.notes,
    )
    db.add(transaction)
    await db.flush()

    logger.info("transaction_created", type=data.type, asset_id=data.asset_id, total=data.total)
    return _transaction_to_response(transaction)


async def list_transactions(
    db: AsyncSession, family_id: str, user_id: str,
    asset_id: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> dict[str, Any]:
    """List transactions."""
    await _verify_family_member(db, family_id, user_id)

    conditions = [Transaction.family_id == family_id]
    if asset_id:
        conditions.append(Transaction.asset_id == asset_id)

    count_stmt = select(func.count()).select_from(Transaction).where(and_(*conditions))
    count_result = await db.execute(count_stmt)
    total = count_result.scalar()

    offset = (page - 1) * page_size
    stmt = (
        select(Transaction)
        .where(and_(*conditions))
        .order_by(Transaction.date.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(stmt)
    transactions = result.scalars().all()

    return {
        "transactions": [_transaction_to_response(t) for t in transactions],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


async def get_cost_basis(
    db: AsyncSession, family_id: str, user_id: str, asset_id: str,
    method: str = "average_cost",
) -> CostBasisInfo:
    """Calculate cost basis for an asset.

    Supports FIFO, LIFO, and average cost methods.
    """
    await _verify_family_member(db, family_id, user_id)

    stmt = (
        select(Transaction)
        .where(
            Transaction.family_id == family_id,
            Transaction.asset_id == asset_id,
            Transaction.type.in_(["buy", "sell"]),
        )
        .order_by(Transaction.date.asc())
    )
    result = await db.execute(stmt)
    transactions = result.scalars().all()

    # Build lots from buy transactions
    lots: list[dict[str, Any]] = []
    for t in transactions:
        if t.type == "buy" and t.quantity:
            lots.append({
                "date": t.date.isoformat(),
                "quantity": t.quantity,
                "price": t.price or 0,
                "total": t.total,
                "fees": t.fees,
            })
        elif t.type == "sell" and t.quantity:
            # Remove lots based on method
            remaining_to_sell = t.quantity
            while remaining_to_sell > 0 and lots:
                if method == "fifo":
                    lot = lots[0]
                elif method == "lifo":
                    lot = lots[-1]
                else:
                    lot = lots[0]

                if lot["quantity"] <= remaining_to_sell:
                    remaining_to_sell -= lot["quantity"]
                    lots.remove(lot)
                else:
                    lot["quantity"] -= remaining_to_sell
                    remaining_to_sell = 0

    total_shares = sum(lot["quantity"] for lot in lots)
    total_cost = sum(lot["total"] + lot["fees"] for lot in lots)
    avg_cost = total_cost / total_shares if total_shares > 0 else 0

    return CostBasisInfo(
        asset_id=asset_id,
        method=method,
        total_shares=total_shares,
        average_cost=round(avg_cost, 4),
        total_cost=round(total_cost, 2),
        lots=lots,
    )


def _transaction_to_response(t: Transaction) -> TransactionResponse:
    return TransactionResponse(
        id=t.id,
        asset_id=t.asset_id,
        type=t.type,
        quantity=t.quantity,
        price=t.price,
        total=t.total,
        fees=t.fees,
        date=t.date,
        notes=t.notes,
        created_at=t.created_at,
    )


# ============================================================
# Categories
# ============================================================

async def get_expense_categories(db: AsyncSession) -> list[dict[str, Any]]:
    """Get all expense categories with subcategories."""
    stmt = select(ExpenseCategory).order_by(ExpenseCategory.sort_order)
    result = await db.execute(stmt)
    categories = result.scalars().all()

    # Build tree
    cat_map = {}
    roots = []
    for cat in categories:
        cat_dict = {
            "id": cat.id,
            "name": cat.name,
            "name_en": cat.name_en,
            "icon": cat.icon,
            "parent_id": cat.parent_id,
            "children": [],
        }
        cat_map[cat.id] = cat_dict
        if cat.parent_id:
            parent = cat_map.get(cat.parent_id)
            if parent:
                parent["children"].append(cat_dict)
        else:
            roots.append(cat_dict)

    return roots


async def get_income_categories(db: AsyncSession) -> list[dict[str, Any]]:
    """Get all income categories with subcategories."""
    stmt = select(IncomeCategory).order_by(IncomeCategory.sort_order)
    result = await db.execute(stmt)
    categories = result.scalars().all()

    cat_map = {}
    roots = []
    for cat in categories:
        cat_dict = {
            "id": cat.id,
            "name": cat.name,
            "name_en": cat.name_en,
            "icon": cat.icon,
            "parent_id": cat.parent_id,
            "children": [],
        }
        cat_map[cat.id] = cat_dict
        if cat.parent_id:
            parent = cat_map.get(cat.parent_id)
            if parent:
                parent["children"].append(cat_dict)
        else:
            roots.append(cat_dict)

    return roots


# ============================================================
# Price Snapshots
# ============================================================

async def record_price_snapshot(
    db: AsyncSession, asset_id: str, price: float, currency: str, source: str
) -> None:
    """Record a price snapshot."""
    snapshot = PriceSnapshot(
        id=str(uuid.uuid4()),
        asset_id=asset_id,
        price=price,
        currency=currency,
        source=source,
        recorded_at=datetime.now(UTC),
    )
    db.add(snapshot)
    await db.flush()


async def get_price_history(
    db: AsyncSession, asset_id: str, days: int = 30
) -> list[dict[str, Any]]:
    """Get price history for an asset."""
    from datetime import timedelta
    cutoff = datetime.now(UTC) - timedelta(days=days)

    stmt = (
        select(PriceSnapshot)
        .where(PriceSnapshot.asset_id == asset_id, PriceSnapshot.recorded_at >= cutoff)
        .order_by(PriceSnapshot.recorded_at.asc())
    )
    result = await db.execute(stmt)
    snapshots = result.scalars().all()

    return [
        {"price": s.price, "date": s.recorded_at.isoformat(), "source": s.source}
        for s in snapshots
    ]
