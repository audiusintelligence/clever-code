"""Sample CRUD - extend or replace for your domain."""
from datetime import datetime, UTC
from uuid import UUID, uuid4
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column

from src.core.auth import get_current_user
from src.core.db import Base, get_db


class Item(Base):
    __tablename__ = "items"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    title: Mapped[str]
    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))


class ItemCreate(BaseModel):
    title: str


class ItemRead(BaseModel):
    id: UUID
    title: str
    created_at: datetime

    model_config = {"from_attributes": True}


router = APIRouter(prefix="/api/v1/items", tags=["items"])


@router.get("", response_model=list[ItemRead])
async def list_items(
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(select(Item))
    return list(result.scalars())


@router.post("", response_model=ItemRead, status_code=201)
async def create_item(
    data: ItemCreate,
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = Item(**data.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_item(
    item_id: UUID,
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await db.get(Item, item_id)
    if not item:
        raise HTTPException(404)
    await db.delete(item)
    await db.commit()
