#!/usr/bin/env bash
# Keycloak Admin Helper für Clever Solutions
# Verfügt über: auth | create | invite | revoke | list
set -euo pipefail

CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
KC_BASE="${KEYCLOAK_BASE:-https://id.clevercompany.ai}"
KC_REALM="${KEYCLOAK_REALM:-clevercompany}"
KC_ADMIN_REALM="master"
mkdir -p "$CLEVER_HOME"

get_token() {
  curl -fsS -X POST \
    "$KC_BASE/realms/$KC_ADMIN_REALM/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=$1&password=$2" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])"
}

token() {
  test -f "$CLEVER_HOME/admin-token" || {
    echo "✗ Bitte erst 'clever auth' ausführen." >&2; exit 1; }
  cat "$CLEVER_HOME/admin-token"
}

case "${1:-help}" in
  auth)
    MODE="${2:-browser}"
    if [[ "$MODE" == "--password" ]] || [[ "$MODE" == "password" ]]; then
      # Klassischer Password-Flow
      echo "Keycloak Admin Login ($KC_BASE) - Password Flow"
      read -p "  Username: " U
      read -sp "  Password: " P; echo
      T=$(get_token "$U" "$P") || { echo "✗ Login fehlgeschlagen"; exit 1; }
      echo "$T" > "$CLEVER_HOME/admin-token"
      chmod 600 "$CLEVER_HOME/admin-token"
      echo "✓ Token gespeichert (gültig ~5 min)"
      exit 0
    fi

    # Browser-Flow via Device Authorization Grant (Standard für CLIs)
    DEVICE_CLIENT="${CLEVER_DEVICE_CLIENT_ID:-clever-cli}"

    DEVICE_RESP=$(curl -fsS -X POST \
      "$KC_BASE/realms/$KC_ADMIN_REALM/protocol/openid-connect/auth/device" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$DEVICE_CLIENT&scope=openid" 2>/dev/null) || {
        echo "✗ Device-Flow nicht verfügbar (Client '$DEVICE_CLIENT' existiert nicht oder Device-Flow nicht aktiviert)"
        echo
        echo "  Fallback: clever auth --password"
        echo
        echo "  Oder ein Admin richtet einmalig den Client ein (siehe Doku)."
        exit 1
      }

    DEVICE_CODE=$(echo "$DEVICE_RESP"  | python3 -c "import sys,json;print(json.load(sys.stdin)['device_code'])")
    USER_CODE=$(echo "$DEVICE_RESP"    | python3 -c "import sys,json;print(json.load(sys.stdin)['user_code'])")
    VERIFY_URI=$(echo "$DEVICE_RESP"   | python3 -c "import sys,json;print(json.load(sys.stdin)['verification_uri_complete'])")
    INTERVAL=$(echo "$DEVICE_RESP"     | python3 -c "import sys,json;print(json.load(sys.stdin).get('interval',5))")
    EXPIRES=$(echo "$DEVICE_RESP"      | python3 -c "import sys,json;print(json.load(sys.stdin).get('expires_in',600))")

    echo "Keycloak Login - Browser öffnet sich..."
    echo
    echo "  Code: $USER_CODE"
    echo "  URL:  $VERIFY_URI"
    echo

    # Browser öffnen (macOS, Linux, WSL)
    if command -v open >/dev/null 2>&1; then
      open "$VERIFY_URI"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$VERIFY_URI" >/dev/null 2>&1
    elif command -v explorer.exe >/dev/null 2>&1; then
      explorer.exe "$VERIFY_URI"
    else
      echo "(Browser nicht automatisch geöffnet - bitte URL manuell öffnen)"
    fi

    echo "Warte auf Login im Browser..."
    DEADLINE=$(( $(date +%s) + EXPIRES ))
    while [[ $(date +%s) -lt $DEADLINE ]]; do
      sleep "$INTERVAL"
      TOK_RESP=$(curl -sS -X POST \
        "$KC_BASE/realms/$KC_ADMIN_REALM/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=$DEVICE_CODE&client_id=$DEVICE_CLIENT" 2>/dev/null)

      ERR=$(echo "$TOK_RESP" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('error',''))
