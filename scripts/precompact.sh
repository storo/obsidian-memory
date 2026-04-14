#!/usr/bin/env bash
# PreCompact hook: before context compaction, persist a snapshot marker to
# logs/now.md so the next SessionStart bundle shows where we left off.

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || exit 0

NOW_FILE="$VAULT/logs/now.md"
TS="$(today_ts)"

# Append a compaction marker to the continuous buffer so Claude knows the
# prior context was compacted around this time. The file is append-only —
# the `save` skill rotates/clears it.
{
  if [ ! -f "$NOW_FILE" ]; then
    echo "# logs/now.md — continuous buffer"
    echo ""
    echo "_Written by PreCompact hook and \`/obsidian-memory:save\`. Cleared when a full session log is committed._"
    echo ""
  fi
  echo "## compact-marker · $TS"
  echo ""
  echo "Context was compacted here. Prior turns may be summarized."
  echo ""
} >> "$NOW_FILE"

exit 0
