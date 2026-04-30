#!/usr/bin/env bash
# clever add-resource <slug> <ResourceName> [field:type ...]
#
# Erzeugt für eine bestehende audius-base Solution:
#   - SQLAlchemy Model (backend/src/models/<name>.py)
#   - Pydantic Schemas (backend/src/schemas/<name>.py)
#   - FastAPI CRUD Router (backend/src/api/<name_plural>.py)
#   - Alembic Migration (backend/alembic/versions/NNN_add_<name>.py)
#   - Next.js List Page (frontend/src/app/<name_plural>/page.tsx)
#   - Registriert Router in main.py
#   - Registriert Model in alembic/env.py
#
# Field types: str | text | int | float | bool | datetime | uuid
# Beispiel:
#   clever add-resource my-app Project name:str description:text done:bool
set -euo pipefail

SLUG="${1:-}"
RES="${2:-}"
shift 2 || true
FIELDS=("$@")

[[ -z "$SLUG" || -z "$RES" ]] && {
  echo "Usage: clever add-resource <slug> <ResourceName> [field:type ...]"
  echo "Field types: str text int float bool datetime uuid"
  exit 1
}

CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
SOLDIR="$CLEVER_HOME/solutions/$SLUG"
[[ ! -d "$SOLDIR" ]] && { echo "✗ Solution '$SLUG' fehlt"; exit 1; }

# Naming: ResourceName -> resource_name (snake_case), resources (plural)
NAME_PASCAL="$RES"
NAME_SNAKE=$(echo "$RES" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]')
NAME_PLURAL="${NAME_SNAKE}s"
NAME_KEBAB=$(echo "$NAME_SNAKE" | tr '_' '-')

cd "$SOLDIR"

GREEN=$'\033[0;32m'; NC=$'\033[0m'
ok() { echo "${GREEN}✓${NC} $1"; }

echo "→ add-resource: $NAME_PASCAL (snake=$NAME_SNAKE, plural=$NAME_PLURAL)"

# Field-Mapping zu Python types
field_to_py() {
  case "$1" in
    str)      echo "Mapped[str]" ;;
    text)     echo "Mapped[str]" ;;
    int)      echo "Mapped[int]" ;;
    float)    echo "Mapped[float]" ;;
    bool)     echo "Mapped[bool] = mapped_column(default=False)" ;;
    datetime) echo "Mapped[datetime]" ;;
    uuid)     echo "Mapped[UUID]" ;;
    *)        echo "Mapped[str]" ;;
  esac
}

field_to_pydantic() {
  case "$1" in
    str|text)  echo "str" ;;
    int)       echo "int" ;;
    float)     echo "float" ;;
    bool)      echo "bool = False" ;;
    datetime)  echo "datetime" ;;
    uuid)      echo "UUID" ;;
    *)         echo "str" ;;
  esac
}

field_to_alembic() {
  case "$1" in
    str)      echo "sa.String" ;;
    text)     echo "sa.Text" ;;
    int)      echo "sa.Integer" ;;
    float)    echo "sa.Float" ;;
    bool)     echo "sa.Boolean" ;;
    datetime) echo "sa.DateTime(timezone=True)" ;;
    uuid)     echo "sa.Uuid" ;;
    *)        echo "sa.String" ;;
  esac
}

# Model schreiben
mkdir -p backend/src/models
MODEL_FIELDS=""
for f in "${FIELDS[@]}"; do
  fname="${f%%:*}"; ftype="${f##*:}"
  PY_TYPE=$(field_to_py "$ftype")
  MODEL_FIELDS+="    $fname: $PY_TYPE
"
done

cat > "backend/src/models/${NAME_SNAKE}.py" <<EOF
from datetime import datetime, UTC
from uuid import UUID, uuid4
from sqlalchemy.orm import Mapped, mapped_column

from src.core.db import Base


class ${NAME_PASCAL}(Base):
    __tablename__ = "${NAME_PLURAL}"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
