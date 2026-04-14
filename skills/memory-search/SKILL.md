---
name: memory-search
description: Searches the Obsidian vault for relevant prior context before answering. Use when the user asks about something that may have historical context — past decisions, prior sessions, earlier discussions, or anything referencing "we talked about", "last time", "previously", "before", "the project X". Also use proactively when you suspect the vault has relevant context but don't know which file. Grep-first strategy avoids loading irrelevant notes into context.
---

# memory-search — find vault context before answering

The vault accumulates hundreds of notes over time. Loading them all into context is wasteful. This skill defines the search strategy: grep first, read relevantly, cite via wikilinks.

## When to use

Auto-activate when:

- The user asks about something that could have historical context ("remember when...", "last time we...", "what did we decide about X", "the project Y").
- You're about to claim "I don't have information about X" — check the vault first.
- A question mentions a name, project, or concept that might be in `permanent/` or `decisions/`.
- The SessionStart bundle didn't include what you need, but you suspect the vault has it.

Do NOT use when:

- The question is about the current session only (look at recent conversation turns instead).
- The question is about the codebase (use `Grep` on source files, not the vault).
- The question has nothing to do with the user's history or decisions.

## Search strategy (in order)

1. **Grep the vault for exact keywords**:

   ```
   Grep pattern="<keyword>" path="$VAULT" output_mode="files_with_matches"
   ```

   Use the most specific term from the question. Broad terms like "project" return everything — useless.

2. **If grep returns 0 files**, try variants:

   - Different spelling / capitalization.
   - Related terms (e.g., "auth" → "authentication", "login", "oauth").
   - Partial matches (`Grep pattern="<stem>"` without word boundaries).

3. **If still 0 files**, check `MEMORY.md` index: `Read $VAULT/MEMORY.md`. The index may mention a note by topic you didn't think of.

4. **If grep returns 1-3 files**, read them all with `Read`.

5. **If grep returns 4+ files**, show the user the file list and ask which to load — or use a narrower query first.

## Folder priority

When choosing which file to read first, prioritize by folder:

1. `decisions/` — decisions have the highest signal-to-noise.
2. `permanent/` — consolidated knowledge.
3. `logs/` — session-level narrative, useful for "what were we doing".
4. `projects/<name>/` — project-specific context.
5. `inbox/`, `fleeting/` — raw capture, lowest priority.

## Citing what you found

When you answer using vault content, cite the source as a wikilink:

> According to [[2026-03-24-use-sqlite-not-redis]], we chose SQLite because the write volume was under 100 ops/sec.

Not as a filesystem path. Not as a markdown link.

## Anti-patterns

- **Don't read the whole vault.** Ever. That defeats the purpose.
- **Don't read every file grep returned** if there are more than 3-4 — narrow first.
- **Don't invent** content that isn't in the vault. If you didn't find it, say "not in the vault" and stop.
- **Don't search the vault for questions that have nothing to do with user history** — use Grep/Read on the actual codebase.

## Zero-result answer format

If nothing relevant is in the vault:

> _No prior context in the vault for "<query>". If this should be persisted, capture with `/obsidian-memory:note` or log a decision with `/obsidian-memory:decide`._

One line. Do not speculate.
