#!/usr/bin/env bash
# clever up <slug>
# Build + start + warte bis healthy + zeige URLs
set -euo pipefail

SLUG="${1:-}"
[[ -z "$SLUG" ]] && { echo "Usage: clever up <slug>"; exit 1; }
CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
SOLDIR="$CLEVER_HOME/solutions/$SLUG"
[[ ! -d "$SOLDIR" ]] && { echo "✗ Solution '$SLUG' fehlt"; exit 1; }

cd "$SOLDIR"
PORT_FE=$(grep PORT_FRONTEND .env | cut -d= -f2)
PORT_BE=$(grep PORT_BACKEND .env | cut -d= -f2)

echo "→ Building + starting $SLUG"
docker compose up -d --build 2>&1 | tail -10

echo
echo "→ Waiting for backend (max 30s)"
for i in {1..30}; do
  if curl -fsS "http://localhost:$PORT_BE/health" >/dev/null 2>&1; then
    echo "✓ Backend ready"
    break
  fi
  sleep 1
done

echo
echo "→ Waiting for frontend (max 30s)"
for i in {1..30}; do
  if curl -fsSI "http://localhost:$PORT_FE" 2>/dev/null | grep -q "200\|307\|301"; then
    echo "✓ Frontend ready"
    break
  fi
  sleep 1
done

echo
echo "Open these:"
echo "  Frontend:  http://localhost:$PORT_FE"
echo "  Backend:   http://localhost:$PORT_BE/docs"
