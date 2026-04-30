# Recipe: Standard CRUD (Backend + Frontend)

Komplettes Beispiel: Resource „Item" mit `Create / Read / Update / Delete`.

## Backend (FastAPI + SQLAlchemy)

### 1. Model (`src/models/item.py`)

```python
from datetime import UTC, datetime
from uuid import UUID, uuid4
from sqlalchemy.orm import Mapped, mapped_column
from src.models.base import Base

class Item(Base):
    __tablename__ = "items"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(index=True)
    description: Mapped[str | None] = mapped_column(default=None)
    user_id: Mapped[UUID] = mapped_column(index=True)  # Owner
    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))
```

### 2. Schemas (`src/schemas/item.py`)

```python
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, ConfigDict

class ItemCreate(BaseModel):
    name: str
    description: str | None = None

class ItemUpdate(BaseModel):
    name: str | None = None
    description: str | None = None

class ItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    description: str | None
    created_at: datetime
    updated_at: datetime
```

### 3. Service (`src/services/item_service.py`)

```python
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.item import Item
from src.schemas.item import ItemCreate, ItemUpdate

async def list_items(db: AsyncSession, user_id: UUID) -> list[Item]:
    result = await db.execute(select(Item).where(Item.user_id == user_id))
    return list(result.scalars())

async def get_item(db: AsyncSession, item_id: UUID, user_id: UUID) -> Item | None:
    result = await db.execute(
        select(Item).where(Item.id == item_id, Item.user_id == user_id)
    )
    return result.scalar_one_or_none()

async def create_item(db: AsyncSession, data: ItemCreate, user_id: UUID) -> Item:
    item = Item(**data.model_dump(), user_id=user_id)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item

async def update_item(db: AsyncSession, item: Item, data: ItemUpdate) -> Item:
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    await db.commit()
    await db.refresh(item)
    return item

async def delete_item(db: AsyncSession, item: Item) -> None:
    await db.delete(item)
    await db.commit()
```

### 4. API (`src/api/items.py`)

```python
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from src.api.deps import get_current_user, get_db
from src.schemas.item import ItemCreate, ItemUpdate, ItemRead
from src.services import item_service

router = APIRouter(prefix="/api/v1/items", tags=["items"])

@router.get("", response_model=list[ItemRead])
async def list_items(user = Depends(get_current_user), db = Depends(get_db)):
    return await item_service.list_items(db, user.id)

@router.post("", response_model=ItemRead, status_code=201)
async def create_item(data: ItemCreate, user = Depends(get_current_user), db = Depends(get_db)):
    return await item_service.create_item(db, data, user.id)

@router.get("/{item_id}", response_model=ItemRead)
async def get_item(item_id: UUID, user = Depends(get_current_user), db = Depends(get_db)):
    item = await item_service.get_item(db, item_id, user.id)
    if not item:
        raise HTTPException(404)
    return item

@router.patch("/{item_id}", response_model=ItemRead)
async def update_item(item_id: UUID, data: ItemUpdate, user = Depends(get_current_user), db = Depends(get_db)):
    item = await item_service.get_item(db, item_id, user.id)
    if not item:
        raise HTTPException(404)
    return await item_service.update_item(db, item, data)

@router.delete("/{item_id}", status_code=204)
async def delete_item(item_id: UUID, user = Depends(get_current_user), db = Depends(get_db)):
    item = await item_service.get_item(db, item_id, user.id)
    if not item:
        raise HTTPException(404)
    await item_service.delete_item(db, item)
```

### 5. Migration

```bash
make db-migrate m="add items table"
make db-upgrade
```

## Frontend (Next.js + TanStack Query)

### 1. Types & API Client (`src/lib/api/items.ts`)

```ts
import { apiFetch } from '@/lib/api';

export interface Item {
  id: string;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface ItemCreate {
  name: string;
  description?: string;
}

export const itemsApi = {
  list: () => apiFetch<Item[]>('/api/v1/items'),
  get: (id: string) => apiFetch<Item>(`/api/v1/items/${id}`),
  create: (data: ItemCreate) =>
    apiFetch<Item>('/api/v1/items', { method: 'POST', body: JSON.stringify(data) }),
  update: (id: string, data: Partial<ItemCreate>) =>
    apiFetch<Item>(`/api/v1/items/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: (id: string) =>
    apiFetch<void>(`/api/v1/items/${id}`, { method: 'DELETE' }),
};
```

### 2. Hooks (`src/hooks/use-items.ts`)

```ts
'use client';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { itemsApi, type ItemCreate } from '@/lib/api/items';

export const useItems = () =>
  useQuery({ queryKey: ['items'], queryFn: itemsApi.list });

export const useCreateItem = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: ItemCreate) => itemsApi.create(data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['items'] }),
  });
};
```

### 3. Page (`src/app/(auth)/items/page.tsx`)

```tsx
'use client';
import { Button, Card, DataTable, EmptyState } from '@audiusintelligence/ui';
import { Plus } from 'lucide-react';
import { useItems } from '@/hooks/use-items';

export default function ItemsPage() {
  const { data: items = [], isLoading } = useItems();

  return (
    <div className="max-w-7xl mx-auto px-4 py-8 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold font-montserrat">Items</h1>
        <Button variant="primary"><Plus className="w-5 h-5" /> Neu</Button>
      </div>

      <Card>
        {isLoading ? 'Lädt…' : items.length === 0 ? (
          <EmptyState message="Noch keine Items" />
        ) : (
          <DataTable
            data={items}
            columns={[
              { key: 'name', label: 'Name', sortable: true },
              { key: 'created_at', label: 'Erstellt', format: 'date' },
            ]}
          />
        )}
      </Card>
    </div>
  );
}
```

## Tests

```python
# tests/unit/test_item_service.py
async def test_create_item_persists_to_db(db, user):
    item = await create_item(db, ItemCreate(name="Test"), user.id)
    assert item.id is not None
    assert item.name == "Test"
```

Das ist die Vorlage für jede neue Resource. **Konsequent so machen.**
