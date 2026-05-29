"""Common utility functions."""

from datetime import UTC, datetime


def utcnow() -> datetime:
    """Get current UTC time as naive datetime (for PostgreSQL TIMESTAMP WITHOUT TIME ZONE).

    asyncpg requires naive datetimes for TIMESTAMP WITHOUT TIME ZONE columns.
    """
    return datetime.now(UTC).replace(tzinfo=None)
