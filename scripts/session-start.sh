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

# Derive the current project slug from CLAUDE_PROJECT_DIR (or PWD fallback),
# using the same heuristic as extract-session.py:detect_project:
#   prefer `projects/<name>` path segment, else basename (skipping dot-dirs).
current_project_slug() {
  local cwd="${CLAUDE_PROJECT_DIR:-${PWD:-}}"
  [ -z "$cwd" ] && return 0
  # projects/<name> segment
  if [[ "$cwd" == */projects/* ]]; then
    local tail="${cwd#*/projects/}"
    echo "${tail%%/*}" | tr '[:upper:]' '[:lower:]'
    return 0
  fi
  # fallback: basename, skipping trailing dot-dirs
  local path="$cwd"
  while [ -n "$path" ]; do
    local base="${path##*/}"
    if [ -n "$base" ] && [[ "$base" != .* ]]; then
      echo "$base" | tr '[:upper:]' '[:lower:]'
      return 0
    fi
    [ "$path" = "/" ] && break
    path="${path%/*}"
    [ -z "$path" ] && break
  done
}

# Does this log file belong to the current project?
# Match order:
#   1. `project: <slug>` frontmatter field (logs written after v0.2)
#   2. `Working dirs: ...` line mentioning the current cwd (legacy logs)
#   3. slug appears in the filename (legacy fallback)
log_matches_project() {
  local file="$1"
  local slug="$2"
  local cwd="$3"
  [ -z "$slug" ] && return 0   # no filter → everything matches
  # 1. frontmatter project: field
  if grep -q -m1 -iE "^project: *\"?${slug}\"? *$" "$file" 2>/dev/null; then
    return 0
  fi
  # 2. legacy Working dirs line contains cwd
  if [ -n "$cwd" ] && grep -q -F -m1 "$cwd" "$file" 2>/dev/null; then
    return 0
  fi
  # 3. filename contains slug (as a word — hyphen-delimited)
  local base
  base="$(basename "$file" .md)"
  if [[ "-${base}-" == *"-${slug}-"* ]]; then
    return 0
  fi
  return 1
}

PROJECT_SLUG="$(current_project_slug)"
PROJECT_CWD="${CLAUDE_PROJECT_DIR:-${PWD:-}}"

# 1. user profile
PROFILE=""
if [ -f "$VAULT/permanent/user-profile.md" ]; then
  PROFILE=$(cat "$VAULT/permanent/user-profile.md" 2>/dev/null)
fi

# 2. MEMORY.md index — global first, then per-project if it exists
INDEX=""
if [ -f "$VAULT/MEMORY.md" ]; then
  INDEX=$(head -50 "$VAULT/MEMORY.md" 2>/dev/null)
fi
PROJECT_INDEX=""
if [ -n "$PROJECT_SLUG" ] && [ -f "$VAULT/projects/$PROJECT_SLUG/MEMORY.md" ]; then
  PROJECT_INDEX=$(head -80 "$VAULT/projects/$PROJECT_SLUG/MEMORY.md" 2>/dev/null)
fi

# 3. logs/now.md continuous buffer
NOW=""
if [ -f "$VAULT/logs/now.md" ]; then
  NOW=$(cat "$VAULT/logs/now.md" 2>/dev/null)
fi

# 4. last 3 session logs for the current project — fall back to 3 most
# recent global logs when the filter yields nothing (e.g. brand new project).
RECENT_LOGS=""
FALLBACK_NOTE=""
if [ -d "$VAULT/logs" ]; then
  # All logs sorted by mtime desc
  mapfile -t ALL_LOGS < <(
    find "$VAULT/logs" -maxdepth 1 -type f -name '20*.md' 2>/dev/null \
      | while read -r f; do
          mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
          echo "$mtime $f"
        done \
      | sort -rn | awk '{$1=""; sub(/^ /,""); print}'
  )

  MATCHED=()
  for f in "${ALL_LOGS[@]}"; do
    [ -n "$f" ] || continue
    if log_matches_project "$f" "$PROJECT_SLUG" "$PROJECT_CWD"; then
      MATCHED+=("$f")
      [ "${#MATCHED[@]}" -ge 3 ] && break
    fi
  done

  if [ "${#MATCHED[@]}" -eq 0 ] && [ -n "$PROJECT_SLUG" ]; then
    # No logs for this project — fall back to 3 most recent globally,
    # but flag it so Claude knows the context isn't project-specific.
    FALLBACK_NOTE="_No prior session logs for project \`$PROJECT_SLUG\` — showing the 3 most recent logs instead._"$'\n'
    MATCHED=("${ALL_LOGS[@]:0:3}")
  fi

  for f in "${MATCHED[@]}"; do
    [ -n "$f" ] || continue
    RECENT_LOGS+=$'\n### '"$(basename "$f" .md)"$'\n'
    RECENT_LOGS+=$(head -40 "$f" 2>/dev/null)
    RECENT_LOGS+=$'\n'
  done

  if [ -n "$FALLBACK_NOTE" ] && [ -n "$RECENT_LOGS" ]; then
    RECENT_LOGS="${FALLBACK_NOTE}${RECENT_LOGS}"
  fi
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
  if [ -n "$PROJECT_SLUG" ]; then
    echo "_Project: \`$PROJECT_SLUG\` (cwd: \`$PROJECT_CWD\`)_"
  fi

  [ -n "$PROFILE" ]       && emit_section "User profile"         "$(truncate_chars "$PROFILE" 1500)"
  [ -n "$NOW" ]           && emit_section "Continuous buffer (logs/now.md)" "$(truncate_chars "$NOW" 2000)"
  [ -n "$RECENT_LOGS" ]   && emit_section "Recent session logs"  "$(truncate_chars "$RECENT_LOGS" 2500)"
  [ -n "$DUE_REVIEWS" ]   && emit_section "Decisions due for review" "$DUE_REVIEWS"
  [ -n "$PROJECT_INDEX" ] && emit_section "Project MEMORY ($PROJECT_SLUG)" "$(truncate_chars "$PROJECT_INDEX" 1500)"
  [ -n "$INDEX" ]         && emit_section "MEMORY.md index"      "$(truncate_chars "$INDEX" 1500)"

  echo ""
  echo "---"
  echo "_To capture work, decisions, or notes during this session, use:_"
  echo "_\`/obsidian-memory:save\` · \`/obsidian-memory:decide\` · \`/obsidian-memory:note\`_"
} | head -c "$BUDGET_CHARS"

exit 0
