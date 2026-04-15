#!/usr/bin/env python3
"""Extract a Claude Code session JSONL into a markdown session log.

Usage: extract-session.py <jsonl_path> [output_md_path]

Reads the raw JSONL conversation log that Claude Code maintains for each
session at $HOME/.claude/projects/<slug>/<session-id>.jsonl, and produces a
markdown summary suitable for the vault's logs/ directory.

The summary captures:
- Session id, timestamps, duration
- Tool usage counts
- Working directories seen
- First and last user message
- Files touched (from Edit/Write/Read/MultiEdit tool calls)
- Bash commands run (deduped)

This is lossy by design: the full conversation stays in the JSONL; the
markdown log is a queryable index over it.
"""

import json
import os
import sys
from datetime import datetime


def load_records(path: str):
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            try:
                yield json.loads(line)
            except Exception:
                continue


def extract(jsonl_path: str) -> dict:
    session_id = None
    first_ts = None
    last_ts = None
    user_texts: list[str] = []
    assistant_texts: list[str] = []
    tool_uses: dict[str, int] = {}
    files_touched: set[str] = set()
    bash_cmds: list[str] = []
    cwds: set[str] = set()

    for r in load_records(jsonl_path):
        ts = r.get("timestamp")
        if ts:
            if not first_ts:
                first_ts = ts
            last_ts = ts
        if not session_id:
            session_id = r.get("sessionId")

        rtype = r.get("type")
        if rtype == "user":
            cwd = r.get("cwd")
            if cwd:
                cwds.add(cwd)
            msg = r.get("message", {}) or {}
            content = msg.get("content")
            if isinstance(content, str):
                text = content.strip()
                # Skip tool_result synthetic messages that start with structured data
                if text and not text.startswith("[{"):
                    user_texts.append(text)
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        t = (block.get("text") or "").strip()
                        if t:
                            user_texts.append(t)

        elif rtype == "assistant":
            msg = r.get("message", {}) or {}
            content = msg.get("content", [])
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                if btype == "text":
                    t = (block.get("text") or "").strip()
                    if t:
                        assistant_texts.append(t)
                elif btype == "tool_use":
                    name = block.get("name", "?")
                    tool_uses[name] = tool_uses.get(name, 0) + 1
                    inp = block.get("input") or {}
                    if isinstance(inp, dict):
                        fp = inp.get("file_path") or inp.get("path")
                        if fp and isinstance(fp, str):
                            files_touched.add(fp)
                        if name == "Bash":
                            cmd = inp.get("command", "")
                            if cmd and isinstance(cmd, str):
                                bash_cmds.append(cmd[:120])

    return {
        "session_id": session_id or "unknown",
        "first_ts": first_ts,
        "last_ts": last_ts,
        "user_texts": user_texts,
        "assistant_texts": assistant_texts,
        "tool_uses": tool_uses,
        "files_touched": files_touched,
        "bash_cmds": bash_cmds,
        "cwds": cwds,
    }


def render_markdown(data: dict, reason: str = "session-end") -> str:
    now_iso = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    first_ts = data["first_ts"] or now_iso
    last_ts = data["last_ts"] or now_iso
    created_date = first_ts[:10] if first_ts else datetime.now().strftime("%Y-%m-%d")

    lines: list[str] = []
    lines.append("---")
    lines.append(f"title: session {created_date} ({reason})")
    lines.append("tags: [log, session, auto]")
    lines.append(f"created: {first_ts}")
    lines.append(f"ended: {last_ts}")
    lines.append(f"session_id: {data['session_id']}")
    lines.append(f"reason: {reason}")
    lines.append("type: session-log")
    lines.append("---")
    lines.append("")
    lines.append(f"# Session {created_date}")
    lines.append("")
    lines.append(
        f"- **Messages**: {len(data['user_texts'])} user / "
        f"{len(data['assistant_texts'])} assistant"
    )
    if data["tool_uses"]:
        tu = ", ".join(
            f"{k}({v})"
            for k, v in sorted(data["tool_uses"].items(), key=lambda x: -x[1])
        )
        lines.append(f"- **Tools**: {tu}")
    if data["cwds"]:
        cwds = ", ".join(f"`{c}`" for c in sorted(data["cwds"]))
        lines.append(f"- **Working dirs**: {cwds}")
    lines.append(f"- **Trigger**: {reason}")
    lines.append("")

    if data["user_texts"]:
        first = data["user_texts"][0]
        lines.append("## First user message")
        lines.append("")
        lines.append("> " + first[:500].replace("\n", "\n> "))
        lines.append("")

        if len(data["user_texts"]) > 1:
            last = data["user_texts"][-1]
            lines.append("## Last user message")
            lines.append("")
            lines.append("> " + last[:500].replace("\n", "\n> "))
            lines.append("")

    if data["files_touched"]:
        ft = sorted(data["files_touched"])
        lines.append(f"## Files touched ({len(ft)})")
        lines.append("")
        for fp in ft[:50]:
            lines.append(f"- `{fp}`")
        if len(ft) > 50:
            lines.append(f"- _… +{len(ft) - 50} more_")
        lines.append("")

    if data["bash_cmds"]:
        seen: set[str] = set()
        uniq: list[str] = []
        for c in data["bash_cmds"]:
            if c not in seen:
                seen.add(c)
                uniq.append(c)
        lines.append(f"## Bash commands ({len(uniq)} unique)")
        lines.append("")
        for c in uniq[:30]:
            lines.append(f"- `{c}`")
        if len(uniq) > 30:
            lines.append(f"- _… +{len(uniq) - 30} more_")
        lines.append("")

    lines.append("## Notes")
    lines.append(
        "_Auto-generated index over the raw JSONL. For narrative/decisions/"
        "next steps, either run `/obsidian-memory:save` to get a Claude-written "
        "summary, or edit this file directly in Obsidian._"
    )
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: extract-session.py <jsonl_path> [output_md_path] [reason]", file=sys.stderr)
        return 1

    jsonl_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else "-"
    reason = sys.argv[3] if len(sys.argv) > 3 else "session-end"

    if not os.path.exists(jsonl_path):
        print(f"not found: {jsonl_path}", file=sys.stderr)
        return 1

    data = extract(jsonl_path)
    md = render_markdown(data, reason=reason)

    if out_path == "-":
        sys.stdout.write(md)
    else:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(md)
        print(out_path)

    return 0


if __name__ == "__main__":
    sys.exit(main())
