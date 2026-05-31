"""Document management API router."""

from datetime import datetime

from app.families.dependencies import verify_family_member_query as verify_family_member
from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser
from app.common.schemas import MessageResponse, SuccessResponse
from app.database import get_db
from app.documents import service as doc_service

router = APIRouter()


# ============================================================
# Folder Endpoints
# ============================================================

@router.post(
    "/folders",
    response_model=SuccessResponse[dict],
    status_code=201,
    summary="创建文件夹",
)
async def create_folder(
    name: str = Form(..., description="文件夹名称"),
    parent_id: str | None = Form(default=None, description="父文件夹ID"),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    result = await doc_service.create_folder(db, family_id, current_user.id, name, parent_id)
    return SuccessResponse(data=result, message="文件夹创建成功")


@router.get(
    "/folders",
    response_model=SuccessResponse[list],
    summary="文件夹列表",
    description="获取当前家庭的所有文件夹",
)
async def list_folders(
    family_id: str = Depends(verify_family_member),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
):
    folders = await doc_service.list_folders(db, family_id, current_user.id)
    return SuccessResponse(data=folders)


@router.delete(
    "/folders/{folder_id}",
    response_model=MessageResponse,
    summary="删除文件夹",
)
async def delete_folder(
    folder_id: str,
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await doc_service.delete_folder(db, folder_id, family_id, current_user.id)
    return MessageResponse(message="文件夹已删除")


# ============================================================
# Document Endpoints
# ============================================================

@router.post(
    "/upload",
    response_model=SuccessResponse[dict],
    status_code=201,
    summary="上传文档",
    description="上传文档到MinIO（支持PDF、JPG、PNG、HEIC，最大20MB）",
)
async def upload_document(
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
    file: UploadFile = File(..., description="文件"),
    type: str = Form(description="文档类型: receipt/warranty/policy/contract/manual/photo/appraisal"),
    name: str = Form(default="", description="文档名称"),
    folder_id: str | None = Form(default=None, description="文件夹ID"),
    asset_id: str | None = Form(default=None, description="关联资产ID"),
    expiry_date: str | None = Form(default=None, description="到期日期(ISO)"),
    description: str | None = Form(default=None, description="描述"),
):
    content = await file.read()
    exp_date = datetime.fromisoformat(expiry_date) if expiry_date else None

    result = await doc_service.upload_document(
        db=db,
        family_id=family_id,
        user_id=current_user.id,
        file_name=file.filename or "unknown",
        file_content=content,
        mime_type=file.content_type or "application/octet-stream",
        doc_type=type,
        name=name,
        folder_id=folder_id,
        asset_id=asset_id,
        expiry_date=exp_date,
        description=description,
    )
    return SuccessResponse(data=result.model_dump(), message="文档上传成功")


@router.get(
    "/",
    response_model=SuccessResponse[dict],
    summary="文档列表",
    description="获取当前家庭的文档和文件夹",
)
async def list_documents(
    folder_id: str | None = None,
    family_id: str = Depends(verify_family_member),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
):
    result = await doc_service.list_family_documents(db, family_id, current_user.id, folder_id)
    return SuccessResponse(data=result)


@router.get(
    "/{doc_id}",
    response_model=SuccessResponse[dict],
    summary="文档详情",
    description="获取文档信息和预览URL",
)
async def get_document(
    doc_id: str,
    family_id: str = Depends(verify_family_member),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
):
    doc = await doc_service.get_document(db, doc_id, family_id, current_user.id)
    return SuccessResponse(data=doc)


@router.get(
    "/asset/{asset_id}",
    response_model=SuccessResponse[list],
    summary="资产文档",
    description="获取资产关联的所有文档",
)
async def list_asset_documents(
    asset_id: str,
    family_id: str = Depends(verify_family_member),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
):
    docs = await doc_service.list_asset_documents(db, asset_id, family_id, current_user.id)
    return SuccessResponse(data=docs)


@router.put(
    "/{doc_id}/move",
    response_model=MessageResponse,
    summary="移动文档",
    description="移动文档到指定文件夹",
)
async def move_document(
    doc_id: str,
    folder_id: str | None = Form(default=None, description="目标文件夹ID，null表示移到根目录"),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
    family_id: str = Depends(verify_family_member),
):
    await doc_service.move_document(db, doc_id, family_id, current_user.id, folder_id)
    return MessageResponse(message="文档已移动")


@router.delete(
    "/{doc_id}",
    response_model=MessageResponse,
    summary="删除文档",
    description="从存储和数据库中删除文档",
)
async def delete_document(
    doc_id: str,
    family_id: str = Depends(verify_family_member),
    current_user: CurrentUser = None,
    db: AsyncSession = Depends(get_db),
):
    await doc_service.delete_document(db, doc_id, family_id, current_user.id)
    return MessageResponse(message="文档已删除")
