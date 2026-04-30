#!/usr/bin/env bash
# clever scaffold <slug> [description]
# Deterministisches Kopieren des audius-base Templates.
# KEIN LLM beteiligt - garantiert lauffähig.
set -euo pipefail

SLUG="${1:-}"
DESC="${2:-Clever Solution}"

[[ -z "$SLUG" ]] && { echo "Usage: clever scaffold <slug> [description]"; exit 1; }
[[ ! "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]] && { echo "✗ Slug muss klein, mit Bindestrich"; exit 1; }

CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
INSTALLER_BASE="${CLEVER_INSTALLER_BASE:-https://code.clevercompany.ai}"
SOLDIR="$CLEVER_HOME/solutions/$SLUG"

[[ -d "$SOLDIR" ]] && { echo "✗ $SOLDIR existiert bereits"; exit 1; }

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
ok()   { echo "${GREEN}✓${NC} $1"; }
step() { echo; echo "→ $1"; }

# Port-Allokation: 7000 + 10*N
COUNT=$(ls -1 "$CLEVER_HOME/solutions/" 2>/dev/null | wc -l | tr -d ' ')
PORT_FE=$((7100 + COUNT * 10))
PORT_BE=$((PORT_FE + 1))
PORT_DB=$((PORT_FE + 2))

step "Lege Solution '$SLUG' an in $SOLDIR"
echo "    Ports: Frontend=$PORT_FE, Backend=$PORT_BE, DB=$PORT_DB"

# Liste aller Files im audius-base Template
TEMPLATE_FILES=(
  "frontend/package.json"
  "frontend/next.config.js"
  "frontend/tsconfig.json"
  "frontend/tailwind.config.ts"
  "frontend/postcss.config.js"
  "frontend/Dockerfile"
  "frontend/.dockerignore"
  "frontend/src/app/layout.tsx"
  "frontend/src/app/page.tsx"
  "frontend/src/app/globals.css"
  "backend/pyproject.toml"
  "backend/Dockerfile"
  "backend/.dockerignore"
  "backend/alembic.ini"
  "backend/src/__init__.py"
  "backend/src/main.py"
  "backend/src/core/__init__.py"
  "backend/src/core/config.py"
  "backend/src/core/db.py"
  "backend/src/core/auth.py"
  "backend/src/api/__init__.py"
  "backend/src/api/me.py"
  "backend/src/api/items.py"
  "backend/alembic/env.py"
  "backend/alembic/script.py.mako"
  "backend/alembic/versions/001_initial.py"
  "docker-compose.yml"
  "Makefile"
  ".env.example"
  ".gitignore"
  "README.md"
)

step "Lade $((${#TEMPLATE_FILES[@]})) Template-Dateien"

for f in "${TEMPLATE_FILES[@]}"; do
  TARGET="$SOLDIR/$f"
  mkdir -p "$(dirname "$TARGET")"
  curl -fsSL "$INSTALLER_BASE/templates/audius-base/$f" -o "$TARGET" \
    || { echo "✗ Download fehlgeschlagen: $f"; exit 1; }
done
ok "Files geladen"

# Placeholders ersetzen
step "Personalisiere"
PG_PW=$(openssl rand -hex 16)

find "$SOLDIR" -type f \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" \
  -o -name "*.json" -o -name "*.yml" -o -name "*.yaml" \
  -o -name "*.toml" -o -name "Dockerfile" -o -name "Makefile" \
  -o -name "*.md" -o -name ".env*" -o -name ".dockerignore" \) \
  -exec sed -i.bak \
    -e "s|__SOLUTION_NAME__|$SLUG|g" \
    -e "s|__SOLUTION_DESCRIPTION__|$DESC|g" \
    -e "s|__POSTGRES_PASSWORD__|$PG_PW|g" \
    {} \;
find "$SOLDIR" -name "*.bak" -delete

# .env aus .env.example
cp "$SOLDIR/.env.example" "$SOLDIR/.env"
sed -i.bak \
  -e "s|^PORT_FRONTEND=.*|PORT_FRONTEND=$PORT_FE|" \
  -e "s|^PORT_BACKEND=.*|PORT_BACKEND=$PORT_BE|" \
  -e "s|^PORT_DB=.*|PORT_DB=$PORT_DB|" \
  "$SOLDIR/.env"
rm -f "$SOLDIR/.env.bak"
ok "Slug + Ports + Secrets eingesetzt"

# Optional: Keycloak Client
step "Keycloak Client"
if [[ -f "$CLEVER_HOME/admin-token" ]]; then
  SECRET=$(bash "$CLEVER_HOME/scripts/keycloak-client.sh" create "$SLUG" "$DESC" "$PORT_FE" 2>&1 | tail -1)
  if [[ "$SECRET" =~ ^[a-zA-Z0-9-]+$ ]]; then
    sed -i.bak "s|^KEYCLOAK_CLIENT_SECRET=.*|KEYCLOAK_CLIENT_SECRET=$SECRET|" "$SOLDIR/.env"
    rm -f "$SOLDIR/.env.bak"
    ok "Keycloak Client 'solution-$SLUG' angelegt"
  else
    echo "  Keycloak-Anlage fehlgeschlagen - Auth bleibt disabled (DISABLE_AUTH=1)"
  fi
else
  echo "  Übersprungen ('clever auth' nicht ausgeführt) - Auth bleibt disabled"
fi

step "Fertig!"
cat <<EOF

  ${GREEN}✓${NC} Solution '${SLUG}' erstellt in:
       $SOLDIR

  ${YELLOW}Starten:${NC}
       cd $SOLDIR
       make up
       open http://localhost:$PORT_FE

  ${YELLOW}Erweitern:${NC}
       opencode --agent clever-solution "füge X hinzu"

EOF
