#!/usr/bin/env bash
# SessionStart hook: emit a compact context bundle that Claude ingests as
# initial context for the session. Never fails — errors go to the log.

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || { echo "obsidian-memory: vault missing at $VAULT"; exit 0; }

TODAY="$(today_iso)"
BUDGET_CHARS=8000   # ~2000 tokens ceiling for the whole bundle

emit_section() {
  local title="$1"
  local body="$2"
  [ -z "$body" ] && return
  printf '\n## %s\n\n%s\n' "$title" "$body"
}

truncate_chars() {
  local input="$1"
  local max="$2"
  if [ "${#input}" -gt "$max" ]; then
    printf '%s\n\n…(truncated)' "${input:0:$max}"
  else
    printf '%s' "$input"
  fi
}

# 1. user profile
PROFILE=""
if [ -f "$VAULT/permanent/user-profile.md" ]; then
  PROFILE=$(cat "$VAULT/permanent/user-profile.md" 2>/dev/null)
fi

# 2. MEMORY.md index
INDEX=""
if [ -f "$VAULT/MEMORY.md" ]; then
  INDEX=$(head -50 "$VAULT/MEMORY.md" 2>/dev/null)
fi

# 3. logs/now.md continuous buffer
NOW=""
if [ -f "$VAULT/logs/now.md" ]; then
  NOW=$(cat "$VAULT/logs/now.md" 2>/dev/null)
fi

# 4. last 3 session logs (excluding now.md)
RECENT_LOGS=""
if [ -d "$VAULT/logs" ]; then
  mapfile -t RECENT < <(find "$VAULT/logs" -maxdepth 1 -type f -name '20*.md' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -3 | awk '{print $2}')
  for f in "${RECENT[@]}"; do
    [ -n "$f" ] || continue
    RECENT_LOGS+=$'\n### '"$(basename "$f" .md)"$'\n'
    RECENT_LOGS+=$(head -40 "$f" 2>/dev/null)
    RECENT_LOGS+=$'\n'
  done
fi

# 5. decisions due for review today or earlier
DUE_REVIEWS=""
if [ -d "$VAULT/decisions" ]; then
  while IFS= read -r -d '' file; do
    review_date=$(grep -m1 '^review_date:' "$file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    status=$(grep -m1 '^status:' "$file" 2>/dev/null | awk '{print $2}' | tr -d '"')
    [ "$status" != "active" ] && continue
    [ -z "$review_date" ] && continue
    if [[ "$review_date" < "$TODAY" || "$review_date" == "$TODAY" ]]; then
      title=$(grep -m1 '^title:' "$file" 2>/dev/null | sed 's/^title: *//' | tr -d '"')
      [ -z "$title" ] && title="$(basename "$file" .md)"
      DUE_REVIEWS+="- [[$(basename "$file" .md)]] — $title (review: $review_date)"$'\n'
    fi
  done < <(find "$VAULT/decisions" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
fi

# assemble bundle
{
  echo "# obsidian-memory session context"
  echo ""
  echo "_Vault: \`$VAULT\` · loaded at $(today_ts)_"

  [ -n "$PROFILE" ]     && emit_section "User profile"        "$(truncate_chars "$PROFILE" 1500)"
  [ -n "$NOW" ]         && emit_section "Continuous buffer (logs/now.md)" "$(truncate_chars "$NOW" 2000)"
  [ -n "$RECENT_LOGS" ] && emit_section "Recent session logs" "$(truncate_chars "$RECENT_LOGS" 2500)"
  [ -n "$DUE_REVIEWS" ] && emit_section "Decisions due for review" "$DUE_REVIEWS"
  [ -n "$INDEX" ]       && emit_section "MEMORY.md index"     "$(truncate_chars "$INDEX" 1500)"

  echo ""
  echo "---"
  echo "_To capture work, decisions, or notes during this session, use:_"
  echo "_\`/obsidian-memory:save\` · \`/obsidian-memory:decide\` · \`/obsidian-memory:note\`_"
} | head -c "$BUDGET_CHARS"

exit 0
