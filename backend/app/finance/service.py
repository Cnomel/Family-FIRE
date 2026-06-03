"""Finance service: liability, budget templates, monthly records, transactions, cost basis."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import NotFoundError, PermissionDeniedError, ValidationError
from app.common.logging import get_logger
from app.common.utils import utcnow
from app.families.models import FamilyMember
from app.finance.models import (
    ExpenseCategory,
    ExpenseTemplate,
    IncomeCategory,
    IncomeTemplate,
    Liability,
    MonthlyBudgetRecord,
    PriceSnapshot,
    Transaction,
)
from app.finance.schemas import (
    BatchSaveMonthlyRequest,
    CostBasisInfo,
    CreateExpenseTemplateRequest,
    CreateIncomeTemplateRequest,
    CreateLiabilityRequest,
    CreateTransactionRequest,
    ExpenseTemplateResponse,
    IncomeTemplateResponse,
    LiabilityResponse,
    MonthlyRecordResponse,
    MonthlySummaryResponse,
    TransactionResponse,
    UpdateExpenseTemplateRequest,
    UpdateIncomeTemplateRequest,
    UpdateLiabilityRequest,
    YearlySummaryResponse,
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
# Expense Template Management
# ============================================================

async def create_expense_template(
    db: AsyncSession, family_id: str, user_id: str, data: CreateExpenseTemplateRequest
) -> ExpenseTemplateResponse:
    """Create a new expense template."""
    await _verify_family_member(db, family_id, user_id)

    template = ExpenseTemplate(
        id=str(uuid.uuid4()),
        family_id=family_id,
        name=data.name,
        category_id=data.category_id,
        icon=data.icon,
        expected_min=data.expected_min,
        expected_max=data.expected_max,
        is_fixed=data.is_fixed,
        is_system=False,
        sort_order=data.sort_order,
        is_active=True,
        created_by=user_id,
    )
    db.add(template)
    await db.flush()

    logger.info("expense_template_created", template_id=template.id, name=data.name)
    return _expense_template_to_response(template)


async def list_expense_templates(
    db: AsyncSession, family_id: str, user_id: str, active_only: bool = True
) -> list[ExpenseTemplateResponse]:
    """List all expense templates for a family."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(ExpenseTemplate).where(ExpenseTemplate.family_id == family_id)
    if active_only:
        stmt = stmt.where(ExpenseTemplate.is_active.is_(True))
    stmt = stmt.order_by(ExpenseTemplate.sort_order, ExpenseTemplate.created_at)

    result = await db.execute(stmt)
    templates = result.scalars().all()
    return [_expense_template_to_response(t) for t in templates]


async def update_expense_template(
    db: AsyncSession, template_id: str, family_id: str, user_id: str,
    data: UpdateExpenseTemplateRequest,
) -> ExpenseTemplateResponse:
    """Update an expense template."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(ExpenseTemplate).where(
        ExpenseTemplate.id == template_id,
        ExpenseTemplate.family_id == family_id,
    )
    result = await db.execute(stmt)
    template = result.scalar_one_or_none()

    if not template:
        raise NotFoundError("支出项模板", template_id)

    # 系统预设项只允许修改支出范围，不允许修改名称
    if template.is_system:
        allowed_fields = {'expected_min', 'expected_max', 'is_active', 'sort_order'}
        update_data = data.model_dump(exclude_unset=True)
        for field in update_data:
            if field not in allowed_fields:
                raise ValidationError(f"系统预设项不可修改 {field} 字段")
        for field, value in update_data.items():
            setattr(template, field, value)
    else:
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(template, field, value)

    await db.flush()
    return _expense_template_to_response(template)


async def delete_expense_template(
    db: AsyncSession, template_id: str, family_id: str, user_id: str
) -> None:
    """Delete an expense template (only if no records exist)."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(ExpenseTemplate).where(
        ExpenseTemplate.id == template_id,
        ExpenseTemplate.family_id == family_id,
    )
    result = await db.execute(stmt)
    template = result.scalar_one_or_none()

    if not template:
        raise NotFoundError("支出项模板", template_id)

    if template.is_system:
        raise ValidationError("系统预设项不可删除")

    # Check if there are any records using this template
    record_count_stmt = select(func.count()).select_from(MonthlyBudgetRecord).where(
        MonthlyBudgetRecord.template_id == template_id
    )
    count_result = await db.execute(record_count_stmt)
    count = count_result.scalar()

    if count > 0:
        raise ValidationError(f"该支出项已有 {count} 条记录，无法删除。请设置为停用状态。")

    await db.delete(template)
    await db.flush()
    logger.info("expense_template_deleted", template_id=template_id)