${MODEL_FIELDS}    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))
EOF
ok "Model: backend/src/models/${NAME_SNAKE}.py"

# Schemas
mkdir -p backend/src/schemas
SCHEMA_FIELDS=""
for f in "${FIELDS[@]}"; do
  fname="${f%%:*}"; ftype="${f##*:}"
  PY_TYPE=$(field_to_pydantic "$ftype")
  SCHEMA_FIELDS+="    $fname: $PY_TYPE
"
done

cat > "backend/src/schemas/${NAME_SNAKE}.py" <<EOF
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, ConfigDict


class ${NAME_PASCAL}Create(BaseModel):
${SCHEMA_FIELDS}

class ${NAME_PASCAL}Update(BaseModel):
$(for f in "${FIELDS[@]}"; do fname="${f%%:*}"; ftype="${f##*:}"; PY=$(field_to_pydantic "$ftype" | sed 's/ = .*//'); echo "    $fname: $PY | None = None"; done)


class ${NAME_PASCAL}Read(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
${SCHEMA_FIELDS}    created_at: datetime
EOF
ok "Schemas: backend/src/schemas/${NAME_SNAKE}.py"

# Router (CRUD)
cat > "backend/src/api/${NAME_PLURAL}.py" <<EOF
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.auth import get_current_user
from src.core.db import get_db
from src.models.${NAME_SNAKE} import ${NAME_PASCAL}
from src.schemas.${NAME_SNAKE} import ${NAME_PASCAL}Create, ${NAME_PASCAL}Update, ${NAME_PASCAL}Read

router = APIRouter(prefix="/api/v1/${NAME_PLURAL}", tags=["${NAME_PLURAL}"])


@router.get("", response_model=list[${NAME_PASCAL}Read])
async def list_${NAME_PLURAL}(
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    result = await db.execute(select(${NAME_PASCAL}))
    return list(result.scalars())


@router.post("", response_model=${NAME_PASCAL}Read, status_code=201)
async def create_${NAME_SNAKE}(
    data: ${NAME_PASCAL}Create,
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = ${NAME_PASCAL}(**data.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@router.get("/{item_id}", response_model=${NAME_PASCAL}Read)
async def get_${NAME_SNAKE}(
    item_id: UUID,
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await db.get(${NAME_PASCAL}, item_id)
    if not item:
        raise HTTPException(404)
    return item


@router.patch("/{item_id}", response_model=${NAME_PASCAL}Read)
async def update_${NAME_SNAKE}(
    item_id: UUID,
    data: ${NAME_PASCAL}Update,
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await db.get(${NAME_PASCAL}, item_id)
    if not item:
        raise HTTPException(404)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    await db.commit()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_${NAME_SNAKE}(
    item_id: UUID,
    _user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    item = await db.get(${NAME_PASCAL}, item_id)
    if not item:
        raise HTTPException(404)
    await db.delete(item)
    await db.commit()
EOF
ok "Router: backend/src/api/${NAME_PLURAL}.py"

# Migration
NEXT_REV=$(printf "%03d" $(($(ls backend/alembic/versions/*.py 2>/dev/null | wc -l | tr -d ' ') + 1)))
PREV_REV=$(printf "%03d" $((10#$NEXT_REV - 1)))
ALEMBIC_FIELDS=""
for f in "${FIELDS[@]}"; do
  fname="${f%%:*}"; ftype="${f##*:}"
  ALEMBIC_TYPE=$(field_to_alembic "$ftype")
  ALEMBIC_FIELDS+="        sa.Column(\"$fname\", $ALEMBIC_TYPE, nullable=False),
"
done

cat > "backend/alembic/versions/${NEXT_REV}_add_${NAME_SNAKE}.py" <<EOF
"""add ${NAME_SNAKE}

Revision ID: ${NEXT_REV}
Revises: ${PREV_REV}
"""
from alembic import op
import sqlalchemy as sa

revision = "${NEXT_REV}"
down_revision = "${PREV_REV}"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "${NAME_PLURAL}",
        sa.Column("id", sa.Uuid, primary_key=True),
${ALEMBIC_FIELDS}        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade():
    op.drop_table("${NAME_PLURAL}")
EOF
ok "Migration: backend/alembic/versions/${NEXT_REV}_add_${NAME_SNAKE}.py"

# main.py: include_router
if ! grep -q "from src.api import.*${NAME_PLURAL}" backend/src/main.py; then
  python3 - <<PY
import re
p = "backend/src/main.py"
content = open(p).read()
# Import erweitern
content = re.sub(
    r"(from src\.api import )([^\n]+)",
    lambda m: m.group(0) if "${NAME_PLURAL}" in m.group(2) else f"{m.group(1)}{m.group(2).rstrip()}, ${NAME_PLURAL}",
    content, count=1
)
# include_router hinzufügen vor health-Endpoint
if "${NAME_PLURAL}.router" not in content:
    content = content.replace(
        "app.include_router(items.router)",
        "app.include_router(items.router)\napp.include_router(${NAME_PLURAL}.router)"
    )
open(p, "w").write(content)
print("✓ main.py aktualisiert")
PY
else
  echo "  main.py: schon registriert"
fi

# alembic/env.py: Model importieren für autogenerate
if ! grep -q "from src.api import.*${NAME_PLURAL}" backend/alembic/env.py 2>/dev/null \
   && ! grep -q "from src.models import.*${NAME_SNAKE}" backend/alembic/env.py 2>/dev/null; then
  sed -i.bak "/^from src.api import items/a\\
from src.api import ${NAME_PLURAL}  # noqa: F401" backend/alembic/env.py
  rm -f backend/alembic/env.py.bak
  ok "alembic/env.py aktualisiert"
fi

# Frontend Page
mkdir -p "frontend/src/app/${NAME_PLURAL}"
LIST_FIELDS_TS=""
for f in "${FIELDS[@]}"; do
  fname="${f%%:*}"
  LIST_FIELDS_TS+="            <th className=\"px-4 py-2 text-left text-sm font-medium text-gray-700\">$fname</th>
"
done
ROW_FIELDS_TS=""
for f in "${FIELDS[@]}"; do
  fname="${f%%:*}"
  ROW_FIELDS_TS+="              <td className=\"px-4 py-2 text-sm\">{String(item.$fname ?? '')}</td>
"
done

cat > "frontend/src/app/${NAME_PLURAL}/page.tsx" <<EOF
async function getItems() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://backend:8000';
  try {
    const res = await fetch(\`\${apiUrl}/api/v1/${NAME_PLURAL}\`, { cache: 'no-store' });
    return res.ok ? await res.json() : [];
  } catch { return []; }
}

export default async function ${NAME_PASCAL}sPage() {
  const items = await getItems();

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-5xl mx-auto">
        <h1 className="text-3xl font-bold text-audius-navy mb-6">${NAME_PASCAL}s</h1>
        <div className="bg-white rounded-2xl shadow overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
${LIST_FIELDS_TS}              </tr>
            </thead>
            <tbody>
              {items.map((item: any) => (
                <tr key={item.id} className="border-t hover:bg-gray-50">
${ROW_FIELDS_TS}                </tr>
              ))}
              {items.length === 0 && (
                <tr><td colSpan={${#FIELDS[@]}} className="px-4 py-12 text-center text-gray-400">Keine Einträge</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  );
}
EOF
ok "Frontend: frontend/src/app/${NAME_PLURAL}/page.tsx"

echo
echo "→ Done. Apply changes:"
echo "    cd $SOLDIR && make rebuild"
echo "→ Then:"
echo "    open http://localhost:\$(grep PORT_FRONTEND .env | cut -d= -f2)/${NAME_PLURAL}"
echo "    open http://localhost:\$(grep PORT_BACKEND .env | cut -d= -f2)/docs"
