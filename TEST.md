# Test-Anleitung: Clever Code Toolchain

So testest du in **15 Minuten** den kompletten Workflow von Installation bis fertig deployter Solution.

> Nach dem Test räumst du alles auf - Schritt 8 zeigt wie.

---

## Voraussetzungen

| Was | Wie prüfen |
|-----|-----------|
| Mac/Linux/WSL2 | — |
| Docker läuft | `docker info` zeigt keine Fehler |
| Internet + VPN/Office | curl https://code.clevercompany.ai funktioniert |
| Keycloak Admin-Login | du hast User+PW für `id.clevercompany.ai` |

```bash
# Quick-Check
docker info >/dev/null 2>&1 && echo "✓ Docker" || echo "✗ Docker fehlt"
curl -fsSL -o /dev/null https://code.clevercompany.ai/install && echo "✓ Gateway" || echo "✗ Gateway nicht erreichbar"
command -v opencode >/dev/null && echo "✓ opencode" || echo "✗ opencode fehlt"
```

Falls etwas fehlt:

```bash
# Docker
brew install --cask docker
open -a Docker

# opencode
curl -fsSL https://opencode.ai/install | bash
```

---

## Schritt 1: Toolchain installieren *(30 sek)*

```bash
curl -fsSL https://code.clevercompany.ai/install | bash
```

**Erwartete Ausgabe:**

```
→ Pre-flight checks
✓ core tools available
→ Verzeichnisse anlegen
→ Guides + Agent + Scripts laden
✓ alle Files installiert
→ clever Command verlinken
✓ clever -> /Users/<du>/.local/bin/clever
→ Fertig!
```

**Verifizieren:**

```bash
clever help
# → zeigt alle Befehle
```

---

## Schritt 2: Keycloak Auth *(30 sek, einmalig pro 5 min)*

```bash
clever auth
```

**Du wirst gefragt:**
```
Username: <dein-account>@clevercompany.ai
Password: ********
```

**Erwartet:** `✓ Token gespeichert (gültig ~5 min)`

**Falls Fehler:**
- `Login fehlgeschlagen` → Passwort prüfen, ggf. mit Admin Recovery durchgehen
- `connection refused` → bist du im VPN?

---

## Schritt 3: Slug-Check *(15 sek)*

Drei Cases testen - **vergebene** Subdomain, **ungültiges** Format, **freier** Slug:

```bash
# Case 1: Vergeben (sollte fehlschlagen)
clever check procurement
# → ✗ Subdomain: procurement.clevercompany.ai schon vergeben
#   ✗ 'procurement' kann nicht verwendet werden

# Case 2: Ungültiges Format (sollte fehlschlagen)
clever check MeineApp
# → ✗ Slug muss klein, mit Bindestrich

# Case 3: Frei (sollte ok sein)
clever check test-$(whoami)-$(date +%s)
# → ✓ '<dein-test-slug>' ist verfügbar
```

---

## Schritt 4: Test-Solution erstellen *(2-5 min)*

Du brauchst einen **freien Slug**. Z.B. `test-<dein-name>-<zahl>`:

```bash
TEST_SLUG="test-$(whoami)-1"

# nochmal verifizieren
clever check "$TEST_SLUG"
```

Dann **deterministisch** scaffolden (kein LLM):

```bash
clever new "$TEST_SLUG" "Einfache Test-Solution"
clever up "$TEST_SLUG"          # Build + Start + Health-Wait (fehlert sichtbar)
```

Optional ein Datenmodell + List-UI generieren (ebenfalls deterministisch):

```bash
clever add-resource "$TEST_SLUG" Task title:str done:bool
clever up "$TEST_SLUG"
```

**Was passiert (ca. 1-3 min):**

1. `clever new` lädt **31 Template-Dateien** vom Gateway (deterministisch, ohne LLM):
   - `~/.clever/solutions/<SLUG>/frontend/` (Next.js)
   - `~/.clever/solutions/<SLUG>/backend/` (FastAPI)
   - `docker-compose.yml`, `Makefile`, `.env`
2. **Personalisiert**: Slug, Beschreibung, Ports `7100+10·N` (7100 nur, wenn noch keine Solution existiert), zufälliges DB-Passwort
3. **Legt Keycloak-Client + Group** `solution-<SLUG>` an (nur, wenn vorher `clever auth` lief)
4. `clever up` baut die Images und wartet auf Health — bleibt das Backend unhealthy, bricht es **mit Log-Auszug ab**

**Erwartete End-Ausgabe:**

```
✓ Backend ready
✓ Frontend ready

Open these:
  Frontend:  http://localhost:7100
  Backend:   http://localhost:7101/docs
```

**Bricht es ab? Häufige Probleme:**

| Symptom | Fix |
|---------|-----|
| Token expired bei Keycloak | `clever auth` und nochmal |
| Port belegt | andere laufende Solution stoppen oder `.env` Port ändern |
| @audiusintelligence/ui Install Error | npm zum GitHub Packages Registry konfigurieren (siehe README dort) |
| Docker container OOMKilled | mehr RAM für Docker Desktop (Settings → Resources → 8GB+) |

---

## Schritt 5: Solution lokal nutzen *(5 min)*

### Frontend testen

```bash
open http://localhost:7100
```

**Basis-Template:** Health-Page mit Solution-Name + Status „Backend API: ok".
Die API läuft ohne Login — Template-Default ist `DISABLE_AUTH=1` (Fail-Open,
bewusst für lokale Tests; für Produktion: `0` + SSO, siehe JOURNEY.md Phase 5).

