#!/usr/bin/env bash
# Append a quick note to $VAULT/inbox/YYYY-MM-DD.md
# Usage: note.sh "text to capture"

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || { echo "vault missing at $VAULT"; exit 1; }

TEXT="${1:?usage: note.sh \"text\"}"
TODAY="$(today_iso)"
TS="$(date +%H:%M:%S)"
FILE="$VAULT/inbox/${TODAY}.md"

if [ ! -f "$FILE" ]; then
  cat > "$FILE" <<EOF
---
title: Inbox $TODAY
tags: [inbox]
created: $TODAY
type: inbox
---

# Inbox $TODAY

EOF
fi

printf '\n## %s\n\n%s\n' "$TS" "$TEXT" >> "$FILE"
echo "$FILE"
exit 0
