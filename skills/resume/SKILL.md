---
name: resume
description: Reloads session context from the Obsidian vault mid-conversation. Use when the user runs `/obsidian-memory:resume`, says "reload context", "resume", "pick up where we left off", "what were we doing", or after a `/clear` that wiped the SessionStart injection. Re-reads user profile, recent logs, pending decision reviews, and the continuous buffer, then briefs the user on current state.
argument-hint: ""
allowed-tools: Bash, Read
---

# resume — reload vault context mid-session

The `SessionStart` hook injects vault context automatically when a fresh session begins. This skill exists for the other cases: after `/clear`, after context compaction that lost state, or when the user explicitly wants a re-orientation.

## When to run

- User runs `/obsidian-memory:resume`.
- User says "what were we doing", "pick up where we left off", "reload context", "remind me what's pending".
- Right after a `/clear` when you need your bearings.
- When you realize mid-conversation that you lack context the vault probably has.

Do NOT run this at the start of a fresh session — the `SessionStart` hook already did it.

## How to run

1. Invoke the same script the SessionStart hook uses, capturing its output:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"
   ```

2. Read the output carefully. It is a compact bundle containing:

   - User profile (`permanent/user-profile.md`)
   - Continuous buffer (`logs/now.md`) if present
   - Last 3 session logs
   - Decisions with `review_date <= today` and `status: active`
   - `MEMORY.md` index

3. Brief the user in **3-5 sentences max**:

   - One sentence: who they are (name + current role/stack).
   - One sentence: what the last session was about (from most recent log).
   - One sentence: any pending decision reviews (if any).
   - One sentence: what was left unfinished or "next" from the prior log.
   - Optionally: any continuous-buffer content worth flagging.

   Example: _"Sergio, polyglot dev (Rust/Go/Python/TS). Last session worked on the inbox-triage CLI with gws. 1 decision pending review: `2026-03-24-use-sqlite-not-redis` (30 days up). Left off: wire gws.send-label to the triage loop."_

4. If the user then asks a follow-up, read the relevant log or note in full with `Read` — the resume bundle is an index, not a substitute for the real files.

## Rules

- **Don't dump the raw bundle** to the user. Summarize.
- **Don't speculate** — if the resume bundle is empty or inconclusive, say "vault has no recent context" and stop.
- **Don't modify anything** — resume is read-only.

## Failure handling

If the script fails (vault missing, permission denied), print the stderr error and suggest:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/migrate.sh"
```
