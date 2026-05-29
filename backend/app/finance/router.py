"""Finance management API router."""

from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db
from app.finance import service as finance_service
from app.finance.schemas import (
    CostBasisInfo,
    CreateIncomeExpenseRequest,
    CreateLiabilityRequest,
    CreateTransactionRequest,
    IncomeExpenseResponse,
    IncomeExpenseSummary,
    LiabilityListResponse,
    LiabilityResponse,
    TransactionResponse,
    UpdateIncomeExpenseRequest,
    UpdateLiabilityRequest,
)

router = APIRouter()


# ============================================================
# Liability Endpoints
# ============================================================

@router.post(
    "/liabilities",
    response_model=SuccessResponse[LiabilityResponse],
    status_code=201,
    summary="记录负债",
    description="创建新的负债记录（房贷、车贷、信用卡等）",
)
async def create_liability(
    family_id: str,
    data: CreateLiabilityRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    liability = await finance_service.create_liability(db, family_id, current_user.id, data)
    return SuccessResponse(data=liability, message="负债记录创建成功")


@router.get(
    "/liabilities",
    response_model=SuccessResponse[LiabilityListResponse],
    summary="负债列表",
    description="获取家庭所有负债",
)
async def list_liabilities(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await finance_service.list_liabilities(db, family_id, current_user.id)
    return SuccessResponse(data=result)


@router.put(
    "/liabilities/{liability_id}",
    response_model=SuccessResponse[LiabilityResponse],
    summary="更新负债",
    description="更新负债信息",
)
async def update_liability(
    family_id: str,
    liability_id: str,
    data: UpdateLiabilityRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    liability = await finance_service.update_liability(db, liability_id, family_id, current_user.id, data)
    return SuccessResponse(data=liability, message="更新成功")


@router.delete(
    "/liabilities/{liability_id}",
    response_model=MessageResponse,
    summary="还清负债",
    description="标记负债为已还清",
)
async def delete_liability(
    family_id: str,
    liability_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await finance_service.delete_liability(db, liability_id, family_id, current_user.id)
    return MessageResponse(message="负债已标记为还清")


# ============================================================
# Income/Expense Endpoints
# ============================================================

@router.post(
    "/income-expense",
    response_model=SuccessResponse[IncomeExpenseResponse],
    status_code=201,
    summary="记录收支",
    description="记录收入或支出",
)
async def create_income_expense(
    family_id: str,
    data: CreateIncomeExpenseRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    record = await finance_service.create_income_expense(db, family_id, current_user.id, data)
    return SuccessResponse(data=record, message="记录成功")


@router.get(
    "/income-expense",
    response_model=SuccessResponse[dict],
    summary="收支列表",
    description="获取收支记录列表（支持筛选）",
)
async def list_income_expense(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    type: str | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    page: int = 1,
    page_size: int = 20,
):
    result = await finance_service.list_income_expense(
        db, family_id, current_user.id,
        record_type=type, start_date=start_date, end_date=end_date,
        page=page, page_size=page_size,
    )
    return SuccessResponse(data=result)


@router.get(
    "/income-expense/summary",
    response_model=SuccessResponse[IncomeExpenseSummary],
    summary="收支汇总",
    description="获取收支汇总统计",
)
async def get_income_expense_summary(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    start_date: datetime | None = None,
    end_date: datetime | None = None,
):
    summary = await finance_service.get_income_expense_summary(
        db, family_id, current_user.id,
        start_date=start_date, end_date=end_date,
    )
    return SuccessResponse(data=summary)


@router.put(
    "/income-expense/{record_id}",
    response_model=SuccessResponse[IncomeExpenseResponse],
    summary="更新收支",
    description="更新收支记录",
)
async def update_income_expense(
    family_id: str,
    record_id: str,
    data: UpdateIncomeExpenseRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    record = await finance_service.update_income_expense(
        db, record_id, family_id, current_user.id, data,
    )
    return SuccessResponse(data=record, message="更新成功")


@router.delete(
    "/income-expense/{record_id}",
    response_model=MessageResponse,
    summary="删除收支",
    description="删除收支记录",
)
async def delete_income_expense(
    family_id: str,
    record_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await finance_service.delete_income_expense(db, record_id, family_id, current_user.id)
    return MessageResponse(message="记录已删除")


# ============================================================
# Category Endpoints
# ============================================================

@router.get(
    "/categories/expense",
    response_model=SuccessResponse[list],
    summary="支出分类",
    description="获取标准支出分类（含子分类）",
)
async def get_expense_categories(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    categories = await finance_service.get_expense_categories(db)
    return SuccessResponse(data=categories)


@router.get(
    "/categories/income",
    response_model=SuccessResponse[list],
    summary="收入分类",
    description="获取标准收入分类（含子分类）",
)
async def get_income_categories(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    categories = await finance_service.get_income_categories(db)
    return SuccessResponse(data=categories)


# ============================================================
# Transaction Endpoints
# ============================================================

@router.post(
    "/transactions",
    response_model=SuccessResponse[TransactionResponse],
    status_code=201,
    summary="记录交易",
    description="记录投资交易（买入/卖出/分红等）",
)
async def create_transaction(
    family_id: str,
    data: CreateTransactionRequest,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    transaction = await finance_service.create_transaction(db, family_id, current_user.id, data)
    return SuccessResponse(data=transaction, message="交易记录成功")


@router.get(
    "/transactions",
    response_model=SuccessResponse[dict],
    summary="交易列表",
    description="获取投资交易记录",
)
async def list_transactions(
    family_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    asset_id: str | None = None,
    page: int = 1,
    page_size: int = 20,
):
    result = await finance_service.list_transactions(
        db, family_id, current_user.id,
        asset_id=asset_id, page=page, page_size=page_size,
    )
    return SuccessResponse(data=result)


@router.get(
    "/cost-basis/{asset_id}",
    response_model=SuccessResponse[CostBasisInfo],
    summary="成本基础",
    description="获取资产的成本基础（FIFO/LIFO/平均成本）",
)
async def get_cost_basis(
    family_id: str,
    asset_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    method: str = Query("average_cost", pattern="^(fifo|lifo|average_cost)$"),
):
    result = await finance_service.get_cost_basis(db, family_id, current_user.id, asset_id, method)
    return SuccessResponse(data=result)


# ============================================================
# Price Endpoints
# ============================================================

@router.get(
    "/price-history/{asset_id}",
    response_model=SuccessResponse[list],
    summary="价格历史",
    description="获取资产的价格历史",
)
async def get_price_history(
    asset_id: str,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    days: int = 30,
):
    history = await finance_service.get_price_history(db, asset_id, days)
    return SuccessResponse(data=history)