**List-UI** (falls in Schritt 4 `add-resource` genutzt):

```bash
open http://localhost:7100/tasks
```

**Was prüfen:**
- [ ] Health-Page: „Backend API: ok" (grün)
- [ ] `/tasks`: List-Page rendert, Einträge aus der DB sichtbar
- [ ] Neue Resource per API: `curl -X POST http://localhost:7101/api/v1/tasks -H 'Content-Type: application/json' -d '{"title":"Test"}'` → erscheint in der Liste
- [ ] Swagger: `open http://localhost:7101/docs` zeigt alle Routen

### Backend testen

```bash
open http://localhost:7101/docs
```

Swagger UI mit allen API-Routen. Probiere `GET /api/v1/<resource>` aus (du brauchst einen Bearer Token aus dem Frontend Cookie).

### Datenbank prüfen

```bash
docker exec -it ${TEST_SLUG}-postgres psql -U <user> <db>
\dt    # Tabellen anzeigen
```

---

## Schritt 6: Solution inspizieren *(1 min)*

```bash
clever inspect $TEST_SLUG
```

Zeigt strukturiert: Ports, Models, Router, Migrations, Frontend-Pages,
Container-Status und die letzten Backend-Errors. Alles sollte passen:
Container `Up`, Migrations 001 (plus eine pro `add-resource`), keine Errors.

Zusätzlich Smoke-Test der API:

```bash
curl -fsS http://localhost:7101/health        # {"status":"ok",...}
curl -fsS http://localhost:7101/api/v1/items  # []
```

Falls irgendetwas nicht grün ist: das ist ein **Feedback an die Toolchain** —
`clever-code`-Repo (nicht `~/.clever/`), siehe `DEVELOPING.md` (isolierter Dev-Loop).

---

## Schritt 7: Kollegen-Invite testen *(30 sek)*

```bash
# Kollegen freischalten
clever invite $TEST_SLUG kollege@clevercompany.ai
```

**Erwartet:** `✓ kollege@clevercompany.ai hat jetzt Zugriff auf solution-<SLUG>`

Voraussetzung: Der User existiert schon in Keycloak (sich mind. 1× irgendwo eingeloggt).

---

## Schritt 8: Cleanup *(1 min)*

Nach erfolgreichem Test alles aufräumen:

```bash
TEST_SLUG="test-$(whoami)-1"   # gleicher Slug wie oben

# 1. Container + Volumes weg
cd ~/.clever/solutions/$TEST_SLUG
docker compose down -v

# 2. Solution-Ordner löschen
cd ~ && rm -rf ~/.clever/solutions/$TEST_SLUG

# 3. Keycloak Client löschen (über UI oder API)
# https://id.clevercompany.ai/admin → Realm solutions → Clients
# → solution-<SLUG> → Delete

# Oder per API (Auto-Refresh holt sich ein frisches Token):
TOKEN=$(bash ~/.clever/scripts/keycloak-client.sh token)
CID="solution-$TEST_SLUG"
UUID=$(curl -fsS "https://id.clevercompany.ai/admin/realms/solutions/clients?clientId=$CID" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['id'])")
curl -fsS -X DELETE "https://id.clevercompany.ai/admin/realms/solutions/clients/$UUID" \
  -H "Authorization: Bearer $TOKEN"
echo "✓ Keycloak Client weg"
```

---

## Was erfolgreich getestet wurde

Nach Schritt 8 hast du verifiziert:

- ✅ Installer pullt Files via Gateway korrekt
- ✅ `clever` CLI mit Help, Auth, Check
- ✅ Slug-Verfügbarkeits-Check erkennt belegte/freie/ungültige Slugs
- ✅ Deterministisches Scaffold (31 Template-Dateien, ohne LLM)
- ✅ Generatoren: `add-resource` (Model + API + Page + Migration), `add-page`
- ✅ Auto-Setup von Keycloak-Client (Redirect URIs, Group)
- ✅ Lokaler Stack läuft (Frontend + Backend + DB, Health-Wait fehlert sichtbar)
- ✅ User-Invite via Group-Membership

> Hinweis: Der Keycloak-Login-Flow (SSO) ist im Basis-Template noch nicht enthalten
> (`DISABLE_AUTH=1`). Für „privat online" siehe JOURNEY.md Phase 5.

---

## Probleme melden

Bei Bugs / unerwarteten Verhalten:

```bash
# Diagnose-Info sammeln
{
  echo "=== Versionen ==="
  clever help | head -3
  opencode --version
  docker --version

  echo
  echo "=== Installierte Files ==="
  ls -la ~/.clever/scripts/
  ls -la ~/.clever/guides/
  ls -la ~/.config/opencode/agent/

  echo
  echo "=== Letzte Logs ==="
  tail -50 ~/.clever/install.log 2>/dev/null
} > /tmp/clever-diag.txt

# Dann den Inhalt von /tmp/clever-diag.txt ins Issue
```

Issues / Feedback:
- GitHub: https://github.com/audiusintelligence/clever-code/issues
- Slack: `#clever-solutions`

---

## Was als nächstes testen

Nach dem grundlegenden Test sind diese Use Cases interessant:

1. **Komplexere Domain** - Solution mit mehreren Resources, Beziehungen
2. **Bestehende Solution updaten** - via opencode neue Felder hinzufügen
3. **Production Deploy** - `clever deploy` testen
4. **Branding-Compliance** - generierter Code passt zum @audiusintelligence/ui Look?
5. **Multi-User** - 2 User invitieren, parallele Nutzung
