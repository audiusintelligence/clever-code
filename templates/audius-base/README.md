# __SOLUTION_NAME__

__SOLUTION_DESCRIPTION__

Clever Solution auf Basis des `audius-base` Templates.

## Schnellstart

```bash
make up
open http://localhost:3000
```

Backend Swagger: http://localhost:8000/docs

## Stack

- Frontend: Next.js 14 (App Router) + Tailwind
- Backend: FastAPI + SQLAlchemy 2 (async) + Alembic
- DB: PostgreSQL 16
- Auth: Keycloak SSO via `id.clevercompany.ai` (per Default für lokale Dev disabled, `DISABLE_AUTH=0` zum Aktivieren)

## Befehle

```bash
make up              # Container starten
make down            # Stoppen
make logs            # Logs verfolgen
make rebuild         # Neu bauen
make migrate m="..."  # Neue Migration
make psql            # DB-Shell
make shell-be        # Backend-Shell
make clean           # Alles inkl. Volumes löschen
```

## Erweitern mit opencode

```bash
opencode "füge ein Modell 'Project' mit Feldern name, description hinzu"
opencode "erstelle eine Page /projects mit Tabelle"
```

## Auth aktivieren

In `.env`:
```
DISABLE_AUTH=0
```

Das setzt voraus dass der Keycloak-Client `solution-__SOLUTION_NAME__` existiert und Login auf `id.clevercompany.ai/realms/solutions` ermöglicht.
