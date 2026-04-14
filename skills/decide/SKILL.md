---
name: decide
description: Records a decision in the Obsidian vault with a 30-day review date. Use when the user runs `/obsidian-memory:decide "text"`, says "log this decision", "remember we decided X", "track this choice", or when the conversation clearly takes a non-trivial technical or product decision that should be revisited later. Creates `$VAULT/decisions/YYYY-MM-DD-<slug>.md` with structured frontmatter.
argument-hint: "\"decision title\" [\"reasoning\"] [\"expected outcome\"]"
allowed-tools: Bash, Read, Edit
---

# decide — log a reviewable decision

Decisions without review dates rot. This skill records a decision with structured metadata so `/obsidian-memory:review` can surface it 30 days later to ask: did the expected outcome match reality?

## When to run

- User runs `/obsidian-memory:decide "..."`.
- User says "remember we decided", "log this decision", "track this choice", "write this down".
- **Proactively**: when you notice the conversation just resolved a non-trivial trade-off (architecture, tooling, stack, process, naming, API shape), ask the user: "Want me to log this as a decision with 30-day review?" — and run the skill if yes.

Do NOT run this for trivial choices (variable naming, local code style) — decisions should be things worth revisiting.

## How to run

1. Parse `$ARGUMENTS` into title, reasoning, expected outcome. Typical formats:

   - `"title only"` — just the title.
   - `"title" "reasoning"` — title + why.
   - `"title" "reasoning" "expected outcome"` — full triple.

   If the user provided only a title, extract reasoning and expected outcome from the prior conversation turns — you have context. Don't ask the user unless the conversation truly lacks it.

2. Invoke the helper script:

   ```bash
   FILE=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/decide.sh" "$TITLE" "$REASONING" "$EXPECTED")
   ```

   The script creates `decisions/YYYY-MM-DD-<slug>.md` with:

   - `title`, `created`, `review_date` (+30d), `status: active`, `type: decision` in frontmatter.
   - Sections: Decision, Reasoning, Expected outcome, Review, Related.
   - Prints the absolute path to stdout.

3. **Read** the generated file and **Edit** it to enrich:

   - If the reasoning or expected outcome placeholders still read `_(to be filled in)_`, fill them from conversation context.
   - Under `## Related`, add `[[wikilinks]]` to any vault notes that are contextually relevant (recent session logs, prior decisions, permanent notes on the same topic). Use `Read` on `$VAULT/MEMORY.md` to discover candidates.

4. Confirm to the user: `Decision logged: <filename> — review on <date>`. Nothing else.

## Rules

- **One decision per note**. Atomic.
- **Frontmatter is sacred**: never edit `created`, `review_date`, or `status` in the file you just generated — the script sets them correctly.
- **30 days is the default review window**. If the user explicitly asks for a different window (e.g., "review in a week"), you cannot pass that through the script — instead, edit `review_date` after the script runs.
- **No secrets** in the decision body.
- **Wikilinks** for references, never markdown links.

## Failure handling

Script non-zero → report error verbatim, do not retry.
