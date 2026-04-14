#!/usr/bin/env bash
# Destructive migration: delete legacy memory locations and create the vault
# + symlink. Idempotent — safe to re-run, but WILL delete unrelated content
# at the legacy paths if present.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

echo "obsidian-memory migration"
echo "========================="
echo "Vault will be: $VAULT"
echo ""

# -------- 1. create vault if missing --------
if [ ! -d "$VAULT" ]; then
  echo "Creating vault at $VAULT"
  mkdir -p "$VAULT"/{permanent,inbox,fleeting,logs,decisions,templates,projects}
  (cd "$VAULT" && git init -q 2>/dev/null || true)
else
  echo "Vault already exists at $VAULT (not recreating)"
  mkdir -p "$VAULT"/{permanent,inbox,fleeting,logs,decisions,templates,projects}
fi

# -------- 2. create symlink from auto-memory hardcoded path --------
AUTO_MEMORY="$HOME/.claude/projects/-home-storo/memory"
AUTO_PARENT="$(dirname "$AUTO_MEMORY")"
mkdir -p "$AUTO_PARENT"

if [ -L "$AUTO_MEMORY" ]; then
  current_target="$(readlink "$AUTO_MEMORY")"
  if [ "$current_target" = "$VAULT" ]; then
    echo "Symlink already points to vault: OK"
  else
    echo "Symlink exists but points to $current_target — removing and relinking"
    rm "$AUTO_MEMORY"
    ln -s "$VAULT" "$AUTO_MEMORY"
  fi
elif [ -e "$AUTO_MEMORY" ]; then
  echo "ERROR: $AUTO_MEMORY exists as a real directory."
  echo "       Migration will NOT auto-delete it. Review its contents and run:"
  echo "         rm -rf \"$AUTO_MEMORY\""
  echo "       then re-run this script."
  exit 2
else
  ln -s "$VAULT" "$AUTO_MEMORY"
  echo "Created symlink: $AUTO_MEMORY -> $VAULT"
fi

# -------- 3. remove legacy ~/.claude/memory/ --------
LEGACY_GLOBAL="$HOME/.claude/memory"
if [ -d "$LEGACY_GLOBAL" ] && [ ! -L "$LEGACY_GLOBAL" ]; then
  echo "Removing legacy $LEGACY_GLOBAL"
  rm -rf "$LEGACY_GLOBAL"
fi

# -------- 4. remove legacy .remember/ dirs in projects --------
for d in "$HOME/.remember" "$HOME"/projects/*/.remember; do
  if [ -d "$d" ]; then
    echo "Removing legacy $d"
    rm -rf "$d"
  fi
done

echo ""
echo "Migration complete."
echo "Vault: $VAULT"
echo "Symlink: $AUTO_MEMORY -> $VAULT"
