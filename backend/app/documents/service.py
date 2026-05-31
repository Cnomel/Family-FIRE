"""Document management service with MinIO storage."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.exceptions import NotFoundError, PermissionDeniedError, ValidationError
from app.common.logging import get_logger
from app.config import get_settings
from app.documents.models import AssetDocument
from app.documents.schemas import UploadResponse
from app.families.models import FamilyMember

logger = get_logger("document_service")
settings = get_settings()

ALLOWED_TYPES = {
    "application/pdf": "pdf",
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/heic": "heic",
    "image/heif": "heif",
}
MAX_FILE_SIZE = 20 * 1024 * 1024  # 20MB


async def _verify_family_member(db: AsyncSession, family_id: str, user_id: str) -> None:
    stmt = select(FamilyMember).where(
        FamilyMember.family_id == family_id,
        FamilyMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if not result.scalar_one_or_none():
        raise PermissionDeniedError("访问此家庭的文档")


def _get_minio_client():
    """Get MinIO client."""
    from minio import Minio
    return Minio(
        settings.MINIO_ENDPOINT,
        access_key=settings.MINIO_ACCESS_KEY,
        secret_key=settings.MINIO_SECRET_KEY,
        secure=settings.MINIO_SECURE,
    )


def _ensure_bucket(client, bucket_name: str) -> None:
    """Ensure bucket exists."""
    if not client.bucket_exists(bucket_name):
        client.make_bucket(bucket_name)


async def upload_document(
    db: AsyncSession,
    family_id: str,
    user_id: str,
    file_name: str,
    file_content: bytes,
    mime_type: str,
    doc_type: str,
    name: str = "",
    asset_id: str | None = None,
    expiry_date: datetime | None = None,
    description: str | None = None,
) -> UploadResponse:
    """Upload a document to MinIO and record metadata."""
    await _verify_family_member(db, family_id, user_id)

    # Validate file type
    if mime_type not in ALLOWED_TYPES:
        raise ValidationError(f"不支持的文件类型: {mime_type}。支持: PDF, JPG, PNG, HEIC")

    # Validate file size
    if len(file_content) > MAX_FILE_SIZE:
        raise ValidationError(f"文件大小超过限制(最大{MAX_FILE_SIZE // 1024 // 1024}MB)")

    doc_id = str(uuid.uuid4())
    file_path = f"{family_id}/{asset_id or 'general'}/{doc_id}/{file_name}"

    # Upload to MinIO
    try:
        client = _get_minio_client()
        _ensure_bucket(client, settings.MINIO_BUCKET_DOCUMENTS)

        import io
        client.put_object(
            settings.MINIO_BUCKET_DOCUMENTS,
            file_path,
            io.BytesIO(file_content),
            length=len(file_content),
            content_type=mime_type,
        )
        logger.info("document_uploaded", doc_id=doc_id, file_path=file_path)
    except Exception as e:
        logger.error("minio_upload_failed", error=str(e))
        raise ValidationError("文件上传失败，请重试") from e

    # Generate thumbnail for images
    thumbnail_path = None
    if mime_type.startswith("image/"):
        thumbnail_path = await _generate_thumbnail(client, file_path, file_content, doc_id)

    # Save metadata
    doc = AssetDocument(
        id=doc_id,
        asset_id=asset_id,
        family_id=family_id,
        uploaded_by=user_id,
        name=name or file_name,
        type=doc_type,
        file_name=file_name,
        file_path=file_path,
        mime_type=mime_type,
        file_size=len(file_content),
        thumbnail_path=thumbnail_path,
        expiry_date=expiry_date,
        description=description,
    )
    db.add(doc)
    await db.flush()

    # Generate preview URL
    preview_url = _generate_presigned_url(client, file_path)

    return UploadResponse(
        id=doc_id,
        file_name=file_name,
        file_size=len(file_content),
        mime_type=mime_type,
        preview_url=preview_url,
    )


async def _generate_thumbnail(client, file_path: str, content: bytes, doc_id: str) -> str | None:
    """Generate thumbnail for image documents."""
    try:
        import io

        from PIL import Image

        img = Image.open(io.BytesIO(content))
        img.thumbnail((300, 300))

        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        buf.seek(0)

        thumb_path = f"thumbnails/{doc_id}.jpg"
        client.put_object(
            settings.MINIO_BUCKET_DOCUMENTS,
            thumb_path,
            buf,
            length=buf.getbuffer().nbytes,
            content_type="image/jpeg",
        )
        return thumb_path
    except Exception as e:
        logger.warning("thumbnail_generation_failed", error=str(e))
        return None


def _generate_presigned_url(client, file_path: str, expires_hours: int = 1) -> str:
    """Generate presigned URL for document access."""
    from datetime import timedelta
    try:
        return client.presigned_get_object(
            settings.MINIO_BUCKET_DOCUMENTS,
            file_path,
            expires=timedelta(hours=expires_hours),
        )
    except Exception:
        return ""


async def get_document(
    db: AsyncSession, doc_id: str, family_id: str, user_id: str
) -> dict[str, Any]:
    """Get document info with preview URL."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(AssetDocument).where(
        AssetDocument.id == doc_id,
        AssetDocument.family_id == family_id,
    )
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()

    if not doc:
        raise NotFoundError("文档", doc_id)

    client = _get_minio_client()
    preview_url = _generate_presigned_url(client, doc.file_path)

    return {
        "id": doc.id,
        "asset_id": doc.asset_id,
        "family_id": doc.family_id,
        "type": doc.type,
        "file_name": doc.file_name,
        "mime_type": doc.mime_type,
        "file_size": doc.file_size,
        "expiry_date": doc.expiry_date.isoformat() if doc.expiry_date else None,
        "description": doc.description,
        "preview_url": preview_url,
        "created_at": doc.created_at.isoformat(),
    }


async def list_asset_documents(
    db: AsyncSession, asset_id: str, family_id: str, user_id: str
) -> list[dict[str, Any]]:
    """List all documents for an asset."""
    await _verify_family_member(db, family_id, user_id)

    stmt = (
        select(AssetDocument)
        .where(AssetDocument.asset_id == asset_id, AssetDocument.family_id == family_id)
        .order_by(AssetDocument.created_at.desc())
    )
    result = await db.execute(stmt)
    docs = result.scalars().all()

    return [
        {
            "id": d.id,
            "type": d.type,
            "file_name": d.file_name,
            "mime_type": d.mime_type,
            "file_size": d.file_size,
            "expiry_date": d.expiry_date.isoformat() if d.expiry_date else None,
            "created_at": d.created_at.isoformat(),
        }
        for d in docs
    ]


async def delete_document(
    db: AsyncSession, doc_id: str, family_id: str, user_id: str
) -> None:
    """Delete a document from storage and database."""
    await _verify_family_member(db, family_id, user_id)

    stmt = select(AssetDocument).where(
        AssetDocument.id == doc_id,
        AssetDocument.family_id == family_id,
    )
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()

    if not doc:
        raise NotFoundError("文档", doc_id)

    # Delete from MinIO
    try:
        client = _get_minio_client()
        client.remove_object(settings.MINIO_BUCKET_DOCUMENTS, doc.file_path)
        if doc.thumbnail_path:
            client.remove_object(settings.MINIO_BUCKET_DOCUMENTS, doc.thumbnail_path)
    except Exception as e:
        logger.warning("minio_delete_failed", error=str(e))

    await db.delete(doc)
    await db.flush()
    logger.info("document_deleted", doc_id=doc_id)
