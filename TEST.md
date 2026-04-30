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

Dann opencode triggern:

```bash
opencode "Erstelle eine neue Clever Solution namens $TEST_SLUG für eine einfache Aufgaben-Liste mit Titel, Beschreibung und Status (offen/erledigt). Nutze den clever-solution Agent."
```

**Was passiert (ca. 2-5 min):**

opencode wird interaktiv:
1. **Liest die Guides** aus `~/.clever/guides/`
2. **Fragt nach** falls Infos fehlen (Felder, Sprache)
3. **Generiert** ~40-50 Dateien:
   - `~/.clever/solutions/<SLUG>/frontend/` (Next.js)
   - `~/.clever/solutions/<SLUG>/backend/` (FastAPI)
   - `docker-compose.yml`, `Makefile`, `.env`
4. **Ruft** `keycloak-client.sh create` auf → legt `solution-<SLUG>` Client + Group an
5. **Startet** den Stack via `make up`
6. **Sagt dir** die URLs

**Erwartete End-Ausgabe:**

```
✓ Solution '<SLUG>' ist live!

  Frontend:    http://localhost:7100
  Backend API: http://localhost:7101/docs
  DB Admin:    psql postgres://localhost:7102/<slug>
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

Du wirst auf `id.clevercompany.ai` weitergeleitet. Login mit deinem Account. Zurück zur App siehst du eine leere Liste + „+ Neu" Button.

**Was prüfen:**
- [ ] Login redirected korrekt
- [ ] Nach Login bist du zurück auf der App
- [ ] Header zeigt deinen Namen
- [ ] „Neu" öffnet ein Form
- [ ] Submit erstellt einen Eintrag → erscheint in der Liste

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

## Schritt 6: Code-Qualität prüfen *(2 min)*

opencode sollte clean Code generiert haben. Verifizieren:

```bash
cd ~/.clever/solutions/$TEST_SLUG

# Frontend Lint
make frontend-lint

# Backend Lint + Type
make backend-lint
make backend-typecheck

# Tests laufen
make backend-test
```

Alles sollte grün sein. Falls nicht: das ist ein **Feedback an die Guides** - sag mir welche Konvention nicht eingehalten wurde, dann schärfen wir die Guides.

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
# https://id.clevercompany.ai/admin → Realm clevercompany → Clients
# → solution-<SLUG> → Delete

# Oder per API (Token muss frisch sein):
clever auth
TOKEN=$(cat ~/.clever/admin-token)
CID="solution-$TEST_SLUG"
UUID=$(curl -fsS "https://id.clevercompany.ai/admin/realms/clevercompany/clients?clientId=$CID" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['id'])")
curl -fsS -X DELETE "https://id.clevercompany.ai/admin/realms/clevercompany/clients/$UUID" \
  -H "Authorization: Bearer $TOKEN"
echo "✓ Keycloak Client weg"
```

---

## Was erfolgreich getestet wurde

Nach Schritt 8 hast du verifiziert:

- ✅ Installer pullt Files via Gateway korrekt
- ✅ `clever` CLI mit Help, Auth, Check
- ✅ Slug-Verfügbarkeits-Check erkennt belegte/freie/ungültige Slugs
- ✅ opencode liest die Guides und generiert eine vollständige Solution
- ✅ Auto-Setup von Keycloak-Client (Redirect URIs, Group)
- ✅ Lokaler Stack läuft (Frontend + Backend + DB)
- ✅ Login-Flow über `id.clevercompany.ai` funktioniert
- ✅ User-Invite via Group-Membership

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
