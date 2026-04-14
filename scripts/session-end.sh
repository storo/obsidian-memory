#!/usr/bin/env bash
# SessionEnd hook: create a stub session log that Claude will fill in via
# the `save` skill if it hasn't already. The log gets a timestamp and a
# placeholder — if Claude already wrote a richer log earlier in the session,
# we skip.

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || exit 0

TODAY="$(today_iso)"
TS="$(today_ts)"
LOG_DIR="$VAULT/logs"
STUB="$LOG_DIR/${TODAY}-session-end.md"

# If a log for today already exists with real content (>200 bytes), don't
# overwrite — portable across GNU/BSD stat.
if ls "$LOG_DIR/${TODAY}-"*.md >/dev/null 2>&1; then
  newest=$(ls -t "$LOG_DIR/${TODAY}-"*.md 2>/dev/null | head -1)
  if [ -n "$newest" ]; then
    size=$(stat -c %s "$newest" 2>/dev/null || stat -f %z "$newest" 2>/dev/null || echo 0)
    if [ "$size" -gt 200 ]; then
      exit 0
    fi
  fi
fi

cat > "$STUB" <<EOF
---
title: Session ended $TODAY
tags: [log, session, auto-generated]
created: $TS
type: session-log
---

# Session ended $TODAY

_Auto-generated stub by \`SessionEnd\` hook. Fill in manually or with \`/obsidian-memory:save\` next session._

## Summary
(not captured — session ended without explicit /save)

## Decisions
(none recorded)

## Files touched
(not captured)
EOF

exit 0
