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

## Obsidian app setup

The plugin writes plain markdown to the vault, so Obsidian is **not required** for it to work. But Obsidian is what makes the vault browseable, graph-navigable, and queryable. Recommended setup:

### 1. Install Obsidian

Download from [obsidian.md](https://obsidian.md). On Linux, the AppImage is the easiest path:

```bash
# Move, chmod, and integrate with the application menu
mkdir -p ~/Applications ~/.local/share/applications ~/.local/share/icons ~/.local/bin
mv ~/Downloads/Obsidian-*.AppImage ~/Applications/Obsidian.AppImage
chmod +x ~/Applications/Obsidian.AppImage

# Extract the icon for the desktop entry
mkdir -p /tmp/obsidian-extract && cd /tmp/obsidian-extract
~/Applications/Obsidian.AppImage --appimage-extract 'usr/share/icons/hicolor/512x512/apps/obsidian.png'
cp squashfs-root/usr/share/icons/hicolor/512x512/apps/obsidian.png ~/.local/share/icons/obsidian.png

# Create the desktop entry
cat > ~/.local/share/applications/obsidian.desktop <<EOF
[Desktop Entry]
Name=Obsidian
GenericName=Knowledge base
Exec=$HOME/Applications/Obsidian.AppImage --no-sandbox %U
Icon=$HOME/.local/share/icons/obsidian.png
Terminal=false
Type=Application
Categories=Office;TextEditor;Utility;
MimeType=x-scheme-handler/obsidian;
StartupWMClass=obsidian
EOF

# CLI shortcut
ln -sfn ~/Applications/Obsidian.AppImage ~/.local/bin/obsidian
```

If `obsidian` fails with `dlopen(): error loading libfuse.so.2`, install FUSE: `sudo apt install libfuse2`.

### 2. Open the vault

Launch Obsidian → **"Open folder as vault"** → select `~/vault` (or wherever `OBSIDIAN_MEMORY_VAULT` points).

Confirm **"Trust author and enable plugins"** when prompted.

**Picker gotcha**: the folder picker wants you to select the vault from its parent. Navigate to `~/` (your home), single-click `vault` to highlight it — **do not enter it** — then click "Open". If the Open button is greyed out, you're inside the folder; click "up one level" first.

### 3. Install required community plugins

Settings → **Community plugins** → **Turn on community plugins** → **Browse**.

Install and enable:

| Plugin | Why it matters |
|---|---|
| **Dataview** | Queries over frontmatter. Required for `/obsidian-memory:review` to visually surface pending decisions. |
| **Templater** | Template engine. Uses the templates already at `~/vault/templates/` for new notes. |
| **Folders to Graph** | Renders directories as nodes in the graph view. Essential for navigating the Zettelkasten visually. |
| **Calendar** | Sidebar calendar widget. Click a date to open that day's session log or inbox. |

### 4. Configure Templater

Settings → **Templater**:

- **Template folder location**: `templates`
- **Trigger Templater on new file creation**: `ON`
- **Folder Templates** (optional): assign `templates/permanent-note.md` to `permanent/`, `templates/decision.md` to `decisions/`, `templates/session-log.md` to `logs/`.

### 5. Configure the graph view (optional)

Open the graph (Cmd/Ctrl+G). Useful filter presets:

| Filter | Shows |
|---|---|
| `path:permanent` | Only consolidated Zettelkasten notes |
| `path:decisions` | Only decision notes |
| `tag:#feedback` | Only feedback memories |
| `-path:logs -path:inbox` | Everything except the noise |

Disable **"Orphans"** and **"Existing files only"** in the graph filters if the view looks empty after applying a filter.

### 6. Git sync (recommended)

The vault is a plain directory — version it with git for cross-machine sync and point-in-time recovery:

```bash
cd ~/vault
git init -q
git add -A
git commit -q -m "Initial vault state"
# Create a private repo on GitHub and push:
gh repo create storo/vault --private --source=. --push
```

**Do not put the vault on iCloud/Dropbox/OneDrive** — those sync engines fight with Obsidian's workspace lockfile and cache. Git or Syncthing are the battle-tested options.

### 7. First run check

In a Claude Code session, run:

```
/obsidian-memory:note "first real note"
```

Switch to Obsidian — the note should appear under `inbox/<today>.md` within a few seconds.

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