def _expense_template_to_response(t: ExpenseTemplate) -> ExpenseTemplateResponse:
    return ExpenseTemplateResponse(
        id=t.id,
        name=t.name,
        category_id=t.category_id,
        icon=t.icon,
        expected_min=t.expected_min,
        expected_max=t.expected_max,
        is_fixed=t.is_fixed,
        is_system=t.is_system,
        sort_order=t.sort_order,
        is_active=t.is_active,
        created_at=t.created_at,
    )


# ============================================================
# Income Template Management
# ============================================================

async def create_income_template(
    db: AsyncSession, family_id: str, user_id: str, data: CreateIncomeTemplateRequest
) -> IncomeTemplateResponse:
    """Create a new income template."""
    await _verify_family_member(db, family_id, user_id)

    template = IncomeTemplate(
        id=str(uuid.uuid4()),
        family_id=family_id,
        name=data.name,
        category_id=data.category_id,
        icon=data.icon,
        is_fixed=data.is_fixed,
        is_system=False,
        sort_order=data.sort_order,
        is_active=True,
        created_by=user_id,
    )
    db.add(template)
    await db.flush()

    logger.info("income_template_created", template_id=template.id, name=data.name)
    return _income_template_to_response(template)


async def list_income_templates(
    db: AsyncSession, family_id: str, user_id: str, active_only: bool = True
) -> list[IncomeTemplateResponse]:
    """List all income templates for a family."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(IncomeTemplate).where(IncomeTemplate.family_id == family_id)
    if active_only:
        stmt = stmt.where(IncomeTemplate.is_active.is_(True))
    stmt = stmt.order_by(IncomeTemplate.sort_order, IncomeTemplate.created_at)

    result = await db.execute(stmt)
    templates = result.scalars().all()
    return [_income_template_to_response(t) for t in templates]


async def update_income_template(
    db: AsyncSession, template_id: str, family_id: str, user_id: str,
    data: UpdateIncomeTemplateRequest,
) -> IncomeTemplateResponse:
    """Update an income template."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(IncomeTemplate).where(
        IncomeTemplate.id == template_id,
        IncomeTemplate.family_id == family_id,
    )
    result = await db.execute(stmt)
    template = result.scalar_one_or_none()

    if not template:
        raise NotFoundError("收入项模板", template_id)

    # 系统预设项只允许修改部分字段
    if template.is_system:
        allowed_fields = {'is_active', 'sort_order'}
        update_data = data.model_dump(exclude_unset=True)
        for field in update_data:
            if field not in allowed_fields:
                raise ValidationError(f"系统预设项不可修改 {field} 字段")
        for field, value in update_data.items():
            setattr(template, field, value)
    else:
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(template, field, value)

    await db.flush()
    return _income_template_to_response(template)


