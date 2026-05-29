"""Base SQLModel models with common fields and mixins."""

from datetime import UTC, datetime

from sqlmodel import Field, SQLModel


def utcnow() -> datetime:
    """Get current UTC time (naive, for PostgreSQL compatibility)."""
    return datetime.utcnow().replace(tzinfo=None)


class TimestampMixin(SQLModel):
    """Mixin that adds created_at and updated_at timestamps."""
    created_at: datetime = Field(default_factory=utcnow, nullable=False)
    updated_at: datetime = Field(default_factory=utcnow, nullable=False)


class SoftDeleteMixin(SQLModel):
    """Mixin that adds soft delete capability."""
    deleted_at: datetime | None = Field(default=None, nullable=True)
    is_deleted: bool = Field(default=False, nullable=False)


class IDMixin(SQLModel):
    """Mixin that adds a UUID primary key."""
    id: str | None = Field(default=None, primary_key=True, max_length=36)
