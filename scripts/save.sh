#!/usr/bin/env bash
# Create an empty session log scaffold for Claude to fill in.
# Claude owns the content — this script just creates the file with correct
# frontmatter and prints the path so Claude can write to it.
#
# Usage: save.sh [title]

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || { echo "vault missing at $VAULT"; exit 1; }

TITLE="${1:-session}"
TODAY="$(today_iso)"
SLUG="$(slugify "$TITLE")"
FILE="$VAULT/logs/${TODAY}-${SLUG}.md"

if [ -e "$FILE" ]; then
  FILE="$VAULT/logs/${TODAY}-${SLUG}-$(date +%H%M%S).md"
fi

cat > "$FILE" <<EOF
---
title: $TITLE
tags: [log, session]
created: $(today_ts)
type: session-log
---

# $TITLE

## Summary
_(Claude fills this in)_

## Decisions
_(list with \`[[decision-slug]]\` wikilinks to decisions/)_

## Files touched
_(bullet list with repo-relative paths)_

## Next
_(what's left, what to pick up from)_
EOF

# Rotate now.md buffer if it exists and has content
NOW_FILE="$VAULT/logs/now.md"
if [ -f "$NOW_FILE" ] && [ -s "$NOW_FILE" ]; then
  : > "$NOW_FILE"
fi

echo "$FILE"
exit 0
