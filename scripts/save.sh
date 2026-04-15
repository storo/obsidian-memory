#!/usr/bin/env bash
# Extract the current Claude Code session JSONL into a markdown session log.
# Reads raw conversation history from
#   $HOME/.claude/projects/<slug>/*.jsonl
# and generates a queryable index under $VAULT/logs/.
#
# If Claude wants to add narrative/decisions/next-steps on top of the
# auto-generated index, it edits the file after this script returns.
#
# Usage: save.sh [title]

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || { echo "vault missing at $VAULT"; exit 1; }

TITLE="${1:-session}"

OUT=$(extract_session_to_log "$TITLE" "save")
if [ -z "$OUT" ]; then
  # JSONL not found or extractor failed — fall back to a minimal stub so the
  # user still gets a file they can edit.
  TODAY="$(today_iso)"
  SLUG="$(slugify "$TITLE")"
  OUT="$VAULT/logs/${TODAY}-${SLUG}.md"
  [ -e "$OUT" ] && OUT="$VAULT/logs/${TODAY}-${SLUG}-$(date +%H%M%S).md"
  cat > "$OUT" <<EOF
---
title: $TITLE
tags: [log, session, stub]
created: $(today_ts)
reason: save-fallback
type: session-log
---

# $TITLE

_Extractor could not read the session JSONL — this is a minimal stub.
Fill in manually._

## Summary

## Decisions

## Files touched

## Next
EOF
fi

# Rotate now.md buffer: move to .bak instead of truncating, so content is
# recoverable if Claude never fills in the log on top of this.
NOW_FILE="$VAULT/logs/now.md"
if [ -f "$NOW_FILE" ] && [ -s "$NOW_FILE" ]; then
  mv "$NOW_FILE" "${NOW_FILE}.bak"
fi

echo "$OUT"
exit 0
