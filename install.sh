#!/usr/bin/env bash
# Clever Solution Installer
# https://code.clevercompany.ai/install
#
# Installiert Guides + opencode-Agent + Scripts ohne Repo-Klon.
#
# Usage:
#   curl -fsSL https://code.clevercompany.ai/install | bash
set -euo pipefail

INSTALLER_BASE="${CLEVER_INSTALLER_BASE:-https://code.clevercompany.ai}"
CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.config/opencode}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }
step() { echo; echo -e "→ $1"; }

# ----------------------------------------------------------------------------
step "Pre-flight checks"
for cmd in bash curl python3 openssl; do
  command -v $cmd >/dev/null || err "$cmd is required"
done
ok "core tools available"

if ! command -v opencode >/dev/null; then
  warn "opencode noch nicht installiert"
  echo "    Nach diesem Script ausführen:"
  echo "    curl -fsSL https://opencode.ai/install | bash"
fi
if ! command -v docker >/dev/null; then
  warn "docker fehlt - wird für lokales Testen benötigt"
fi

# ----------------------------------------------------------------------------
step "Verzeichnisse anlegen"
mkdir -p "$CLEVER_HOME"/{scripts,solutions,guides/recipes}
mkdir -p "$OPENCODE_DIR"/{agent,command}

# ----------------------------------------------------------------------------
step "Guides + Agent + Scripts laden"

fetch() {
  local src="$1"; local dst="$2"
  curl -fsSL "$INSTALLER_BASE/$src" -o "$dst" || err "Download fehlgeschlagen: $src"
}

# Guides (Quelle der Wahrheit)
fetch "guides/brand.md"               "$CLEVER_HOME/guides/brand.md"
fetch "guides/architecture.md"        "$CLEVER_HOME/guides/architecture.md"
fetch "guides/conventions.md"         "$CLEVER_HOME/guides/conventions.md"
fetch "guides/recipes/auth-page.md"   "$CLEVER_HOME/guides/recipes/auth-page.md"
fetch "guides/recipes/crud.md"        "$CLEVER_HOME/guides/recipes/crud.md"

# opencode Integration
fetch "agent/clever-solution.md"      "$OPENCODE_DIR/agent/clever-solution.md"
fetch "command/new-solution.md"       "$OPENCODE_DIR/command/new-solution.md"
fetch "command/invite.md"             "$OPENCODE_DIR/command/invite.md"

# Scripts
fetch "scripts/clever"                "$CLEVER_HOME/scripts/clever"
fetch "scripts/keycloak-client.sh"    "$CLEVER_HOME/scripts/keycloak-client.sh"

chmod +x "$CLEVER_HOME/scripts/"*
ok "alle Files installiert"

# ----------------------------------------------------------------------------
step "clever Command verlinken"

if [ -d "$HOME/.local/bin" ] && echo ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
  BIN_DIR="$HOME/.local/bin"
elif [ -w "/usr/local/bin" ]; then
  BIN_DIR="/usr/local/bin"
else
  mkdir -p "$HOME/.local/bin"
  BIN_DIR="$HOME/.local/bin"
  warn "Bitte zur Shell-Konfig hinzufügen:"
  echo '    export PATH="$HOME/.local/bin:$PATH"'
fi

ln -sf "$CLEVER_HOME/scripts/clever" "$BIN_DIR/clever"
ok "clever -> $BIN_DIR/clever"

# ----------------------------------------------------------------------------
step "Fertig!"
cat <<EOF

  ${GREEN}════════════════════════════════════════════════════════════${NC}
  ${GREEN}  Clever Toolchain installiert${NC}
  ${GREEN}════════════════════════════════════════════════════════════${NC}

  Nächste Schritte:

  ${YELLOW}1. opencode installieren${NC} (falls noch nicht)
     curl -fsSL https://opencode.ai/install | bash

  ${YELLOW}2. Keycloak Login einrichten${NC} (einmalig pro 5min)
     clever auth

  ${YELLOW}3. Erste Solution erstellen${NC}
     clever new my-first-solution
     ${NC}# oder direkt:${NC}
     opencode "neue Clever Solution namens my-first-solution"

  Guides:    $CLEVER_HOME/guides/
  Online:    $INSTALLER_BASE/

EOF
