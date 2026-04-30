#!/usr/bin/env bash
# clever inspect <slug>
# Strukturierte Übersicht über eine Solution für den LLM-Agent.
# Output ist deterministisch + maschinen-lesbar.
set -euo pipefail

SLUG="${1:-}"
[[ -z "$SLUG" ]] && { echo "Usage: clever inspect <slug>"; exit 1; }
CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
SOLDIR="$CLEVER_HOME/solutions/$SLUG"
[[ ! -d "$SOLDIR" ]] && { echo "✗ Solution '$SLUG' fehlt"; exit 1; }

cd "$SOLDIR"

echo "=== solution: $SLUG ==="
echo "path: $SOLDIR"

echo
echo "=== ports ==="
grep -E "^PORT_" .env | sed 's/^/  /'

echo
echo "=== models ==="
ls backend/src/models/*.py 2>/dev/null | grep -v __init__ | xargs -I {} basename {} .py | sed 's/^/  /'
[[ -d backend/src/models ]] || echo "  (no backend/src/models/ dir)"

echo
echo "=== routers ==="
for f in backend/src/api/*.py; do
  [[ "$(basename $f)" == "__init__.py" ]] && continue
  PREFIX=$(grep -oE 'prefix="[^"]+"' "$f" | head -1 | cut -d'"' -f2)
  echo "  $(basename $f .py) -> $PREFIX"
done

echo
echo "=== migrations ==="
ls backend/alembic/versions/*.py 2>/dev/null | xargs -I {} basename {} .py | sed 's/^/  /'

echo
echo "=== frontend pages ==="
find frontend/src/app -name "page.tsx" | sed "s|frontend/src/app||; s|/page.tsx||; s|^|  |; s|^  $|  /|"

echo
echo "=== container status ==="
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | tail -n +2 | sed 's/^/  /' || echo "  (compose not running or not found)"

echo
echo "=== last backend errors (10) ==="
docker compose logs backend 2>/dev/null | grep -iE "error|traceback|fail" | tail -10 | sed 's/^/  /' || echo "  (no logs)"
