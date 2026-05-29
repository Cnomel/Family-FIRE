"""Common Pydantic schemas for API responses."""

from typing import Any, Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class SuccessResponse(BaseModel, Generic[T]):
    """Standard success response wrapper."""
    model_config = {"arbitrary_types_allowed": True}

    success: bool = True
    data: T
    message: str = ""


class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated list response."""
    model_config = {"arbitrary_types_allowed": True}

    success: bool = True
    data: list[T]
    total: int
    page: int = 1
    page_size: int = 20
    total_pages: int = 0


class ErrorResponse(BaseModel):
    """Standard error response."""
    success: bool = False
    error: dict[str, Any]


class PaginationParams(BaseModel):
    """Pagination query parameters."""
    page: int = Field(default=1, ge=1, description="页码")
    page_size: int = Field(default=20, ge=1, le=100, description="每页数量")

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


class MessageResponse(BaseModel):
    """Simple message response."""
    success: bool = True
    message: str


class IDResponse(BaseModel):
    """Response with just an ID."""
    success: bool = True
    id: str
    message: str = ""
