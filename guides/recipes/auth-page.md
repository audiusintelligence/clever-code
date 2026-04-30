# Recipe: Geschützte Page mit Auth

So baust du eine Page, die nur eingeloggte User sehen.

## Frontend (Next.js App Router)

### 1. Auth Layout (einmalig pro Solution)

```tsx
// src/app/(auth)/layout.tsx
import { redirect } from 'next/navigation';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';

export default async function AuthLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authOptions);
  if (!session) redirect('/api/auth/signin');
  return <>{children}</>;
}
```

Alle Pages unter `app/(auth)/...` sind automatisch geschützt.

### 2. Eine geschützte Page

```tsx
// src/app/(auth)/invoices/page.tsx
import { AppLayout, Card } from '@audiusintelligence/ui';
import { apiFetch } from '@/lib/api';

export default async function InvoicesPage() {
  const invoices = await apiFetch<Invoice[]>('/api/v1/invoices');

  return (
    <AppLayout>
      <div className="max-w-7xl mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold font-montserrat mb-6">Rechnungen</h1>
        <Card>
          {invoices.map(inv => <div key={inv.id}>{inv.title}</div>)}
        </Card>
      </div>
    </AppLayout>
  );
}
```

### 3. Header mit Logout

```tsx
// src/app/(auth)/layout.tsx (erweitert)
import { Header } from '@audiusintelligence/ui';
import { signOut } from 'next-auth/react';

const session = await getServerSession(authOptions);

return (
  <>
    <Header
      user={{ name: session.user.name, email: session.user.email }}
      onLogout={() => signOut()}
    />
    {children}
  </>
);
```

## Backend (FastAPI)

### 1. Endpoint mit Auth-Dependency

```python
# src/api/invoices.py
from fastapi import APIRouter, Depends
from src.api.deps import get_current_user, get_db
from src.models.invoice import Invoice
from src.schemas.invoice import InvoiceRead

router = APIRouter(prefix="/api/v1/invoices", tags=["invoices"])

@router.get("", response_model=list[InvoiceRead])
async def list_invoices(
    user = Depends(get_current_user),
    db = Depends(get_db),
):
    result = await db.execute(
        select(Invoice).where(Invoice.user_id == user.id)
    )
    return list(result.scalars())
```

`get_current_user` aus `src/core/auth.py` (siehe `architecture.md`):
- Validiert JWT gegen Keycloak JWKS
- Provisioniert User automatisch in DB beim ersten Login
- Wirft 401 wenn Token ungültig

### 2. Router registrieren

```python
# src/main.py
from src.api import invoices

app.include_router(invoices.router)
```

## Test

```python
# tests/integration/test_invoices.py
async def test_list_invoices_requires_auth(client):
    response = await client.get("/api/v1/invoices")
    assert response.status_code == 401

async def test_list_invoices_with_valid_token_returns_200(client, valid_token):
    response = await client.get(
        "/api/v1/invoices",
        headers={"Authorization": f"Bearer {valid_token}"},
    )
    assert response.status_code == 200
```
