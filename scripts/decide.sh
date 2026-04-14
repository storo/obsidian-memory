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

echo "$FILE"
exit 0