async def delete_income_template(
    db: AsyncSession, template_id: str, family_id: str, user_id: str
) -> None:
    """Delete an income template (only if no records exist)."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(IncomeTemplate).where(
        IncomeTemplate.id == template_id,
        IncomeTemplate.family_id == family_id,
    )
    result = await db.execute(stmt)
    template = result.scalar_one_or_none()

    if not template:
        raise NotFoundError("收入项模板", template_id)

    if template.is_system:
        raise ValidationError("系统预设项不可删除")

    # Check if there are any records using this template
    record_count_stmt = select(func.count()).select_from(MonthlyBudgetRecord).where(
        MonthlyBudgetRecord.template_id == template_id
    )
    count_result = await db.execute(record_count_stmt)
    count = count_result.scalar()

    if count > 0:
        raise ValidationError(f"该收入项已有 {count} 条记录，无法删除。请设置为停用状态。")

    await db.delete(template)
    await db.flush()
    logger.info("income_template_deleted", template_id=template_id)


def _income_template_to_response(t: IncomeTemplate) -> IncomeTemplateResponse:
    return IncomeTemplateResponse(
        id=t.id,
        name=t.name,
        category_id=t.category_id,
        icon=t.icon,
        is_fixed=t.is_fixed,
        is_system=t.is_system,
        sort_order=t.sort_order,
        is_active=t.is_active,
        created_at=t.created_at,
    )


# ============================================================
# Monthly Budget Records
# ============================================================

async def get_monthly_records(
    db: AsyncSession, family_id: str, user_id: str, year_month: str
) -> MonthlySummaryResponse:
    """Get all budget records for a specific month."""
    await _verify_family_member(db, family_id, user_id)

    # Get all active templates
    expense_templates = await list_expense_templates(db, family_id, user_id, active_only=True)
    income_templates = await list_income_templates(db, family_id, user_id, active_only=True)

    # Get existing records for this month
    stmt = select(MonthlyBudgetRecord).where(
        MonthlyBudgetRecord.family_id == family_id,
        MonthlyBudgetRecord.year_month == year_month,
    )
    result = await db.execute(stmt)
    records = result.scalars().all()

    # Build record map
    record_map = {r.template_id: r for r in records}

    # Build expense records
    # 固定项：始终显示
    # 临时项：只有在有记录时才显示
    expense_records = []
    total_expense = 0
    for template in expense_templates:
        record = record_map.get(template.id)

        # 临时项且没有记录，跳过
        if not template.is_fixed and record is None:
            continue

        actual_amount = record.actual_amount if record else 0
        total_expense += actual_amount
        expense_records.append(MonthlyRecordResponse(
            id=record.id if record else "",
            template_id=template.id,
            template_type="expense",
            template_name=template.name,
            template_icon=template.icon,
            expected_min=template.expected_min,
            expected_max=template.expected_max,
            actual_amount=actual_amount,
            notes=record.notes if record else None,
            created_at=record.created_at if record else datetime.min,
        ))

    # Build income records
    # 固定项：始终显示
    # 临时项：只有在有记录时才显示
    income_records = []
    total_income = 0
    for template in income_templates:
        record = record_map.get(template.id)

        # 临时项且没有记录，跳过
        if not template.is_fixed and record is None:
            continue

        actual_amount = record.actual_amount if record else 0
        total_income += actual_amount
        income_records.append(MonthlyRecordResponse(
            id=record.id if record else "",
            template_id=template.id,
            template_type="income",
            template_name=template.name,
            template_icon=template.icon,
            expected_min=0,
            expected_max=0,
            actual_amount=actual_amount,
            notes=record.notes if record else None,
            created_at=record.created_at if record else datetime.min,
        ))

    net = total_income - total_expense
    savings_rate = (net / total_income * 100) if total_income > 0 else 0

    return MonthlySummaryResponse(
        year_month=year_month,
        total_income=total_income,
        total_expense=total_expense,
        net=net,
        savings_rate=round(savings_rate, 2),
        income_records=income_records,
        expense_records=expense_records,
    )


async def save_monthly_records(
    db: AsyncSession, family_id: str, user_id: str, year_month: str,
    data: BatchSaveMonthlyRequest,
) -> None:
    """Batch save monthly budget records."""
    await _verify_family_member(db, family_id, user_id)

    for item in data.records:
        # Check if record already exists
        stmt = select(MonthlyBudgetRecord).where(
            MonthlyBudgetRecord.family_id == family_id,
            MonthlyBudgetRecord.year_month == year_month,
            MonthlyBudgetRecord.template_id == item.template_id,
        )
        result = await db.execute(stmt)
        record = result.scalar_one_or_none()

        if record:
            # Update existing record
            record.actual_amount = item.actual_amount
            record.notes = item.notes
        else:
            # Create new record
            record = MonthlyBudgetRecord(
                id=str(uuid.uuid4()),
                family_id=family_id,
                year_month=year_month,
                template_id=item.template_id,
                template_type=item.template_type,
                actual_amount=item.actual_amount,
                notes=item.notes,
                recorded_by=user_id,
            )
            db.add(record)

    await db.flush()
    logger.info("monthly_records_saved", family_id=family_id, year_month=year_month, count=len(data.records))


async def get_yearly_summary(
    db: AsyncSession, family_id: str, user_id: str, year: int
) -> YearlySummaryResponse:
    """Get yearly budget summary."""
    await _verify_family_member(db, family_id, user_id)

    # Get all records for the year
    stmt = select(MonthlyBudgetRecord).where(
        MonthlyBudgetRecord.family_id == family_id,
        MonthlyBudgetRecord.year_month.like(f"{year}-%"),
    )
    result = await db.execute(stmt)
    records = result.scalars().all()

    # Get templates for names
    expense_templates = await list_expense_templates(db, family_id, user_id, active_only=False)
    income_templates = await list_income_templates(db, family_id, user_id, active_only=False)
    template_map = {t.id: t for t in expense_templates + income_templates}

    # Group by month
    monthly_data = {}
    for month in range(1, 13):
        month_key = f"{year}-{month:02d}"
        monthly_data[month_key] = {
            "month": month,
            "month_key": month_key,
            "income": 0,
            "expense": 0,
            "net": 0,
        }

    # Group by category
    category_data = {}

    for record in records:
        month_key = record.year_month
        if month_key in monthly_data:
            if record.template_type == "income":
                monthly_data[month_key]["income"] += record.actual_amount
            else:
                monthly_data[month_key]["expense"] += record.actual_amount

        # Category aggregation
        template = template_map.get(record.template_id)
        if template:
            cat_name = template.name
            if cat_name not in category_data:
                category_data[cat_name] = {"name": cat_name, "type": record.template_type, "total": 0}
            category_data[cat_name]["total"] += record.actual_amount

    # Calculate net for each month
    for month_key in monthly_data:
        monthly_data[month_key]["net"] = (
            monthly_data[month_key]["income"] - monthly_data[month_key]["expense"]
        )

    monthly_list = list(monthly_data.values())
    total_income = sum(m["income"] for m in monthly_list)
    total_expense = sum(m["expense"] for m in monthly_list)
    total_net = total_income - total_expense
    avg_savings_rate = (total_net / total_income * 100) if total_income > 0 else 0

    return YearlySummaryResponse(
        year=year,
        total_income=total_income,
        total_expense=total_expense,
        total_net=total_net,
        average_savings_rate=round(avg_savings_rate, 2),
        monthly_data=monthly_list,
        by_category=list(category_data.values()),
    )


# ============================================================
# Investment Transactions
# ============================================================

async def create_transaction(
    db: AsyncSession, family_id: str, user_id: str, data: CreateTransactionRequest
) -> TransactionResponse:
    """Record an investment transaction and sync asset data."""
    await _verify_family_member(db, family_id, user_id)

    # 移除时区信息，确保是 naive datetime（数据库是 TIMESTAMP WITHOUT TIME ZONE）
    transaction_date = data.date.replace(tzinfo=None) if data.date.tzinfo else data.date

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
        date=transaction_date,
        notes=data.notes,
    )
    db.add(transaction)
    await db.flush()

    # Auto-sync asset financial data
    await _sync_asset_after_transaction(db, data.asset_id)

    logger.info("transaction_created", type=data.type, asset_id=data.asset_id, total=data.total)
    return _transaction_to_response(transaction)


async def _sync_asset_after_transaction(db: AsyncSession, asset_id: str) -> None:
    """Sync asset financial metadata after a transaction is created/updated."""
    from app.assets.models import AssetFinancial, AssetMetadataFinancial
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

    # Calculate remaining cost using average cost method
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

        # 查询实时价格更新 current_price
        ticker = metadata.ticker
        if ticker:
            try:
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
                pass

        await db.flush()

    # Update AssetFinancial - 更新成本和当前价值
    financial_stmt = select(AssetFinancial).where(AssetFinancial.asset_id == asset_id)
    financial_result = await db.execute(financial_stmt)
    financial = financial_result.scalar_one_or_none()

    if financial:
        financial.purchase_price = remaining_cost
        current_price = metadata.current_price if metadata else None
        if current_price and net_shares > 0:
            financial.current_value = current_price * net_shares
        else:
            financial.current_value = remaining_cost
        await db.flush()


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
# Portfolio Aggregation
# ============================================================

async def get_portfolio(
    db: AsyncSession, family_id: str, user_id: str
) -> dict[str, Any]:
    """Get aggregated portfolio view grouped by asset."""
    await _verify_family_member(db, family_id, user_id)

    from app.assets.models import Asset, AssetFinancial, AssetMetadataFinancial

    # Query all financial assets with their financial data
    stmt = (
        select(Asset, AssetFinancial, AssetMetadataFinancial)
        .join(AssetFinancial, AssetFinancial.asset_id == Asset.id)
        .outerjoin(AssetMetadataFinancial, AssetMetadataFinancial.asset_id == Asset.id)
        .where(
            Asset.family_id == family_id,
            Asset.nature == "financial",
            Asset.status == "active",
        )
        .order_by(Asset.name)
    )
    result = await db.execute(stmt)
    rows = result.all()

    holdings = []
    total_value = 0.0
    total_cost = 0.0

    for asset, financial, metadata in rows:
        # Get transaction summary for this asset
        tx_stmt = (
            select(
                func.coalesce(func.sum(Transaction.quantity), 0).label("total_shares"),
                func.coalesce(func.sum(Transaction.total), 0).label("total_invested"),
                func.count(Transaction.id).label("tx_count"),
            )
            .where(
                Transaction.asset_id == asset.id,
                Transaction.type.in_(["buy", "sell"]),
            )
        )
        tx_result = await db.execute(tx_stmt)
        tx_row = tx_result.one()

        # Calculate net shares (buy adds, sell subtracts)
        buy_stmt = (
            select(func.coalesce(func.sum(Transaction.quantity), 0))
            .where(
                Transaction.asset_id == asset.id,
                Transaction.type == "buy",
            )
        )
        sell_stmt = (
            select(func.coalesce(func.sum(Transaction.quantity), 0))
            .where(
                Transaction.asset_id == asset.id,
                Transaction.type == "sell",
            )
        )
        buy_shares = (await db.execute(buy_stmt)).scalar() or 0
        sell_shares = (await db.execute(sell_stmt)).scalar() or 0
        net_shares = buy_shares - sell_shares

        # Calculate cost basis
        buy_total = (await db.execute(
            select(func.coalesce(func.sum(Transaction.total), 0))
            .where(
                Transaction.asset_id == asset.id,
                Transaction.type == "buy",
            )
        )).scalar() or 0

        # Net cost = buy total - sell total (proportional)
        if buy_shares > 0 and sell_shares > 0:
            avg_buy_price = buy_total / buy_shares
            cost_of_sold = avg_buy_price * sell_shares
            remaining_cost = buy_total - cost_of_sold
        elif buy_shares > 0:
            remaining_cost = buy_total
        else:
            # 没有交易记录时（定期/国债等），使用购买价格作为成本
            remaining_cost = financial.purchase_price if financial else 0

        current_value = financial.current_value if financial else 0

        # 计算收益：优先使用 expected_yield 或 annual_income
        if metadata and metadata.annual_income is not None and metadata.annual_income > 0:
            # 使用手动输入的年收益金额
            gain = metadata.annual_income
            gain_source = 'manual'
        elif metadata and metadata.expected_yield is not None and metadata.expected_yield > 0:
            # 使用年化收益率计算
            gain = current_value * (metadata.expected_yield / 100)
            gain_source = 'yield'
        else:
            # 使用市值与成本的差额（适用于股票等）
            gain = current_value - remaining_cost
            gain_source = 'market'

        gain_percent = (gain / remaining_cost * 100) if remaining_cost > 0 else 0

        total_value += current_value
        total_cost += remaining_cost

        # Get recent transactions
        recent_tx_stmt = (
            select(Transaction)
            .where(Transaction.asset_id == asset.id)
            .order_by(Transaction.date.desc())
            .limit(5)
        )
        recent_tx_result = await db.execute(recent_tx_stmt)
        recent_txs = recent_tx_result.scalars().all()

        holdings.append({
            "asset_id": asset.id,
            "name": asset.name,
            "instrument_type": metadata.instrument_type if metadata else None,
            "ticker": metadata.ticker if metadata else None,
            "currency": financial.currency if financial else "CNY",
            "shares": net_shares,
            "average_cost": (remaining_cost / net_shares) if net_shares > 0 else 0,
            "current_value": current_value,
            "current_price": metadata.current_price if metadata else None,
            "cost": round(remaining_cost, 2),
            "gain": round(gain, 2),
            "gain_percent": round(gain_percent, 2),
            "gain_source": gain_source,
            "expected_yield": metadata.expected_yield if metadata else None,
            "annual_income": metadata.annual_income if metadata else None,
            "transaction_count": tx_row.tx_count,
            "recent_transactions": [
                {
                    "id": tx.id,
                    "type": tx.type,
                    "quantity": tx.quantity,
                    "price": tx.price,
                    "total": tx.total,
                    "date": tx.date.isoformat() if tx.date else None,
                }
                for tx in recent_txs
            ],
        })

    total_gain = sum(h['gain'] for h in holdings)
    total_gain_percent = (total_gain / total_cost * 100) if total_cost > 0 else 0

    return {
        "total_value": round(total_value, 2),
        "total_cost": round(total_cost, 2),
        "total_gain": round(total_gain, 2),
        "total_gain_percent": round(total_gain_percent, 2),
        "holdings_count": len(holdings),
        "holdings": holdings,
    }


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
        recorded_at=utcnow(),
    )
    db.add(snapshot)
    await db.flush()


async def get_price_history(
    db: AsyncSession, asset_id: str, days: int = 30
) -> list[dict[str, Any]]:
    """Get price history for an asset."""
    from datetime import timedelta
    cutoff = utcnow() - timedelta(days=days)

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