except: print('')" 2>/dev/null)

      case "$ERR" in
        authorization_pending|slow_down) printf "." ;;
        "")
          # Erfolgreich
          T=$(echo "$TOK_RESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
          echo
          echo "$T" > "$CLEVER_HOME/admin-token"
          chmod 600 "$CLEVER_HOME/admin-token"
          echo "✓ Token gespeichert (gültig ~5 min)"
          exit 0
          ;;
        expired_token|access_denied)
          echo
          echo "✗ Login abgebrochen oder abgelaufen"
          exit 1
          ;;
        *)
          echo
          echo "✗ Fehler: $ERR"
          echo "$TOK_RESP"
          exit 1
          ;;
      esac
    done
    echo
    echo "✗ Timeout - Login nicht innerhalb von ${EXPIRES}s abgeschlossen"
    exit 1
    ;;

  create)
    NAME="$2"; DESC="${3:-}"; PORT="${4:-3000}"
    T=$(token)
    CID="solution-${NAME}"

    BODY=$(python3 -c "
import json,sys
print(json.dumps({
  'clientId':'$CID',
  'name':'Solution: $NAME',
  'description':'$DESC',
  'enabled':True,
  'publicClient':False,
  'standardFlowEnabled':True,
  'directAccessGrantsEnabled':False,
  'redirectUris':[
    f'http://localhost:$PORT/*',
    f'http://localhost:3000/*',
    f'https://${NAME}.clevercompany.ai/*',
    f'https://${NAME}-staging.clevercompany.ai/*',
  ],
  'webOrigins':[
    f'http://localhost:$PORT',
    f'https://${NAME}.clevercompany.ai',
  ],
}))")

    HTTP=$(curl -s -o /tmp/kc.json -w "%{http_code}" -X POST \
      "$KC_BASE/admin/realms/$KC_REALM/clients" \
      -H "Authorization: Bearer $T" \
      -H "Content-Type: application/json" \
      -d "$BODY")

    if [[ "$HTTP" != "201" && "$HTTP" != "409" ]]; then
      echo "✗ Client-Erstellung fehlgeschlagen (HTTP $HTTP)"; cat /tmp/kc.json; exit 1
    fi

    UUID=$(curl -fsS "$KC_BASE/admin/realms/$KC_REALM/clients?clientId=$CID" \
      -H "Authorization: Bearer $T" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['id'])")
    SECRET=$(curl -fsS "$KC_BASE/admin/realms/$KC_REALM/clients/$UUID/client-secret" \
      -H "Authorization: Bearer $T" | python3 -c "import sys,json;print(json.load(sys.stdin)['value'])")

    # Group anlegen
    curl -sS -X POST "$KC_BASE/admin/realms/$KC_REALM/groups" \
      -H "Authorization: Bearer $T" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${CID}-users\"}" >/dev/null 2>&1 || true

    echo "$SECRET"  # für Caller
    ;;

  invite)
    NAME="$2"; EMAIL="$3"
    T=$(token)
    UID=$(curl -fsS "$KC_BASE/admin/realms/$KC_REALM/users?email=$EMAIL&exact=true" \
      -H "Authorization: Bearer $T" \
      | python3 -c "import sys,json;u=json.load(sys.stdin);print(u[0]['id'] if u else '')")
    [[ -z "$UID" ]] && { echo "✗ User $EMAIL nicht gefunden"; exit 1; }
    GID=$(curl -fsS "$KC_BASE/admin/realms/$KC_REALM/groups?search=solution-${NAME}-users" \
      -H "Authorization: Bearer $T" \
      | python3 -c "import sys,json;g=json.load(sys.stdin);print(g[0]['id'] if g else '')")
    [[ -z "$GID" ]] && { echo "✗ Group für solution-${NAME} fehlt"; exit 1; }
    curl -fsS -X PUT "$KC_BASE/admin/realms/$KC_REALM/users/$UID/groups/$GID" \
      -H "Authorization: Bearer $T"
    echo "✓ $EMAIL hat jetzt Zugriff auf solution-${NAME}"
    ;;

  list)
    T=$(token)
    curl -fsS "$KC_BASE/admin/realms/$KC_REALM/clients?search=true&clientId=solution-" \
      -H "Authorization: Bearer $T" \
      | python3 -c "
import sys,json
for c in json.load(sys.stdin):
    print(f\"  {c['clientId']:40s} {c.get('description','')}\")"
    ;;

  *)
    cat <<EOF
Usage: $0 <command>

  auth                          Admin Login (einmalig pro 5 min)
  create <name> [desc] [port]   Keycloak Client + Group anlegen
  invite <name> <email>         User für Solution freischalten
  list                          alle eigenen Solutions in Keycloak
EOF
    ;;
esac
