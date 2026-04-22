#!/usr/bin/env bash
# Shared utilities for obsidian-memory scripts.
# Source this from every script: source "$(dirname "$0")/lib/common.sh"
#
# Defensive by default: never exits the parent shell on error, always logs
# failures to $VAULT/logs/hook-errors.log so hooks don't block sessions.

set +e

# -------- vault resolution --------
resolve_vault() {
  if [ -n "${OBSIDIAN_MEMORY_VAULT:-}" ]; then
    echo "$OBSIDIAN_MEMORY_VAULT"
    return 0
  fi
  local override_file="$HOME/.claude/obsidian-memory.local.md"
  if [ -f "$override_file" ]; then
    local path
    path=$(grep -v '^#' "$override_file" | grep -v '^$' | head -1 | tr -d '[:space:]')
    if [ -n "$path" ]; then
      echo "${path/#\~/$HOME}"
      return 0
    fi
  fi
  echo "$HOME/vault"
}

VAULT="$(resolve_vault)"
export VAULT

# -------- logging --------
log_error() {
  local msg="$1"
  local log_dir="$VAULT/logs"
  mkdir -p "$log_dir" 2>/dev/null
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $msg" >> "$log_dir/hook-errors.log" 2>/dev/null
}

# -------- slug helper --------
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g' \
    | sed -E 's/^-+|-+$//g' \
    | cut -c1-60
}

# -------- today helpers --------
today_iso() { date +%Y-%m-%d; }
today_ts() { date +%Y-%m-%dT%H:%M:%S%z; }
days_from_now() { date -d "+$1 days" +%Y-%m-%d 2>/dev/null || date -v "+${1}d" +%Y-%m-%d; }

# -------- vault precheck --------
ensure_vault() {
  if [ ! -d "$VAULT" ]; then
    log_error "vault directory missing at $VAULT"
    return 1
  fi
  mkdir -p "$VAULT/logs" "$VAULT/inbox" "$VAULT/decisions" 2>/dev/null
  return 0
}

# -------- project slug detection --------
# Derive a stable project slug from $CLAUDE_PROJECT_DIR (or $PWD fallback).
# Mirrors extract-session.py:detect_project so logs and decisions agree on
# the slug for a given cwd.
#
# Only matches the convention `<anything>/projects/<name>/...` — which is
# where the user keeps work repos. Everything else (~/, /tmp, arbitrary
# paths) returns empty, which the callers treat as "no project context"
# and route to the global index instead of inventing a slug from a
# generic basename.
#
# $OBSIDIAN_MEMORY_PROJECT acts as an override for cases where the repo
# lives outside ~/projects/ but the user still wants project routing.
#
# Output is lowercased.
current_project_slug() {
  if [ -n "${OBSIDIAN_MEMORY_PROJECT:-}" ]; then
    echo "$OBSIDIAN_MEMORY_PROJECT" | tr '[:upper:]' '[:lower:]'
    return 0
  fi
  local cwd="${CLAUDE_PROJECT_DIR:-${PWD:-}}"
  [ -z "$cwd" ] && return 0
  if [[ "$cwd" == */projects/* ]]; then
    local tail="${cwd#*/projects/}"
    echo "${tail%%/*}" | sed 's/^\.*//' | tr '[:upper:]' '[:lower:]'
    return 0
  fi
}

# -------- locate current session JSONL --------
# Claude Code stores raw conversation logs at
#   $HOME/.claude/projects/<slug>/<session-id>.jsonl
# where <slug> is the project's working directory with slashes replaced by
# hyphens — NOT $HOME. Each project Claude Code is launched from has its
# own slug directory.
#
# Resolution order for the "current project":
#   1. $CLAUDE_PROJECT_DIR — set by Claude Code in hook env (authoritative)
#   2. $PWD — shell's current directory when script was invoked
#   3. $HOME — last-resort fallback
#
# Within the resolved slug dir, "current session jsonl" = most recently
# modified *.jsonl file.
find_current_jsonl() {
  local project="${CLAUDE_PROJECT_DIR:-${PWD:-$HOME}}"
  local slug
  slug="$(echo "$project" | tr '/' '-')"
  local dir="$HOME/.claude/projects/${slug}"
  if [ ! -d "$dir" ]; then
    log_error "find_current_jsonl: dir not found for project '$project' -> $dir"
    echo ""
    return 1
  fi
  local latest
  latest=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
  echo "$latest"
  [ -n "$latest" ]
}

# -------- extract session JSONL into a vault log --------
# Usage: extract_session_to_log <output_name_without_ext> [reason]
# Writes the extracted markdown to $VAULT/logs/<YYYY-MM-DD>-<name>.md and
# prints the resulting path. Returns 0 on success, 1 on failure.
extract_session_to_log() {
  local name="${1:-session}"
  local reason="${2:-session-end}"
  local jsonl
  jsonl=$(find_current_jsonl)
  if [ -z "$jsonl" ] || [ ! -f "$jsonl" ]; then
    log_error "no jsonl found for current session"
    return 1
  fi

  local slug today out
  slug=$(slugify "$name")
  today=$(today_iso)
  out="$VAULT/logs/${today}-${slug}.md"
  if [ -e "$out" ]; then
    out="$VAULT/logs/${today}-${slug}-$(date +%H%M%S).md"
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if python3 "$script_dir/extract-session.py" "$jsonl" "$out" "$reason" >/dev/null 2>>"$VAULT/logs/hook-errors.log"; then
    echo "$out"
    return 0
  fi
  log_error "extract-session.py failed for $jsonl"
  return 1
}
