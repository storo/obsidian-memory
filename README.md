# obsidian-memory

> Single-source memory system for Claude Code, backed by an Obsidian vault.

**No fragmented state.** Replaces `.claude/memory`, the built-in auto-memory, and per-repo `.remember/` buffers with one vault on disk. Claude writes there, you read and edit it in Obsidian, git keeps history.

## Why

Claude Code ships with several overlapping memory mechanisms: the global `~/.claude/memory/` convention, the auto-memory at `~/.claude/projects/<project>/memory/`, and optional `.remember/` buffers per repo. Three places to look, three formats to keep in sync, and none of them are visually browsable.

This plugin collapses all of it into one Obsidian vault:

- **Zettelkasten-style notes** with wikilinks, frontmatter, atomic units.
- **Session logs** auto-generated at session end.
- **Decision log** with review dates, queryable via Dataview.
- **Quick capture** to `inbox/` from anywhere in Claude Code.
- **Context injection** at session start — Claude wakes up knowing recent logs, pending decision reviews, and your profile.

## Architecture

```
~/vault/                                          ← single source of truth
├── CLAUDE.md                                     ← vault rules (loaded per session)
├── MEMORY.md                                     ← index
├── permanent/                                    ← consolidated Zettelkasten notes
├── inbox/                                        ← raw capture (auto-memory + /note)
├── fleeting/                                     ← scratch
├── logs/                                         ← session logs + logs/now.md buffer
├── decisions/                                    ← one .md per decision
├── templates/                                    ← Templater templates
└── projects/                                     ← project-specific notes

~/.claude/projects/<project>/memory → ~/vault/    ← symlink (bridges hardcoded auto-memory path)
```

**The symlink is load-bearing.** Claude Code's auto-memory path is hardcoded in the harness and cannot be disabled. The symlink redirects it to the vault, so there is still one physical location.

## Installation

```bash
# Local install (development)
git clone https://github.com/storo/obsidian-memory ~/.claude/plugins/local/obsidian-memory

# Or marketplace install (when published)
claude plugin marketplace add storo/obsidian-memory
claude plugin install obsidian-memory@storo
```

Then run the migration script once (destructive — see below):

```bash
bash ~/.claude/plugins/local/obsidian-memory/scripts/migrate.sh
```

## Configuration

The vault path defaults to `$HOME/vault`. Override via environment variable:

```bash
export OBSIDIAN_MEMORY_VAULT="$HOME/Documents/my-vault"
```

Or put it in `~/.claude/obsidian-memory.local.md` (one line with the path).

## Components

### User-invoked skills

| Skill | Syntax | What it does |
|---|---|---|
| `save` | `/obsidian-memory:save [title]` | Force-write a session log right now |
| `resume` | `/obsidian-memory:resume` | Reload context from vault (useful after `/clear`) |
| `decide` | `/obsidian-memory:decide "decision text"` | Create a decision note with 30-day review date |
| `review` | `/obsidian-memory:review` | List decisions whose review date has passed |
| `note` | `/obsidian-memory:note "text"` | Append a quick note to `inbox/YYYY-MM-DD.md` |

### Auto-activated skills

| Skill | Triggers on | Purpose |
|---|---|---|
| `memory-write-rules` | Writing to the vault | Zettelkasten rules: wikilinks, frontmatter, kebab-case, atomicity |
| `memory-search` | Before answering questions with historical context | Grep-first strategy, read relevant notes, cite via wikilinks |

### Hooks

| Event | Script | Purpose |
|---|---|---|
| `SessionStart` | `session-start.sh` | Inject profile + 3 recent logs + `logs/now.md` + due decision reviews + `MEMORY.md` index |
| `SessionEnd` | `session-end.sh` | Write `logs/YYYY-MM-DD-slug.md` summarizing the session |
| `PreCompact` | `precompact.sh` | Snapshot conversation state to `logs/now.md` before compaction |

All hook scripts are defensive: failures never block the session, errors are logged to `$VAULT/logs/hook-errors.log`.

## License

MIT
