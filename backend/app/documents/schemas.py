"""Document management schemas."""

from datetime import datetime

from pydantic import BaseModel


class DocumentResponse(BaseModel):
    """Document information."""
    id: str
    asset_id: str | None = None
    family_id: str
    type: str
    file_name: str
    file_path: str
    mime_type: str
    file_size: int
    thumbnail_path: str | None = None
    expiry_date: datetime | None = None
    description: str | None = None
    created_at: datetime


class DocumentListResponse(BaseModel):
    """Document list."""
    documents: list[DocumentResponse]
    total: int


class UploadResponse(BaseModel):
    """Upload result."""
    id: str
    file_name: str
    file_size: int
    mime_type: str
    preview_url: str
