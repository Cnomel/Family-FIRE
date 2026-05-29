"""Asset management schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

# ============================================================
# Request Schemas
# ============================================================

class CreateAssetRequest(BaseModel):
    """Create a new asset with multi-dimensional classification."""
    name: str = Field(min_length=1, max_length=200, description="资产名称")
    description: str | None = Field(default=None, description="描述")

    # Multi-dimensional classification
    nature: str = Field(
        pattern="^(tangible|digital|financial|intangible|service)$",
        description="性质",
    )
    utility: str = Field(
        pattern="^(productive|consumable|protective|speculative|lifestyle|essential)$",
        description="用途",
    )
    ownership: str = Field(
        pattern="^(owned|mortgaged|leased|subscribed|licensed|custodied)$",
        description="持有方式",
    )
    liquidity: str = Field(
        pattern="^(instant|high|medium|low|fixed)$",
        description="流动性",
    )

    tags: list[str] | None = Field(default=None, description="标签列表")
    custom_fields: dict[str, Any] | None = Field(default=None, description="自定义字段")

    # Financial info
    purchase_price: float = Field(default=0, ge=0, description="购买价格")
    purchase_date: datetime | None = Field(default=None, description="购买日期")
    currency: str = Field(default="CNY", max_length=3, description="货币代码")

    # Type-specific metadata (JSON)
    metadata_type: str | None = Field(default=None, description="元数据类型")
    metadata: dict[str, Any] | None = Field(default=None, description="类型特定元数据")


class UpdateAssetRequest(BaseModel):
    """Update an existing asset."""
    name: str | None = Field(default=None, min_length=1, max_length=200, description="资产名称")
    description: str | None = Field(default=None, description="描述")
    nature: str | None = None
    utility: str | None = None
    ownership: str | None = None
    liquidity: str | None = None
    tags: list[str] | None = None
    custom_fields: dict[str, Any] | None = None
    status: str | None = Field(default=None, pattern="^(active|archived|disposed)$")


class AssetFilterParams(BaseModel):
    """Asset list filter parameters."""
    nature: str | None = None
    utility: str | None = None
    ownership: str | None = None
    liquidity: str | None = None
    tags: list[str] | None = None
    status: str = "active"
    search: str | None = None
    min_value: float | None = None
    max_value: float | None = None
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)


class BulkActionRequest(BaseModel):
    """Bulk action on multiple assets."""
    asset_ids: list[str] = Field(min_length=1, description="资产ID列表")
    action: str = Field(pattern="^(archive|delete|tag)$", description="操作类型")
    tag: str | None = Field(default=None, description="标签（action=tag时必填）")


class AddTagRequest(BaseModel):
    """Add a tag to an asset."""
    tag: str = Field(min_length=1, max_length=50, description="标签")


# ============================================================
# Response Schemas
# ============================================================

class AssetFinancialResponse(BaseModel):
    """Financial info response."""
    purchase_price: float = 0
    purchase_date: datetime | None = None
    currency: str = "CNY"
    current_value: float = 0
    last_valuation_date: datetime | None = None
    total_cost_of_ownership: float = 0
    monthly_carrying_cost: float = 0


class AssetResponse(BaseModel):
    """Asset summary response."""
    id: str
    name: str
    description: str | None = None
    nature: str
    utility: str
    ownership: str
    liquidity: str
    tags: list[str] | None = None
    status: str = "active"
    financial: AssetFinancialResponse | None = None
    created_at: datetime


class AssetDetailResponse(AssetResponse):
    """Detailed asset response with metadata."""
    custom_fields: dict[str, Any] | None = None
    metadata: dict[str, Any] | None = None
    metadata_type: str | None = None
    relationships: list[dict[str, Any]] = []
    documents: list[dict[str, Any]] = []


class AssetListResponse(BaseModel):
    """Paginated asset list."""
    assets: list[AssetResponse]
    total: int
    page: int
    page_size: int


class AssetStatsResponse(BaseModel):
    """Asset statistics by dimension."""
    total_count: int
    total_value: float
    by_nature: dict[str, dict[str, Any]]
    by_utility: dict[str, dict[str, Any]]
    by_ownership: dict[str, dict[str, Any]]
    by_liquidity: dict[str, dict[str, Any]]
