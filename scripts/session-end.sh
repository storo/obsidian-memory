#!/usr/bin/env bash
# SessionEnd hook: extract the current session's JSONL into a markdown log.
# Also fires when /clear is invoked (per Claude Code docs — SessionEnd is
# the closest built-in event to a pre-clear save point).
#
# Idempotent: if a log for "session-end" already exists for today with the
# same session_id in its frontmatter, this run is a no-op. That prevents
# overwriting content Claude Code may have written via the save skill.

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || exit 0

# Only skip if a non-trivial log already exists for today — the extractor
# will always produce something useful even for short sessions.
TODAY="$(today_iso)"
LOG_DIR="$VAULT/logs"
if ls "$LOG_DIR/${TODAY}-session-end"*.md >/dev/null 2>&1; then
  newest=$(ls -t "$LOG_DIR/${TODAY}-session-end"*.md 2>/dev/null | head -1)
  if [ -n "$newest" ]; then
    size=$(stat -c %s "$newest" 2>/dev/null || stat -f %z "$newest" 2>/dev/null || echo 0)
    [ "$size" -gt 500 ] && exit 0
  fi
fi

extract_session_to_log "session-end" "session-end" >/dev/null 2>&1 || true

# Rotate now.md if non-empty (PreCompact appends there)
NOW_FILE="$VAULT/logs/now.md"
if [ -f "$NOW_FILE" ] && [ -s "$NOW_FILE" ]; then
  mv "$NOW_FILE" "${NOW_FILE}.bak"
fi

exit 0
