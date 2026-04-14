---
name: save
description: Force-writes a session log to the Obsidian vault right now. Use when the user runs `/obsidian-memory:save`, says "save the session", "log what we did", "write a session log", "checkpoint this", or when a meaningful chunk of work has completed and should be persisted before context compaction. Summarizes work, decisions, files touched, and next steps into `$VAULT/logs/YYYY-MM-DD-<slug>.md`.
argument-hint: "[optional title, e.g. \"auth refactor\"]"
allowed-tools: Bash, Read, Write, Edit
---

# save — write a session log to the vault

This skill persists the current session into the Obsidian vault as an atomic session log. It runs a helper script that creates a scaffolded markdown file, then you (Claude) fill in the real content by editing that file.

## When to run

Run this skill when **any** of these is true:

- The user explicitly asks: `/obsidian-memory:save`, "save this", "log the session", "checkpoint", "write a log of what we did".
- A large piece of work just completed (feature shipped, refactor merged, bug root-caused) and there is real content worth persisting.
- Before a manual `/compact` or when the user says they're wrapping up.
- After a `/obsidian-memory:decide` was run, to capture the surrounding context.

Do NOT run this skill for trivial one-turn interactions — session logs with "fixed a typo" are noise.

## How to run

1. Invoke the helper script to create the scaffold and capture the file path:

   ```bash
   FILE=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/save.sh" "$ARGUMENTS")
   ```

   `$ARGUMENTS` is the user-provided title. If empty, the script defaults to `session`. The script prints the absolute path of the newly created log file to stdout.

2. Read the scaffold with the `Read` tool to confirm structure.

3. Replace each `_(placeholder)_` in the scaffold with real content using `Edit`:

   - **Summary** — one paragraph, user-facing. What was worked on and why. No narration of tool calls.
   - **Decisions** — bullet list. For each decision taken this session, add a wikilink to the corresponding `decisions/` note if one exists, or note that a decision was taken but not yet formalized ("TODO: run /obsidian-memory:decide").
   - **Files touched** — bullet list of repo-relative paths that were created or edited. Group by repo if multiple.
   - **Next** — bullets of what's left, pending questions, or where to pick up next session.

4. After writing, confirm to the user with: `Log saved: <absolute path>` — nothing more.

## Rules

- **Atomic**: one session log per invocation. Don't try to split into multiple files.
- **No secrets**: never write tokens, passwords, API keys, or private data into the log.
- **Wikilinks, not paths**: when referencing other vault notes use `[[slug]]`, not markdown links.
- **Don't rewrite history**: if a log already exists with the same title for today, `save.sh` auto-suffixes with a timestamp. Trust it.
- **Don't delete `logs/now.md`** manually — the script rotates it for you when a full log is written.

## Failure handling

If `save.sh` fails (e.g., vault missing), the script prints an error to stderr and exits non-zero. Report the error to the user verbatim and suggest running the migration script:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/migrate.sh"
```

Never silently fall back to writing elsewhere — if the vault isn't there, the user needs to know.
