"""Finance models: liabilities, transactions, budget templates, categories, price snapshots."""

from datetime import datetime

from sqlalchemy import Column, Index, Text
from sqlalchemy.dialects.postgresql import JSON
from sqlmodel import Field

from app.common.models import TimestampMixin, utcnow

# ============================================================
# Liabilities
# ============================================================

class Liability(TimestampMixin, table=True):
    """Liability records: mortgage, auto loan, credit card, consumer loan, personal loan."""
    __tablename__ = "liabilities"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    asset_id: str | None = Field(default=None, max_length=36, index=True, description="关联资产ID")
    created_by: str = Field(max_length=36, description="创建者用户ID")

    type: str = Field(max_length=20, description="类型: mortgage/auto_loan/credit_card/consumer_loan/personal_loan")
    name: str = Field(max_length=200, description="负债名称")
    lender: str | None = Field(default=None, max_length=200, description="债权人")
    original_amount: float = Field(description="原始金额")
    current_balance: float = Field(description="当前余额")
    interest_rate: float | None = Field(default=None, description="年利率(%)")
    monthly_payment: float | None = Field(default=None, description="月供")
    start_date: datetime | None = Field(default=None, description="开始日期")
    end_date: datetime | None = Field(default=None, description="结束日期")
    payment_day: int | None = Field(default=None, description="每月还款日")
    notes: str | None = Field(default=None, sa_column=Column(Text), description="备注")
    status: str = Field(default="active", max_length=20, description="状态: active/paid_off/defaulted")


# ============================================================
# Transactions (Investment)
# ============================================================

class Transaction(TimestampMixin, table=True):
    """Investment transaction records: buy, sell, dividend, split, transfer, fee."""
    __tablename__ = "transactions"
    __table_args__ = (
        Index("idx_transaction_asset_date", "asset_id", "date"),
    )

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, index=True, description="资产ID")
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    created_by: str = Field(max_length=36, description="创建者用户ID")

    type: str = Field(max_length=20, description="类型: buy/sell/dividend/split/transfer/fee")
    quantity: float | None = Field(default=None, description="数量")
    price: float | None = Field(default=None, description="单价")
    total: float = Field(description="总金额")
    fees: float = Field(default=0, description="手续费")
    date: datetime = Field(description="交易日期")
    notes: str | None = Field(default=None, sa_column=Column(Text), description="备注")


# ============================================================
# Income & Expense Categories
# ============================================================

class ExpenseCategory(TimestampMixin, table=True):
    """Standard expense categories (Chinese convention)."""
    __tablename__ = "expense_categories"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    name: str = Field(max_length=50, description="中文名称")
    name_en: str = Field(max_length=50, description="英文名称")
    icon: str | None = Field(default=None, max_length=50, description="图标标识")
    parent_id: str | None = Field(default=None, max_length=36, index=True, description="父分类ID")
    sort_order: int = Field(default=0, description="排序")
    is_system: bool = Field(default=True, description="是否系统预设")


class IncomeCategory(TimestampMixin, table=True):
    """Standard income categories (Chinese convention)."""
    __tablename__ = "income_categories"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    name: str = Field(max_length=50, description="中文名称")
    name_en: str = Field(max_length=50, description="英文名称")
    icon: str | None = Field(default=None, max_length=50, description="图标标识")
    parent_id: str | None = Field(default=None, max_length=36, index=True, description="父分类ID")
    sort_order: int = Field(default=0, description="排序")
    is_system: bool = Field(default=True, description="是否系统预设")


# ============================================================
# Income & Expense Records
# ============================================================

class IncomeExpenseRecord(TimestampMixin, table=True):
    """Income and expense tracking records."""
    __tablename__ = "income_expense_records"
    __table_args__ = (
        Index("idx_ie_family_date", "family_id", "date"),
        Index("idx_ie_family_type", "family_id", "type"),
    )

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    user_id: str = Field(max_length=36, description="记录者用户ID")

    type: str = Field(max_length=10, description="类型: income/expense")
    category_id: str | None = Field(default=None, max_length=36, description="分类ID")
    subcategory_id: str | None = Field(default=None, max_length=36, description="子分类ID")
    amount: float = Field(description="金额")
    currency: str = Field(default="CNY", max_length=3, description="货币")
    date: datetime = Field(description="日期")
    description: str | None = Field(default=None, max_length=500, description="描述")
    notes: str | None = Field(default=None, sa_column=Column(Text), description="备注")

    # Recurring settings
    is_recurring: bool = Field(default=False, description="是否周期性")
    recurring_config: dict | None = Field(default=None, sa_column=Column(JSON), description="周期配置")


# ============================================================
# Budget Templates (新系统)
# ============================================================

class ExpenseTemplate(TimestampMixin, table=True):
    """支出项模板（固定支出项和临时支出项）"""
    __tablename__ = "expense_templates"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    name: str = Field(max_length=100, description="名称（如：房租、水电、餐饮）")
    category_id: str | None = Field(default=None, max_length=36, description="关联分类ID")
    icon: str | None = Field(default=None, max_length=50, description="图标标识")
    expected_min: float = Field(default=0, description="预期最小值")
    expected_max: float = Field(default=0, description="预期最大值")
    is_fixed: bool = Field(default=True, description="是否固定项（每月自动显示）")
    is_system: bool = Field(default=False, description="是否系统预设（不可删除）")
    sort_order: int = Field(default=0, description="排序")
    is_active: bool = Field(default=True, description="是否启用")
    created_by: str = Field(max_length=36, description="创建者用户ID")


class IncomeTemplate(TimestampMixin, table=True):
    """收入项模板"""
    __tablename__ = "income_templates"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    name: str = Field(max_length=100, description="名称（如：工资、奖金、兼职）")
    category_id: str | None = Field(default=None, max_length=36, description="关联分类ID")
    icon: str | None = Field(default=None, max_length=50, description="图标标识")
    is_fixed: bool = Field(default=True, description="是否固定项")
    is_system: bool = Field(default=False, description="是否系统预设（不可删除）")
    sort_order: int = Field(default=0, description="排序")
    is_active: bool = Field(default=True, description="是否启用")
    created_by: str = Field(max_length=36, description="创建者用户ID")


class MonthlyBudgetRecord(TimestampMixin, table=True):
    """月度收支记录"""
    __tablename__ = "monthly_budget_records"
    __table_args__ = (
        Index("idx_mbr_family_month", "family_id", "year_month"),
        Index("idx_mbr_family_template", "family_id", "template_id"),
        Index("idx_mbr_family_type", "family_id", "template_type"),
    )

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="家庭ID")
    year_month: str = Field(max_length=7, description="格式：2024-01")
    template_id: str = Field(max_length=36, description="关联模板ID")
    template_type: str = Field(max_length=10, description="类型：expense/income")
    actual_amount: float = Field(default=0, description="实际金额")
    notes: str | None = Field(default=None, max_length=500, description="备注")
    recorded_by: str = Field(max_length=36, description="记录者用户ID")


# ============================================================
# Price Snapshots
# ============================================================

class PriceSnapshot(TimestampMixin, table=True):
    """Historical price records for financial assets."""
    __tablename__ = "price_snapshots"
    __table_args__ = (
        Index("idx_price_asset_time", "asset_id", "recorded_at"),
    )

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, index=True, description="资产ID")
    price: float = Field(description="价格")
    currency: str = Field(default="CNY", max_length=3, description="货币")
    source: str = Field(max_length=30, description="来源: manual/alphavantage/coingecko/yahoo")
    recorded_at: datetime = Field(default_factory=utcnow, description="记录时间")
