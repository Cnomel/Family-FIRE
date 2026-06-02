"""Asset models: main table, financial info, lifecycle, relationships, and type-specific metadata."""

from datetime import datetime

from sqlalchemy import Column, Index, Text
from sqlalchemy.dialects.postgresql import JSON
from sqlmodel import Field

from app.common.models import TimestampMixin

# ============================================================
# Asset Main Table
# ============================================================

class Asset(TimestampMixin, table=True):
    """Core asset record. Every item tracked in the system."""
    __tablename__ = "assets"
    __table_args__ = (
        Index("idx_asset_family_status", "family_id", "status"),
        Index("idx_asset_family_nature", "family_id", "nature", "utility"),
    )

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="所属家庭ID")
    created_by: str = Field(max_length=36, description="创建者用户ID")
    name: str = Field(max_length=200, description="资产名称")
    description: str | None = Field(default=None, sa_column=Column(Text), description="描述")

    # Multi-dimensional classification
    nature: str = Field(max_length=20, description="性质: tangible/digital/financial/intangible/service")
    utility: str = Field(max_length=20, description="用途: productive/consumable/protective/speculative/lifestyle/essential")
    ownership: str = Field(max_length=20, description="持有: owned/mortgaged/leased/subscribed/licensed/custodied")
    liquidity: str = Field(max_length=20, description="流动性: instant/high/medium/low/fixed")

    # Tags for free-form categorization
    tags: dict | None = Field(default=None, sa_column=Column(JSON), description="标签列表")
    # Custom fields
    custom_fields: dict | None = Field(default=None, sa_column=Column(JSON), description="自定义字段")

    status: str = Field(default="active", max_length=20, description="状态: active/archived/disposed")


# ============================================================
# Asset Financial Info
# ============================================================

class AssetFinancial(TimestampMixin, table=True):
    """Financial information for an asset."""
    __tablename__ = "asset_financial"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    purchase_price: float = Field(default=0, description="购买价格")
    purchase_date: datetime | None = Field(default=None, description="购买日期")
    currency: str = Field(default="CNY", max_length=3, description="货币代码")
    current_value: float = Field(default=0, description="当前价值")
    last_valuation_date: datetime | None = Field(default=None, description="最后估值日期")
    total_cost_of_ownership: float = Field(default=0, description="总持有成本")
    monthly_carrying_cost: float = Field(default=0, description="月持有成本")


# ============================================================
# Asset Lifecycle
# ============================================================

class AssetLifecycle(TimestampMixin, table=True):
    """Lifecycle configuration for an asset."""
    __tablename__ = "asset_lifecycles"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    trajectory: str = Field(max_length=20, description="轨迹: appreciating/depreciating/consumable/expiring/volatile/stable")
    depreciation_config: dict | None = Field(default=None, sa_column=Column(JSON), description="折旧配置")
    expiration_config: dict | None = Field(default=None, sa_column=Column(JSON), description="到期配置")
    consumption_config: dict | None = Field(default=None, sa_column=Column(JSON), description="消耗配置")
    market_value_config: dict | None = Field(default=None, sa_column=Column(JSON), description="市场价值配置")
    appreciation_config: dict | None = Field(default=None, sa_column=Column(JSON), description="增值配置")


# ============================================================
# Asset Relationships
# ============================================================

class AssetRelationship(TimestampMixin, table=True):
    """Relationship between two assets."""
    __tablename__ = "asset_relationships"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    type: str = Field(max_length=20, description="关系类型: component_of/contains/requires/manages/provides/protects/funds/secures/accesses/substitutes")
    source_asset_id: str = Field(max_length=36, index=True, description="源资产ID")
    target_asset_id: str = Field(max_length=36, index=True, description="目标资产ID")
    is_optional: bool = Field(default=True, description="是否可选关系")
    lifecycle_linked: bool = Field(default=False, description="生命周期是否关联")
    extra_data: dict | None = Field(default=None, sa_column=Column(JSON), description="关系元数据")


# ============================================================
# Type-Specific Metadata Tables
# ============================================================

class AssetMetadataVehicle(TimestampMixin, table=True):
    """Vehicle-specific metadata."""
    __tablename__ = "asset_metadata_vehicle"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: car/motorcycle/bicycle/boat/rv")
    make: str = Field(max_length=50, description="品牌")
    model: str = Field(max_length=50, description="型号")
    year: int = Field(description="年份")
    vin: str | None = Field(default=None, max_length=17, description="车架号")
    license_plate: str | None = Field(default=None, max_length=20, description="车牌号")
    mileage: int | None = Field(default=None, description="里程数")
    fuel_type: str | None = Field(default=None, max_length=20, description="燃料类型")
    registration_expiry: datetime | None = Field(default=None, description="注册到期日")


class AssetMetadataRealEstate(TimestampMixin, table=True):
    """Real estate-specific metadata."""
    __tablename__ = "asset_metadata_real_estate"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=30, description="类型: primary_residence/rental/vacation/land/commercial")
    address: str = Field(max_length=500, description="地址")
    square_footage: float | None = Field(default=None, description="面积(平方米)")
    bedrooms: int | None = Field(default=None, description="卧室数")
    bathrooms: int | None = Field(default=None, description="卫生间数")
    year_built: int | None = Field(default=None, description="建造年份")
    property_tax_annual: float | None = Field(default=None, description="年房产税")
    hoa_monthly: float | None = Field(default=None, description="月物业费")
    rental_income: float | None = Field(default=None, description="租金收入")


