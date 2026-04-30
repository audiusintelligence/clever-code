#!/usr/bin/env bash
# clever add-page <slug> <route> [title]
# Erstellt eine einfache Next.js Page mit Audius-Styling.
set -euo pipefail

SLUG="${1:-}"
ROUTE="${2:-}"
TITLE="${3:-}"
[[ -z "$SLUG" || -z "$ROUTE" ]] && { echo "Usage: clever add-page <slug> <route> [title]"; exit 1; }

ROUTE_CLEAN=$(echo "$ROUTE" | sed 's|^/||; s|/$||')
[[ -z "$TITLE" ]] && TITLE="$(echo $ROUTE_CLEAN | tr '-' ' ' | tr '/' ' ' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) substr($i,2)}1')"

CLEVER_HOME="${CLEVER_HOME:-$HOME/.clever}"
SOLDIR="$CLEVER_HOME/solutions/$SLUG"
[[ ! -d "$SOLDIR" ]] && { echo "✗ Solution '$SLUG' fehlt"; exit 1; }

PAGE_DIR="$SOLDIR/frontend/src/app/$ROUTE_CLEAN"
mkdir -p "$PAGE_DIR"

cat > "$PAGE_DIR/page.tsx" <<EOF
export default function Page() {
  return (
    <main className="min-h-screen p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-audius-navy mb-4">${TITLE}</h1>
        <div className="bg-white rounded-2xl shadow p-8">
          <p className="text-gray-600">Diese Seite ist leer. Inhalt hinzufügen.</p>
        </div>
      </div>
    </main>
  );
}
EOF

echo "✓ Page: frontend/src/app/$ROUTE_CLEAN/page.tsx"
echo "→ make rebuild && open http://localhost:\$(grep PORT_FRONTEND $SOLDIR/.env | cut -d= -f2)/$ROUTE_CLEAN"
