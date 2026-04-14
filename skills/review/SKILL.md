---
name: review
description: Lists decisions whose review date has passed and walks the user through renewing or closing each. Use when the user runs `/obsidian-memory:review`, says "review decisions", "what decisions are due", "check pending reviews", or at the start of a session if the SessionStart bundle showed decisions due. Reads `$VAULT/decisions/*.md`, filters by `review_date <= today` and `status: active`, presents each with its original expected outcome vs. what actually happened.
argument-hint: ""
allowed-tools: Bash, Read, Edit
---

# review — process decisions due for review

Decisions are logged with a 30-day review date so you come back and compare _expected_ to _actual_. This skill presents the list and helps the user close each one.

## When to run

- User runs `/obsidian-memory:review`.
- User says "review decisions", "what's pending", "check decisions", "any decisions due".
- **Proactively**: at session start if the `SessionStart` bundle's "Decisions due for review" section was non-empty, offer: "There are N decisions due for review — want to go through them?"

## How to run

1. Collect candidate decisions:

   ```bash
   TODAY=$(date +%Y-%m-%d)
   VAULT="${OBSIDIAN_MEMORY_VAULT:-$HOME/vault}"
   grep -l '^status: active$' "$VAULT"/decisions/*.md 2>/dev/null | while read f; do
     rv=$(grep -m1 '^review_date:' "$f" | awk '{print $2}')
     if [[ "$rv" < "$TODAY" || "$rv" == "$TODAY" ]]; then
       echo "$f"
     fi
   done
   ```

2. For each file found, use `Read` to load the full content.

3. Present to the user as a numbered list, one decision per entry:

   ```
   N. <title> (created YYYY-MM-DD, review YYYY-MM-DD)
      Reasoning: <one line>
      Expected: <one line>
   ```

   Keep each entry to 3-4 lines. Don't dump the whole file.

4. Ask the user to choose for each (one at a time, or all at once — their preference):

   - **Renew** (`r`): push `review_date` by another 30 days.
   - **Close as successful** (`s`): expected outcome matched → set `status: closed-success`, add a `## Outcome` section with what happened.
   - **Close as failed** (`f`): expected didn't match → `status: closed-failed`, `## Outcome` section explains why.
   - **Skip** (`x`): leave alone, do nothing.

5. Apply the user's choice via `Edit` on the corresponding file:

   - **Renew**: update `review_date` to `+30d` from today.
   - **Close success / failed**: update `status`, append `## Outcome` section with what the user told you.
   - **Skip**: no-op.

6. After all decisions are processed, summarize: _"Renewed N, closed-success M, closed-failed K, skipped J."_

## Rules

- **Never batch-close without asking**. Each decision gets an explicit verdict.
- **Preserve original content**. Never rewrite the Decision/Reasoning/Expected sections — only append to Outcome and modify `status`/`review_date` in frontmatter.
- **If no decisions are due**, say so in one sentence and stop.
- **Wikilinks** if the user wants you to cross-reference related decisions or logs.

## Failure handling

If `$VAULT/decisions/` doesn't exist, the skill exits with: "No decisions directory found at $VAULT/decisions/. Run migration first." — do not create it silently.
