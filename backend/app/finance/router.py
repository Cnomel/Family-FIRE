"""Finance management API router."""


from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db
from app.families.dependencies import verify_family_member
from app.finance import service as finance_service
from app.finance.schemas import (
    BatchSaveMonthlyRequest,
    CostBasisInfo,
    CreateExpenseTemplateRequest,
    CreateIncomeTemplateRequest,
    CreateLiabilityRequest,
    CreateTransactionRequest,
    ExpenseTemplateResponse,
    IncomeTemplateResponse,
    LiabilityListResponse,
    LiabilityResponse,
    MonthlySummaryResponse,
    TransactionResponse,
    UpdateExpenseTemplateRequest,
    UpdateIncomeTemplateRequest,
    UpdateLiabilityRequest,
    YearlySummaryResponse,
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
        data: CreateLiabilityRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
    liability_id: str,
    data: UpdateLiabilityRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
    liability_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await finance_service.delete_liability(db, liability_id, family_id, current_user.id)
    return MessageResponse(message="负债已标记为还清")


# ============================================================
# Expense Template Endpoints
# ============================================================

@router.post(
    "/expense-templates",
    response_model=SuccessResponse[ExpenseTemplateResponse],
    status_code=201,
    summary="创建支出项模板",
    description="创建新的支出项模板",
)
async def create_expense_template(
    data: CreateExpenseTemplateRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    template = await finance_service.create_expense_template(db, family_id, current_user.id, data)
    return SuccessResponse(data=template, message="支出项创建成功")


@router.get(
    "/expense-templates",
    response_model=SuccessResponse[list],
    summary="支出项模板列表",
    description="获取所有支出项模板",
)
async def list_expense_templates(
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    templates = await finance_service.list_expense_templates(db, family_id, current_user.id)
    return SuccessResponse(data=templates)


@router.put(
    "/expense-templates/{template_id}",
    response_model=SuccessResponse[ExpenseTemplateResponse],
    summary="更新支出项模板",
    description="更新支出项模板信息",
)
async def update_expense_template(
    template_id: str,
    data: UpdateExpenseTemplateRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    template = await finance_service.update_expense_template(
        db, template_id, family_id, current_user.id, data,
    )
    return SuccessResponse(data=template, message="更新成功")


@router.delete(
    "/expense-templates/{template_id}",
    response_model=MessageResponse,
    summary="删除支出项模板",
    description="删除支出项模板（有数据时禁止删除）",
)
async def delete_expense_template(
    template_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await finance_service.delete_expense_template(db, template_id, family_id, current_user.id)
    return MessageResponse(message="支出项已删除")


# ============================================================
# Income Template Endpoints
# ============================================================

@router.post(
    "/income-templates",
    response_model=SuccessResponse[IncomeTemplateResponse],
    status_code=201,
    summary="创建收入项模板",
    description="创建新的收入项模板",
)
async def create_income_template(
    data: CreateIncomeTemplateRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    template = await finance_service.create_income_template(db, family_id, current_user.id, data)
    return SuccessResponse(data=template, message="收入项创建成功")


@router.get(
    "/income-templates",
    response_model=SuccessResponse[list],
    summary="收入项模板列表",
    description="获取所有收入项模板",
)
async def list_income_templates(
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    templates = await finance_service.list_income_templates(db, family_id, current_user.id)
    return SuccessResponse(data=templates)


@router.put(
    "/income-templates/{template_id}",
    response_model=SuccessResponse[IncomeTemplateResponse],
    summary="更新收入项模板",
    description="更新收入项模板信息",
)
async def update_income_template(
    template_id: str,
    data: UpdateIncomeTemplateRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    template = await finance_service.update_income_template(
        db, template_id, family_id, current_user.id, data,
    )
    return SuccessResponse(data=template, message="更新成功")


@router.delete(
    "/income-templates/{template_id}",
    response_model=MessageResponse,
    summary="删除收入项模板",
    description="删除收入项模板（有数据时禁止删除）",
)
async def delete_income_template(
    template_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await finance_service.delete_income_template(db, template_id, family_id, current_user.id)
    return MessageResponse(message="收入项已删除")


# ============================================================
# Monthly Budget Endpoints
# ============================================================

@router.get(
    "/monthly/{year_month}",
    response_model=SuccessResponse[MonthlySummaryResponse],
    summary="月度预算记录",
    description="获取某月所有收支记录",
)
async def get_monthly_records(
    year_month: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    result = await finance_service.get_monthly_records(db, family_id, current_user.id, year_month)
    return SuccessResponse(data=result)


@router.post(
    "/monthly/{year_month}",
    response_model=MessageResponse,
    status_code=201,
    summary="保存月度记录",
    description="批量保存某月的收支记录",
)
async def save_monthly_records(
    year_month: str,
    data: BatchSaveMonthlyRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await finance_service.save_monthly_records(db, family_id, current_user.id, year_month, data)
    return MessageResponse(message="保存成功")


# ============================================================
# Yearly Statistics Endpoints
# ============================================================

@router.get(
    "/yearly/{year}/summary",
    response_model=SuccessResponse[YearlySummaryResponse],
    summary="年度统计",
    description="获取年度收支统计",
)
async def get_yearly_summary(
    year: int,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    result = await finance_service.get_yearly_summary(db, family_id, current_user.id, year)
    return SuccessResponse(data=result)


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
    current_user: CurrentUser = None,
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
    current_user: CurrentUser = None,
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
        data: CreateTransactionRequest,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
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
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    asset_id: str | None = None,
    page: int = 1,
    page_size: int = 20,
    family_id: str = Depends(verify_family_member),
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
    asset_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    method: str = Query("average_cost", pattern="^(fifo|lifo|average_cost)$"),
    family_id: str = Depends(verify_family_member),
):
    result = await finance_service.get_cost_basis(db, family_id, current_user.id, asset_id, method)
    return SuccessResponse(data=result)


@router.get(
    "/portfolio",
    response_model=SuccessResponse[dict],
    summary="投资组合",
    description="获取聚合的投资组合视图，按资产分组展示持仓",
)
async def get_portfolio(
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    result = await finance_service.get_portfolio(db, family_id, current_user.id)
    return SuccessResponse(data=result)


@router.get(
    "/lookup/{ticker}",
    response_model=SuccessResponse[dict],
    summary="查询基金/股票信息",
    description="根据代码查询基金/股票的名称和当前价格",
)
async def lookup_instrument(
    ticker: str,
    current_user: CurrentUser = None,
    instrument_type: str = "fund",
):
    """Lookup fund/stock info by ticker symbol.

    instrument_type: fund (场外基金), etf (场内基金/ETF), stock (股票), crypto (加密货币)
    """
    from app.finance.providers.price_service import PriceProviderFactory

    # Determine provider based on instrument type and ticker format
    ticker = ticker.strip()

    # Chinese stock codes: 6 digits starting with 6 (Shanghai) or 0/3 (Shenzhen)
    is_chinese_stock = len(ticker) == 6 and ticker.isdigit() and ticker[0] in ('6', '0', '3')
    # Chinese fund codes: 6 digits starting with 1, 2 (场外基金)
    is_chinese_fund = len(ticker) == 6 and ticker.isdigit() and ticker[0] in ('1', '2')
    # Chinese ETF codes: 6 digits starting with 5 (场内基金)
    is_chinese_etf = len(ticker) == 6 and ticker.isdigit() and ticker[0] == '5'

    if instrument_type == "crypto":
        providers = ["coingecko"]
        currency = "USD"
    elif instrument_type == "stock":
        if is_chinese_stock:
            providers = ["china_stock"]
            currency = "CNY"
        else:
            # 美股等国际股票：Alpha Vantage 优先，新浪美股兜底
            providers = ["alphavantage", "china_stock_us"]
            currency = "USD"
    elif instrument_type == "etf" or is_chinese_etf:
        # 场内基金（ETF）使用股票API获取实时价格
        providers = ["china_stock"]
        currency = "CNY"
    elif instrument_type == "fund" or is_chinese_fund:
        # 场外基金获取最新净值
        providers = ["china_fund"]
        currency = "CNY"
    else:  # 国际基金/ETF
        providers = ["yahoo"]
        currency = "USD"

    result = await PriceProviderFactory.get_price_with_fallback(
        ticker, providers, currency
    )

    if result:
        return SuccessResponse(data={
            "ticker": ticker,
            "price": result["price"],
            "currency": result["currency"],
            "source": result["source"],
            "name": result.get("name"),
        })
    else:
        return SuccessResponse(data={
            "ticker": ticker,
            "price": None,
            "currency": currency,
            "source": None,
            "message": "未找到价格信息，请手动输入",
        })


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
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    days: int = 30,
):
    history = await finance_service.get_price_history(db, asset_id, days)
    return SuccessResponse(data=history)


# ============================================================
# FIRE Endpoints
# ============================================================

@router.get(
    "/fire/snapshot",
    response_model=SuccessResponse[dict],
    summary="FIRE快照",
    description="获取所有FIRE核心指标",
)
async def get_fire_snapshot(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    withdrawal_rate: float = 0.04,
    expected_return: float = 0.07,
    family_id: str = Depends(verify_family_member),
):
    from app.finance.fire_service import compute_fire_metrics
    metrics = await compute_fire_metrics(db, family_id, withdrawal_rate, expected_return)
    return SuccessResponse(data=metrics)


@router.get(
    "/fire/net-worth",
    response_model=SuccessResponse[dict],
    summary="净资产",
    description="获取净资产分解",
)
async def get_net_worth(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.finance.fire_service import compute_net_worth
    nw = await compute_net_worth(db, family_id)
    return SuccessResponse(data=nw)


@router.get(
    "/fire/allocation",
    response_model=SuccessResponse[dict],
    summary="资产配置",
    description="获取资产配置分析",
)
async def get_allocation(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.finance.fire_service import compute_asset_allocation
    allocation = await compute_asset_allocation(db, family_id)
    return SuccessResponse(data=allocation)


@router.get(
    "/fire/expenses",
    summary="支出分析",
    description="获取支出分析",
)
async def get_expense_analysis(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.finance.fire_service import compute_monthly_summary
    summary = await compute_monthly_summary(db, family_id)
    return SuccessResponse(data=summary)


@router.post(
    "/fire/monte-carlo",
    response_model=SuccessResponse[dict],
    summary="蒙特卡洛模拟",
    description="运行FIRE蒙特卡洛模拟",
)
async def run_monte_carlo(
        data: dict,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.finance.fire_service import compute_monthly_summary, compute_net_worth
    from app.finance.fire_service import run_monte_carlo as mc_sim

    nw = await compute_net_worth(db, family_id)
    summary = await compute_monthly_summary(db, family_id)

    # 计算默认 FIRE 数字
    annual_expense = summary.get("annual_expense", 0) or 0
    default_fire_number = annual_expense / 0.04 if annual_expense > 0 else 0

    # 获取用户输入或使用默认值
    fire_number = data.get("fire_number") or default_fire_number
    net_worth = nw.get("net_worth", 0) or 0
    annual_savings = (summary.get("monthly_income", 0) or 0) * (summary.get("savings_rate", 0) or 0) * 12

    result = mc_sim(
        net_worth=net_worth,
        annual_savings=annual_savings,
        fire_number=fire_number,
        expected_return=data.get("expected_return", 0.07) or 0.07,
        volatility=data.get("volatility", 0.15) or 0.15,
        simulations=data.get("simulations", 1000) or 1000,
    )
    return SuccessResponse(data=result)


@router.get(
    "/fire/passive-income",
    response_model=SuccessResponse[dict],
    summary="被动收入",
    description="获取被动收入分析",
)
async def get_passive_income(
        current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    from app.finance.fire_service import compute_passive_income
    income = await compute_passive_income(db, family_id)
    return SuccessResponse(data=income)
