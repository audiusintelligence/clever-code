#!/usr/bin/env bash
# clever check <slug> - prüft ob ein Solution-Slug verfügbar ist
# Checkt: Lokal, Gateway (Subdomain), Keycloak (Client)
set -euo pipefail

SLUG="${1:-}"
[[ -z "$SLUG" ]] && { echo "Usage: $0 <slug>"; exit 1; }

# Slug-Format validieren
if ! [[ "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "✗ Slug muss klein, mit Bindestrich (z.B. 'invoice-tracker'). Gefunden: '$SLUG'"
    exit 1
fi

CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
KC_BASE="${KEYCLOAK_BASE:-https://id.clevercompany.ai}"
KC_REALM="${KEYCLOAK_REALM:-clevercompany}"
GATEWAY="${GATEWAY:-http://code.clevercompany.ai}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; ERR=1; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

ERR=0

# 1. Lokal
if [[ -d "$CLEVER_HOME/solutions/$SLUG" ]]; then
    fail "Lokal: $CLEVER_HOME/solutions/$SLUG existiert bereits"
else
    ok  "Lokal: kein Konflikt"
fi

# 2. Gateway / Subdomain
HTTP_BODY=$(curl -sS --max-time 5 \
    -H "Host: ${SLUG}.clevercompany.ai" \
    "$GATEWAY/" 2>/dev/null || echo "TIMEOUT")

if echo "$HTTP_BODY" | grep -q "solution_not_found"; then
    ok  "Subdomain: ${SLUG}.clevercompany.ai ist frei"
elif echo "$HTTP_BODY" | grep -q "TIMEOUT"; then
    warn "Subdomain: Gateway nicht erreichbar (kein VPN?), Subdomain-Check übersprungen"
else
    fail "Subdomain: ${SLUG}.clevercompany.ai schon vergeben"
    echo "    Response: $(echo "$HTTP_BODY" | head -c 100)"
fi

# 3. Keycloak Client
if [[ -f "$CLEVER_HOME/admin-token" ]]; then
    TOKEN="$(cat $CLEVER_HOME/admin-token)"
    EXISTS=$(curl -sS --max-time 5 \
        "$KC_BASE/admin/realms/$KC_REALM/clients?clientId=solution-${SLUG}" \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null \
        | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    print(len(d) if isinstance(d, list) else 'ERROR')
except Exception:
    print('ERROR')" )

    case "$EXISTS" in
        0)       ok "Keycloak: Client solution-${SLUG} ist frei" ;;
        ERROR)   warn "Keycloak: Token abgelaufen oder Auth-Fehler ('clever auth' erneut)" ;;
        *)       fail "Keycloak: Client solution-${SLUG} existiert bereits" ;;
    esac
else
    warn "Keycloak: kein Admin-Token (überspringe — 'clever auth' für vollständigen Check)"
fi

echo
if [[ "$ERR" -eq 0 ]]; then
    ok "'$SLUG' ist verfügbar"
    exit 0
else
    fail "'$SLUG' kann nicht verwendet werden"
    exit 1
fi
