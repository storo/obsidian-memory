#!/usr/bin/env bash
# UserPromptSubmit hook: opportunistic save-before-clear.
#
# Claude Code's UserPromptSubmit event delivers the user's prompt as JSON on
# stdin. If the prompt matches `/clear` (or `/compact`), extract the current
# session's JSONL into a named log before the built-in command wipes context.
#
# If UserPromptSubmit does NOT fire on built-in commands (uncertain per
# Claude Code docs), this script simply never runs for /clear — and
# SessionEnd still catches it. Belt and suspenders.
#
# Never blocks the session: exits 0 regardless of outcome.

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || exit 0

# Read stdin as JSON if available. Claude Code delivers something like:
#   {"prompt": "...", ...}
# Be defensive: if stdin is empty or not JSON, fall back to checking if
# there are any CLI args that look like a prompt.
PROMPT=""
if [ ! -t 0 ]; then
  RAW=$(cat 2>/dev/null || true)
  if [ -n "$RAW" ]; then
    PROMPT=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('prompt', '') or d.get('user_prompt', '') or '')
except Exception:
    pass
" 2>/dev/null || true)
  fi
fi

# If no prompt on stdin, try CLI args
[ -z "$PROMPT" ] && PROMPT="${1:-}"

# Pattern-match /clear or /compact at the start of the prompt (ignore
# surrounding whitespace, case-insensitive).
PROMPT_TRIMMED=$(echo "$PROMPT" | sed -E 's/^[[:space:]]+//' | head -1)

case "$PROMPT_TRIMMED" in
  /clear*|/compact*)
    # Determine reason tag
    case "$PROMPT_TRIMMED" in
      /clear*)    REASON="pre-clear" ;;
      /compact*)  REASON="pre-compact" ;;
      *)          REASON="pre-slash" ;;
    esac
    extract_session_to_log "$REASON" "$REASON" >/dev/null 2>&1 || true
    ;;
esac

exit 0
