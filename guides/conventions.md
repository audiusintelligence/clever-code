# Coding Conventions

Verbindlicher Code-Style für alle Clever Solutions.

## Python (FastAPI Backend)

### Tooling
- **Format/Lint:** Ruff (`line-length = 88`)
- **Type Check:** mypy strict
- **Test:** pytest (in `tests/unit/`, `tests/integration/`)

```toml
# pyproject.toml
[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "RUF"]
```

### Imports
**Immer absolute Imports**, nie relative:
```python
# ✓ Richtig
from src.models.user import User
from src.api.deps import get_db

# ✗ Falsch
from .models import User
from ..api import deps
```

### Async First
Alle Datenbank-Operationen sind async:
```python
async def get_invoices(db: AsyncSession) -> list[Invoice]:
    result = await db.execute(select(Invoice))
    return list(result.scalars())
```

### Type Hints (Pflicht überall)
```python
# ✓ Richtig
async def create_invoice(
    data: InvoiceCreate,
    db: AsyncSession = Depends(get_db),
) -> InvoiceRead:
    ...

# ✗ Falsch
async def create_invoice(data, db):
    ...
```

### Datetime
```python
from datetime import UTC, datetime

now = datetime.now(UTC)  # immer mit Timezone
```

### Logging
```python
import logging
logger = logging.getLogger(__name__)  # immer modul-lokal

logger.info("Importing %d records", count)  # %s, nicht f-strings für log args
logger.exception("Import failed")  # in except-Blöcken
```

### Naming
| Was | Format | Beispiel |
|-----|--------|----------|
| Datei | snake_case | `invoice_service.py` |
| Funktion | snake_case | `create_invoice()` |
| Klasse | PascalCase | `InvoiceService` |
| Service-File | `<name>_service.py` | `import_service.py` |
| Connector-File | `<name>_connector.py` | `sap_connector.py` |
| Konstanten | UPPER_SNAKE | `MAX_RETRIES = 3` |

### Error Handling
```python
# ✓ Spezifische Exceptions zuerst, dann generisch
try:
    result = await fetch_data()
except AuthenticationError:
    raise HTTPException(status_code=401, detail="...")
except FetchError as e:
    logger.exception("Fetch failed")
    raise HTTPException(status_code=502, detail=str(e))
except Exception:
    logger.exception("Unexpected error")
    raise HTTPException(status_code=500)
```

### Tests
- Datei: `test_<modul>.py`
- Funktion: `test_<was>_<wann>_<erwartung>()`
- Mocks: über `pytest-mock` oder `unittest.mock`
- Fixtures: in `conftest.py`

```python
async def test_create_invoice_with_valid_data_returns_201(
    client: AsyncClient, db: AsyncSession
):
    response = await client.post("/api/v1/invoices", json={...})
    assert response.status_code == 201
```

## TypeScript / React (Next.js Frontend)

### Tooling
- **Format:** Prettier (default config)
- **Lint:** ESLint (next/core-web-vitals)
- **Type Check:** tsc strict

### Naming
| Was | Format | Beispiel |
|-----|--------|----------|
| Component-Datei | PascalCase | `InvoiceCard.tsx` |
| Hook-Datei | camelCase, `use` prefix | `useInvoices.ts` |
| API-Module | kebab-case | `api/invoices-api.ts` |
| Types-Datei | kebab-case | `types/invoice.ts` |
| Page-Folder | kebab-case | `app/invoices/page.tsx` |
| Type/Interface | PascalCase | `interface Invoice {}` |
| Component | PascalCase | `<InvoiceCard />` |
| Hook | camelCase, `use` prefix | `useInvoices()` |
| Funktion | camelCase | `formatDate()` |
| Konstanten | UPPER_SNAKE | `MAX_FILE_SIZE` |

### Components

**Server Components by default**, `'use client'` nur wenn nötig:
```tsx
// app/invoices/page.tsx (Server Component)
export default async function InvoicesPage() {
  const invoices = await fetchInvoices();
  return <InvoiceList invoices={invoices} />;
}

// components/invoice-list.tsx (Client wenn Interaktivität)
'use client';
export function InvoiceList({ invoices }: { invoices: Invoice[] }) {
  const [filter, setFilter] = useState('');
  ...
}
```

**Props mit explizitem Interface:**
```tsx
interface InvoiceCardProps {
  invoice: Invoice;
  onEdit?: (id: string) => void;
}

export function InvoiceCard({ invoice, onEdit }: InvoiceCardProps) {
  return ...;
}
```

### API Calls

**Immer** über zentralen Client mit Auth:
```ts
// src/lib/api.ts
import { getServerSession } from "next-auth";

export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const session = await getServerSession(authOptions);
  const url = `${process.env.NEXT_PUBLIC_API_URL}${path}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(session?.accessToken && {
        Authorization: `Bearer ${session.accessToken}`,
      }),
      ...options?.headers,
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new ApiError(response.status, error.detail || response.statusText);
  }

  return response.json();
}
```

### State Management

- **Server State:** TanStack Query (`@tanstack/react-query`)
- **Client State:** `useState`, `useReducer`
- **Form State:** React Hook Form + Zod
- **Global State:** Zustand (nur wenn nötig, sonst Props/Context)

### Forms
```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1, 'Pflichtfeld'),
  amount: z.number().positive(),
});

type FormData = z.infer<typeof schema>;

export function InvoiceForm({ onSubmit }: { onSubmit: (d: FormData) => void }) {
  const { register, handleSubmit, formState } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Input {...register('name')} label="Name" error={formState.errors.name?.message} />
      ...
    </form>
  );
}
```

### Error Handling

```tsx
// API Errors fangen, Toast zeigen
try {
  await apiFetch('/api/v1/invoices', { method: 'POST', body });
  toast.success('Gespeichert');
} catch (e) {
  if (e instanceof ApiError) {
    toast.error(e.message);
  } else {
    toast.error('Unerwarteter Fehler');
    console.error(e);
  }
}
```

## Git

### Branches
- `main` - Production, immer deployable
- `feat/<topic>` - Feature
- `fix/<bug>` - Bugfix
- `chore/<topic>` - Tooling, Dependencies

### Commits

**Conventional Commits:**
```
feat: add invoice CRUD endpoints
fix: prevent duplicate supplier entries
docs: update README with new auth flow
chore: bump fastapi to 0.115
test: add integration tests for invoice service
refactor: extract invoice validation to service
```

### Pull Requests

- Titel: gleicher Stil wie Commits
- Beschreibung: was, warum, wie getestet
- Mindestens **1 Reviewer** vor Merge
- CI muss grün sein

## Solution-spezifische `AGENTS.md`

Jede Solution hat eine eigene `AGENTS.md` die ergänzt:
- Domain-spezifische Begriffe (z.B. „Lieferant", „Vertrag")
- Spezielle Conventions wenn Standard nicht passt
- Externe Integrationen (Connectoren, APIs)

**Default-Conventions stehen in dieser Datei und gelten überall, wenn nicht überschrieben.**
