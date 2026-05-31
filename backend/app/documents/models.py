"""Document model for asset document management."""

from datetime import datetime

from sqlmodel import Field

from app.common.models import TimestampMixin


class DocumentFolder(TimestampMixin, table=True):
    """Folder for organizing documents."""
    __tablename__ = "document_folders"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    family_id: str = Field(max_length=36, index=True, description="所属家庭ID")
    name: str = Field(max_length=200, description="文件夹名称")
    parent_id: str | None = Field(default=None, max_length=36, index=True, description="父文件夹ID")
    created_by: str = Field(max_length=36, description="创建者用户ID")


class AssetDocument(TimestampMixin, table=True):
    """Document attached to an asset (receipt, warranty, manual, photo, etc.)."""
    __tablename__ = "asset_documents"

    id: str | None = Field(default=None, primary_key=True, max_length=36)
    asset_id: str | None = Field(default=None, max_length=36, index=True, description="关联资产ID")
    family_id: str = Field(max_length=36, index=True, description="所属家庭ID")
    folder_id: str | None = Field(default=None, max_length=36, index=True, description="所属文件夹ID")
    uploaded_by: str = Field(max_length=36, description="上传者用户ID")

    name: str = Field(max_length=200, description="文档名称", default="")
    type: str = Field(max_length=20, description="类型: receipt/warranty/policy/contract/manual/photo/appraisal")
    file_name: str = Field(max_length=255, description="文件名")
    file_path: str = Field(max_length=500, description="存储路径")
    mime_type: str = Field(max_length=100, description="MIME类型")
    file_size: int = Field(description="文件大小(字节)")
    thumbnail_path: str | None = Field(default=None, max_length=500, description="缩略图路径")

    expiry_date: datetime | None = Field(default=None, description="到期日期(保修书/保单等)")
    description: str | None = Field(default=None, max_length=500, description="描述")
