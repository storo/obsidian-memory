#!/usr/bin/env bash
# Create a decision note in $VAULT/decisions/ with a 30-day review date.
# Usage: decide.sh "decision title" [reasoning] [expected_outcome]

set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ensure_vault || { echo "vault missing at $VAULT"; exit 1; }

TITLE="${1:?usage: decide.sh \"title\" [reasoning] [expected_outcome]}"
REASONING="${2:-}"
EXPECTED="${3:-}"

TODAY="$(today_iso)"
REVIEW="$(days_from_now 30)"
SLUG="$(slugify "$TITLE")"
FILE="$VAULT/decisions/${TODAY}-${SLUG}.md"

if [ -e "$FILE" ]; then
  # append a suffix to avoid clobbering
  FILE="$VAULT/decisions/${TODAY}-${SLUG}-$(date +%H%M%S).md"
fi

PROJECT_SLUG="$(current_project_slug)"

{
  echo "---"
  echo "title: $TITLE"
  if [ -n "$PROJECT_SLUG" ]; then
    echo "tags: [decision, project/$PROJECT_SLUG]"
  else
    echo "tags: [decision]"
  fi
  echo "created: $TODAY"
  echo "review_date: $REVIEW"
  echo "status: active"
  echo "type: decision"
  if [ -n "$PROJECT_SLUG" ]; then
    echo "project: $PROJECT_SLUG"
  fi
  echo "---"
  echo ""
  echo "# $TITLE"
  echo ""
  echo "## Decision"
  echo "$TITLE"
  echo ""
  echo "## Reasoning"
  echo "${REASONING:-_(to be filled in)_}"
  echo ""
  echo "## Expected outcome"
  echo "${EXPECTED:-_(to be filled in)_}"
  echo ""
  echo "## Review ($REVIEW)"
  echo "_Left open — compare expected vs actual on review date._"
  echo ""
  echo "## Related"
  echo "_Link related notes with \`[[wikilinks]]\`._"
} > "$FILE"

SLUG_DATE="${TODAY}-${SLUG}"
ENTRY="- [[$SLUG_DATE]] — $TITLE · review $REVIEW"

# Insert entry into MEMORY.md. Python helper because sed with arbitrary
# titles is a minefield (special chars, unicode, etc.).
insert_entry() {
  local memory_path="$1"
  local entry="$2"
  python3 - "$memory_path" "$entry" <<'PYEOF'
import sys, pathlib
path, entry = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text() if path.exists() else ""
lines = text.splitlines(keepends=True)
# insert after "## Decisions" if present
for i, line in enumerate(lines):
    if line.rstrip() == "## Decisions":
        lines.insert(i + 1, entry + "\n")
        path.write_text("".join(lines))
        sys.exit(0)
# else insert a new section before "## Reference" if present
for i, line in enumerate(lines):
    if line.rstrip() == "## Reference":
        lines.insert(i, "## Decisions\n" + entry + "\n\n")
        path.write_text("".join(lines))
        sys.exit(0)
# else append at end
if text and not text.endswith("\n"):
    text += "\n"
text += "\n## Decisions\n" + entry + "\n"
path.write_text(text)
PYEOF
}

# Route the index entry:
#   - If we're inside a project, write to projects/<slug>/MEMORY.md.
#     Global MEMORY.md is reserved for cross-project decisions (tooling,
#     workflow rules, etc.) to keep per-project noise out of the bundle.
#   - If no project detected, write to global MEMORY.md.
if [ -n "$PROJECT_SLUG" ]; then
  PROJECT_MEMORY_DIR="$VAULT/projects/$PROJECT_SLUG"
  PROJECT_MEMORY="$PROJECT_MEMORY_DIR/MEMORY.md"
  mkdir -p "$PROJECT_MEMORY_DIR" 2>/dev/null
  if [ ! -f "$PROJECT_MEMORY" ]; then
    cat > "$PROJECT_MEMORY" <<EOF
---
title: MEMORY — $PROJECT_SLUG
tags: [project/$PROJECT_SLUG, memory-index]
type: memory-index
project: $PROJECT_SLUG
---

# MEMORY — $PROJECT_SLUG

_Auto-maintained index of decisions and notes tagged to this project._

## Decisions
EOF
  fi
  insert_entry "$PROJECT_MEMORY" "$ENTRY"
else
  MEMORY="$VAULT/MEMORY.md"
  [ -f "$MEMORY" ] && insert_entry "$MEMORY" "$ENTRY"
fi

echo "$FILE"
exit 0