class AssetMetadataElectronics(TimestampMixin, table=True):
    """Electronics-specific metadata."""
    __tablename__ = "asset_metadata_electronics"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: phone/laptop/tablet/tv/audio/gaming/camera/appliance/networking")
    brand: str = Field(max_length=50, description="品牌")
    model: str = Field(max_length=100, description="型号")
    serial_number: str | None = Field(default=None, max_length=100, description="序列号")
    specs: dict | None = Field(default=None, sa_column=Column(JSON), description="规格参数")
    warranty_expiration: datetime | None = Field(default=None, description="保修到期")
    os_firmware: str | None = Field(default=None, max_length=50, description="系统/固件版本")


class AssetMetadataFurniture(TimestampMixin, table=True):
    """Furniture-specific metadata."""
    __tablename__ = "asset_metadata_furniture"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: seating/table/storage/bed/lighting/decor/outdoor")
    brand: str | None = Field(default=None, max_length=50, description="品牌")
    material: str | None = Field(default=None, max_length=50, description="材质")
    room: str | None = Field(default=None, max_length=50, description="房间")
    dimensions: dict | None = Field(default=None, sa_column=Column(JSON), description="尺寸")
    condition: str | None = Field(default=None, max_length=20, description="状态: new/good/fair/poor")


class AssetMetadataInsurance(TimestampMixin, table=True):
    """Insurance policy-specific metadata."""
    __tablename__ = "asset_metadata_insurance"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: car/home/life/health/liability/disability/umbrella")
    provider: str = Field(max_length=100, description="保险公司")
    policy_number: str = Field(max_length=100, description="保单号")
    coverage_amount: float = Field(description="保额")
    deductible: float | None = Field(default=None, description="免赔额")
    premium: float = Field(description="保费")
    premium_frequency: str = Field(max_length=20, description="缴费频率: monthly/quarterly/annual")
    beneficiaries: dict | None = Field(default=None, sa_column=Column(JSON), description="受益人")
    covered_assets: dict | None = Field(default=None, sa_column=Column(JSON), description="覆盖资产ID列表")


class AssetMetadataFinancial(TimestampMixin, table=True):
    """Financial instrument-specific metadata."""
    __tablename__ = "asset_metadata_financial"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    instrument_type: str = Field(max_length=20, description="类型: stock/etf/mutual_fund/bond/crypto/reit/option/cd/money_market")
    ticker: str | None = Field(default=None, max_length=20, description="代码")
    exchange: str | None = Field(default=None, max_length=20, description="交易所")
    shares: float | None = Field(default=None, description="持有份额")
    average_cost_basis: float | None = Field(default=None, description="平均成本")
    current_price: float | None = Field(default=None, description="当前价格")
    price_currency: str = Field(default="CNY", max_length=3, description="价格货币")
    expense_ratio: float | None = Field(default=None, description="费率")
    dividend_yield: float | None = Field(default=None, description="股息率")
    expected_yield: float | None = Field(default=None, description="预期收益率(适用于存款/国债等稳定产品)")
    annual_income: float | None = Field(default=None, description="年收益金额(适用于理财产品等不确定收益率的产品)")
    tax_advantaged: bool = Field(default=False, description="是否税收优惠")
    account_type: str | None = Field(default=None, max_length=30, description="账户类型")
    price_source: dict | None = Field(default=None, sa_column=Column(JSON), description="价格源配置")
    transactions: dict | None = Field(default=None, sa_column=Column(JSON), description="交易记录")


class AssetMetadataSubscription(TimestampMixin, table=True):
    """Subscription service-specific metadata."""
    __tablename__ = "asset_metadata_subscription"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: streaming/software/cloud/news/fitness/meal_delivery/other")
    provider: str = Field(max_length=100, description="服务商")
    plan: str | None = Field(default=None, max_length=100, description="套餐")
    billing_cycle: str = Field(max_length=20, description="计费周期: monthly/quarterly/annual/lifetime")
    billing_amount: float = Field(description="计费金额")
    next_billing_date: datetime | None = Field(default=None, description="下次计费日期")
    auto_renew: bool = Field(default=True, description="是否自动续费")
    cancel_url: str | None = Field(default=None, max_length=500, description="取消链接")
    usage_level: str | None = Field(default=None, max_length=20, description="使用程度")
    annual_cost: float = Field(default=0, description="年化成本")


class AssetMetadataAccount(TimestampMixin, table=True):
    """Digital account-specific metadata."""
    __tablename__ = "asset_metadata_account"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: bank/brokerage/crypto_exchange/email/social/utility/government/other")
    provider: str = Field(max_length=100, description="服务商")
    username: str | None = Field(default=None, max_length=100, description="用户名")
    email: str | None = Field(default=None, max_length=255, description="邮箱")
    url: str | None = Field(default=None, max_length=500, description="URL")
    mfa_enabled: bool = Field(default=False, description="是否启用MFA")
    credential_vault_ref: str | None = Field(default=None, max_length=200, description="凭据库引用")
    account_number: str | None = Field(default=None, max_length=100, description="账号(脱敏)")


class AssetMetadataConsumable(TimestampMixin, table=True):
    """Consumable-specific metadata."""
    __tablename__ = "asset_metadata_consumable"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str = Field(max_length=36, unique=True, index=True, description="资产ID")
    type: str = Field(max_length=20, description="类型: hygiene/cleaning/food/office_supply/medical")
    brand: str | None = Field(default=None, max_length=50, description="品牌")
    initial_quantity: float = Field(description="初始数量")
    current_quantity: float = Field(description="当前数量")
    unit: str = Field(max_length=20, description="单位: rolls/bottles/ml/loads/pads")
    purchase_location: str | None = Field(default=None, max_length=200, description="购买地点")
    reorder_url: str | None = Field(default=None, max_length=500, description="补货链接")
    cost_per_unit: float | None = Field(default=None, description="单位成本")
    consumption_rate: float | None = Field(default=None, description="消耗率(单位/天)")
    reorder_threshold: float | None = Field(default=None, description="补货阈值")
