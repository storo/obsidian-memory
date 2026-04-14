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
