# Clever Solution Architecture

Standard-Aufbau einer Solution. **Verbindlich** für alles unter `*.clevercompany.ai`.

## Stack

| Layer | Technologie | Warum |
|-------|-------------|-------|
| Frontend | Next.js 14+ (App Router) | SSR + RSC, Standard im Audius-Ökosystem |
| UI | `@audiusintelligence/ui` + Tailwind | Konsistentes Look & Feel |
| Auth | Keycloak via OIDC (`id.clevercompany.ai`) | SSO über alle Solutions |
| Backend | FastAPI 0.115+ (async) | Performance, Type-Safety, Auto-Docs |
| ORM | SQLAlchemy 2.0 (async) + Alembic | Standard, Migrations |
| Datenbank | PostgreSQL 16 | Plattform-Standard |
| Cache | Redis (optional) | Falls nötig |
| Container | Docker Compose lokal, Docker Swarm production | Reproducible |

## Verzeichnis-Struktur

```
my-solution/
├── frontend/                          # Next.js App
│   ├── src/
│   │   ├── app/                       # App Router
│   │   │   ├── (auth)/                # Auth-geschützte Routes
│   │   │   │   └── layout.tsx         # SessionGuard
│   │   │   ├── api/auth/[...nextauth]/route.ts  # NextAuth Keycloak
│   │   │   ├── layout.tsx             # Root Layout mit ThemeProvider
│   │   │   └── page.tsx               # Landing
│   │   ├── components/                # App-spezifische Komponenten
│   │   ├── lib/
│   │   │   ├── api.ts                 # Backend API Client (auth-aware)
│   │   │   ├── auth.ts                # NextAuth Config
│   │   │   └── env.ts                 # Validierte ENV-Variablen
│   │   └── hooks/                     # React Hooks
│   ├── tailwind.config.js             # extends @audiusintelligence/ui/preset
│   ├── next.config.js
│   └── package.json
│
├── backend/                           # FastAPI App
│   ├── src/
│   │   ├── main.py                    # FastAPI App + Middlewares
│   │   ├── core/
│   │   │   ├── config.py              # Pydantic Settings
│   │   │   ├── db.py                  # Async SQLAlchemy Engine
│   │   │   ├── auth.py                # Keycloak JWT Validierung
│   │   │   └── security.py            # Helpers
│   │   ├── api/
│   │   │   ├── deps.py                # Dependencies (get_db, get_user)
│   │   │   ├── me.py                  # /me Endpoint
│   │   │   └── <feature>.py           # je Feature ein Router
│   │   ├── models/                    # SQLAlchemy ORM
│   │   │   ├── base.py
│   │   │   └── user.py
│   │   ├── schemas/                   # Pydantic Schemas (API DTOs)
│   │   └── services/                  # Business Logic
│   ├── alembic/                       # DB Migrations
│   │   ├── versions/
│   │   └── env.py
│   ├── tests/unit/                    # pytest
│   ├── pyproject.toml                 # Ruff, deps
│   └── Dockerfile
│
├── deploy/
│   ├── nginx.conf                     # falls eigener nginx, sonst zentrale Plattform
│   └── deploy.sh                      # SSH zu host2
│
├── docker-compose.yml                 # full local stack
├── docker-compose.prod.yml            # production overrides
├── Makefile                           # make up, make backend-test, ...
├── .env.example                       # template
├── .env                               # auto-generiert, gitignored
└── AGENTS.md                          # solution-spezifische conventions
```

## Auth-Flow (verbindlich)

```
User → Frontend (Next.js)
         │
         ├─── /api/auth/signin → Keycloak (id.clevercompany.ai)
         │                            │
         │                            └─── Login + Group-Check
         │
         ├─── Session cookie (signed JWT)
         │
         └─── API Call: Authorization: Bearer <access_token>
                    │
                    ▼
              Backend (FastAPI)
                    │
                    ├─── verify token (JWKS from Keycloak)
                    ├─── auto-provision User in DB (first login)
                    └─── attach `current_user` to request
```

