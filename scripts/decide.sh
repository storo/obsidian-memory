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

cat > "$FILE" <<EOF
---
title: $TITLE
tags: [decision]
created: $TODAY
review_date: $REVIEW
status: active
type: decision
---

# $TITLE

## Decision
$TITLE

## Reasoning
${REASONING:-_(to be filled in)_}

## Expected outcome
${EXPECTED:-_(to be filled in)_}

## Review ($REVIEW)
_Left open — compare expected vs actual on review date._

## Related
_Link related notes with \`[[wikilinks]]\`._
EOF

# Update MEMORY.md index
MEMORY="$VAULT/MEMORY.md"
if [ -f "$MEMORY" ]; then
  SLUG_DATE="${TODAY}-${SLUG}"
  ENTRY="- [[$SLUG_DATE]] — $TITLE · review $REVIEW"
  if grep -q "^## Decisions" "$MEMORY"; then
    # Use python to safely insert after "## Decisions" (avoids sed special-char issues)
    python3 - "$MEMORY" "$ENTRY" <<'PYEOF'
import sys, pathlib
path, entry = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = path.read_text().splitlines(keepends=True)
out = []
inserted = False
for line in lines:
    out.append(line)
    if not inserted and line.rstrip() == "## Decisions":
        out.append(entry + "\n")
        inserted = True
path.write_text("".join(out))
PYEOF
  else
    # Append new Decisions section before ## Reference, or at end
    python3 - "$MEMORY" "$ENTRY" <<'PYEOF'
import sys, pathlib
path, entry = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = path.read_text().splitlines(keepends=True)
section = "## Decisions\n" + entry + "\n\n"
for i, line in enumerate(lines):
    if line.rstrip() == "## Reference":
        lines.insert(i, section)
        path.write_text("".join(lines))
        sys.exit(0)
path.write_text("".join(lines) + "\n" + section)
PYEOF
  fi
fi

echo "$FILE"
exit 0
