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
    echo "Keycloak Admin Login ($KC_BASE)"
    read -p "  Username: " U
    read -sp "  Password: " P; echo
    T=$(get_token "$U" "$P") || { echo "✗ Login fehlgeschlagen"; exit 1; }
    echo "$T" > "$CLEVER_HOME/admin-token"
    chmod 600 "$CLEVER_HOME/admin-token"
    echo "✓ Token gespeichert (gültig ~5 min)"
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
