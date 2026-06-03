"""Finance management schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

# ============================================================
# Liability Schemas
# ============================================================

class CreateLiabilityRequest(BaseModel):
    """Create a new liability."""
    name: str = Field(min_length=1, max_length=200, description="负债名称")
    type: str = Field(
        pattern="^(mortgage|auto_loan|credit_card|consumer_loan|personal_loan)$",
        description="类型",
    )
    lender: str | None = Field(default=None, max_length=200, description="债权人")
    original_amount: float = Field(gt=0, description="原始金额")
    current_balance: float = Field(ge=0, description="当前余额")
    interest_rate: float | None = Field(default=None, ge=0, le=100, description="年利率(%)")
    monthly_payment: float | None = Field(default=None, ge=0, description="月供")
    start_date: datetime | None = Field(default=None, description="开始日期")
    end_date: datetime | None = Field(default=None, description="结束日期")
    payment_day: int | None = Field(default=None, ge=1, le=31, description="每月还款日")
    notes: str | None = Field(default=None, description="备注")
    asset_id: str | None = Field(default=None, description="关联资产ID")


class UpdateLiabilityRequest(BaseModel):
    """Update a liability."""
    name: str | None = None
    lender: str | None = None
    current_balance: float | None = None
    interest_rate: float | None = None
    monthly_payment: float | None = None
    payment_day: int | None = None
    notes: str | None = None
    status: str | None = None


class LiabilityResponse(BaseModel):
    """Liability information."""
    id: str
    name: str
    type: str
    lender: str | None = None
    original_amount: float
    current_balance: float
    interest_rate: float | None = None
    monthly_payment: float | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    payment_day: int | None = None
    status: str = "active"
    asset_id: str | None = None
    notes: str | None = None
    created_at: datetime


class LiabilityListResponse(BaseModel):
    """Liability list."""
    liabilities: list[LiabilityResponse]
    total: int
    total_balance: float


# ============================================================
# Income/Expense Schemas
# ============================================================

class CreateIncomeExpenseRequest(BaseModel):
    """Record an income or expense."""
    type: str = Field(pattern="^(income|expense)$", description="类型: income/expense")
    category_id: str | None = Field(default=None, description="分类ID")
    subcategory_id: str | None = Field(default=None, description="子分类ID")
    amount: float = Field(gt=0, description="金额")
    currency: str = Field(default="CNY", max_length=3, description="货币")
    date: datetime = Field(description="日期")
    description: str | None = Field(default=None, max_length=500, description="描述")
    notes: str | None = Field(default=None, description="备注")
    is_recurring: bool = Field(default=False, description="是否周期性")
    recurring_config: dict[str, Any] | None = Field(default=None, description="周期配置")


class UpdateIncomeExpenseRequest(BaseModel):
    """Update an income/expense record."""
    category_id: str | None = None
    amount: float | None = None
    date: datetime | None = None
    description: str | None = None
    notes: str | None = None


class IncomeExpenseResponse(BaseModel):
    """Income/expense record."""
    id: str
    type: str
    category_id: str | None = None
    subcategory_id: str | None = None
    amount: float
    currency: str = "CNY"
    date: datetime
    description: str | None = None
    is_recurring: bool = False
    created_at: datetime


class IncomeExpenseSummary(BaseModel):
    """Income/expense summary."""
    total_income: float
    total_expense: float
    net: float
    savings_rate: float
    period_start: datetime | None = None
    period_end: datetime | None = None
    by_category: list[dict[str, Any]] = []


class CategoryResponse(BaseModel):
    """Category information."""
    id: str
    name: str
    name_en: str
    icon: str | None = None
    parent_id: str | None = None
    sort_order: int = 0


# ============================================================
# Budget Template Schemas
# ============================================================

class CreateExpenseTemplateRequest(BaseModel):
    """Create a new expense template."""
    name: str = Field(min_length=1, max_length=100, description="支出项名称")
    category_id: str | None = Field(default=None, description="关联分类ID")
    icon: str | None = Field(default=None, max_length=50, description="图标标识")
    expected_min: float = Field(default=0, ge=0, description="预期最小值")
    expected_max: float = Field(default=0, ge=0, description="预期最大值")
    is_fixed: bool = Field(default=True, description="是否固定项")
    sort_order: int = Field(default=0, description="排序")


class UpdateExpenseTemplateRequest(BaseModel):
    """Update an expense template."""
    name: str | None = None
    category_id: str | None = None
    icon: str | None = None
    expected_min: float | None = None
    expected_max: float | None = None
    is_fixed: bool | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class ExpenseTemplateResponse(BaseModel):
    """Expense template information."""
    id: str
    name: str
    category_id: str | None = None
    icon: str | None = None
    expected_min: float = 0
    expected_max: float = 0
    is_fixed: bool = True
    is_system: bool = False
    sort_order: int = 0
    is_active: bool = True
    created_at: datetime


class CreateIncomeTemplateRequest(BaseModel):
    """Create a new income template."""
    name: str = Field(min_length=1, max_length=100, description="收入项名称")
    category_id: str | None = Field(default=None, description="关联分类ID")
    icon: str | None = Field(default=None, max_length=50, description="图标标识")
    is_fixed: bool = Field(default=True, description="是否固定项")
    sort_order: int = Field(default=0, description="排序")


class UpdateIncomeTemplateRequest(BaseModel):
    """Update an income template."""
    name: str | None = None
    category_id: str | None = None
    icon: str | None = None
    is_fixed: bool | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class IncomeTemplateResponse(BaseModel):
    """Income template information."""
    id: str
    name: str
    category_id: str | None = None
    icon: str | None = None
    is_fixed: bool = True
    is_system: bool = False
    sort_order: int = 0
    is_active: bool = True
    created_at: datetime


# ============================================================
# Monthly Budget Schemas
# ============================================================

class SaveMonthlyRecordRequest(BaseModel):
    """Save a monthly budget record."""
    template_id: str = Field(description="模板ID")
    template_type: str = Field(pattern="^(income|expense)$", description="类型")
    actual_amount: float = Field(ge=0, description="实际金额")
    notes: str | None = Field(default=None, max_length=500, description="备注")


class BatchSaveMonthlyRequest(BaseModel):
    """Batch save monthly budget records."""
    records: list[SaveMonthlyRecordRequest] = Field(description="记录列表")


class MonthlyRecordResponse(BaseModel):
    """Monthly budget record."""
    id: str
    template_id: str
    template_type: str
    template_name: str
    template_icon: str | None = None
    expected_min: float = 0
    expected_max: float = 0
    actual_amount: float = 0
    notes: str | None = None
    created_at: datetime


class MonthlySummaryResponse(BaseModel):
    """Monthly budget summary."""
    year_month: str
    total_income: float
    total_expense: float
    net: float
    savings_rate: float
    income_records: list[MonthlyRecordResponse]
    expense_records: list[MonthlyRecordResponse]


class YearlySummaryResponse(BaseModel):
    """Yearly budget summary."""
    year: int
    total_income: float
    total_expense: float
    total_net: float
    average_savings_rate: float
    monthly_data: list[dict[str, Any]]
    by_category: list[dict[str, Any]]


# ============================================================
# Transaction Schemas
# ============================================================

class CreateTransactionRequest(BaseModel):
    """Record an investment transaction."""
    asset_id: str = Field(description="资产ID")
    type: str = Field(
        pattern="^(buy|sell|dividend|split|transfer|fee)$",
        description="交易类型",
    )
    quantity: float | None = Field(default=None, ge=0, description="数量")
    price: float | None = Field(default=None, ge=0, description="单价")
    total: float = Field(description="总金额")
    fees: float = Field(default=0, ge=0, description="手续费")
    date: datetime = Field(description="交易日期")
    notes: str | None = None


class TransactionResponse(BaseModel):
    """Transaction record."""
    id: str
    asset_id: str
    type: str
    quantity: float | None = None
    price: float | None = None
    total: float
    fees: float = 0
    date: datetime
    notes: str | None = None
    created_at: datetime


class PortfolioSnapshot(BaseModel):
    """Investment portfolio snapshot."""
    total_value: float
    total_cost: float
    total_gain: float
    total_gain_percent: float
    holdings: list[dict[str, Any]] = []


class CostBasisInfo(BaseModel):
    """Cost basis information for an asset."""
    asset_id: str
    method: str
    total_shares: float
    average_cost: float
    total_cost: float
    lots: list[dict[str, Any]] = []


# ============================================================
# Price Schemas
# ============================================================

class PriceInfo(BaseModel):
    """Price information."""
    asset_id: str
    price: float
    currency: str
    source: str
    updated_at: datetime


class PriceHistory(BaseModel):
    """Price history."""
    asset_id: str
    prices: list[dict[str, Any]] = []
