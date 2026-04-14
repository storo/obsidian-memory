---
name: note
description: Appends a quick note to today's inbox file in the Obsidian vault. Use when the user runs `/obsidian-memory:note "text"`, says "capture this", "add a note", "put this in inbox", "remind me about X later", or when a useful observation comes up mid-conversation that doesn't warrant a full decision or session log. Appends with timestamp to `$VAULT/inbox/YYYY-MM-DD.md` — minimal friction, zero interruption.
argument-hint: "\"text to capture\""
allowed-tools: Bash
---

# note — zero-friction capture to inbox

Inbox notes are the cheapest persistence mechanism in the vault. They exist to catch thoughts, TODOs, links, and observations that shouldn't interrupt the current flow but shouldn't be forgotten either.

## When to run

- User runs `/obsidian-memory:note "..."`.
- User says "capture this", "add to inbox", "note that", "remind me later about...".
- User mentions a tangential idea mid-conversation and says "we should come back to this".

Do NOT run this skill for things that belong elsewhere:

- **Decisions** → use `/obsidian-memory:decide`.
- **Session logs** → use `/obsidian-memory:save`.
- **Permanent knowledge** → suggest the user promote an inbox note to `permanent/` manually.

## How to run

1. Get the text from `$ARGUMENTS`. If empty, ask the user what to capture.

2. Invoke the helper script:

   ```bash
   FILE=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/note.sh" "$ARGUMENTS")
   ```

   The script appends to `$VAULT/inbox/YYYY-MM-DD.md`, creating the file with frontmatter if this is the first note of the day. Each entry gets a `## HH:MM:SS` header.

3. Confirm tersely: `Noted → <filename>`. One line. Nothing else.

## Rules

- **Do not rewrite the user's text**. Capture verbatim (modulo trivial punctuation fixes).
- **Do not categorize or tag**. Inbox is raw capture — curation happens later when notes get promoted to `permanent/`.
- **Do not ask follow-up questions**. The whole point of `note` is that it doesn't interrupt flow.
- **No formatting theater**. A note is a line of text, not a mini essay.

## Failure handling

Script failure → one-line error message, nothing more.