### Pflicht-Konfiguration im Frontend

```ts
// src/lib/auth.ts
import KeycloakProvider from "next-auth/providers/keycloak";

export const authOptions = {
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID!,
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET!,
      issuer: process.env.KEYCLOAK_ISSUER!,  // https://id.clevercompany.ai/realms/clevercompany
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, account }) {
      if (account) token.accessToken = account.access_token;
      return token;
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken;
      return session;
    },
  },
};
```

### Pflicht-Middleware im Backend

```python
# src/core/auth.py
from jose import jwt
import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer

bearer = HTTPBearer()
ISSUER = "https://id.clevercompany.ai/realms/clevercompany"
JWKS_URL = f"{ISSUER}/protocol/openid-connect/certs"

# Cache JWKS
_jwks: dict | None = None

async def _get_jwks():
    global _jwks
    if _jwks is None:
        async with httpx.AsyncClient() as c:
            _jwks = (await c.get(JWKS_URL)).json()
    return _jwks

async def get_current_user(token = Depends(bearer)):
    jwks = await _get_jwks()
    try:
        claims = jwt.decode(
            token.credentials,
            jwks,
            algorithms=["RS256"],
            issuer=ISSUER,
            audience="solution-<your-name>",
        )
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")
    # Auto-Provision (siehe me.py)
    return claims
```

## Datenbank-Konventionen

- **Migrations sind Pflicht** (Alembic). Niemals Schema in `models.py` ändern ohne Migration.
- **Async überall:** `AsyncSession`, `async def`, `await session.execute()`
- **Naming:** Tabellen `snake_case`, Plural (`invoices`, `suppliers`)
- **Primary Keys:** UUID v4 default (`id: Mapped[UUID] = mapped_column(default=uuid4)`)
- **Timestamps:** `created_at`, `updated_at` automatisch via Mixin
- **Soft Delete:** `deleted_at: datetime | None = None` (nur wenn nötig)

## API-Konventionen

- **REST-First**, GraphQL nur wenn nötig
- **Pfade:** `/api/v1/<resource>` (immer mit Version)
- **HTTP Status:** korrekt nutzen (`201` für Create, `204` für Delete, `409` für Conflict)
- **Pagination:** `?page=1&size=20` mit Response `{ items, total, page, size }`
- **Filtern:** Query-Params, validiert via Pydantic (`?status=active&from=2024-01-01`)
- **Errors:** RFC 7807 Format `{ type, title, status, detail }`

## Deploy

| Env | Wo | Domain | Trigger |
|-----|----|----|----|
| Local | Docker Compose | `localhost:<port>` | `make up` |
| Staging | host2 | `<name>-staging.clevercompany.ai` | `clever deploy <name> --env staging` |
| Production | host2 | `<name>.clevercompany.ai` | `clever deploy <name>` |

## Was eine Solution NICHT selbst implementiert

- **Login-UI** (kommt von Keycloak)
- **User-Management** (kommt von Keycloak Admin)
- **SSL** (zentrale nginx auf 10.200.3.10:80, Let's Encrypt)
- **DNS** (Wildcard `*.clevercompany.ai` schon konfiguriert)
- **Monitoring/Logs** (Plattform-zentral, opt-in)

## Health Endpoints (Pflicht)

```python
# Backend
@app.get("/health/liveliness")
async def live(): return {"status": "ok"}

@app.get("/health/readiness")
async def ready(db = Depends(get_db)):
    await db.execute(text("SELECT 1"))
    return {"status": "ok"}
```

## Was als nächstes lesen

- `conventions.md` - Code-Style
- `recipes/auth-page.md` - Geschützte Pages
- `recipes/crud.md` - Standard CRUD
- `recipes/api-route.md` - Backend Endpoint
