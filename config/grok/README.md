# config/grok/ — Grok Build wiring

Grok Build (this machine: `~/.grok`) is a second agent harness on the same
projects, skills, MCP gateway, and role files that Claude Code uses.

Claude Code injects `behavioral-reminders.txt` via SessionStart hook stdout.
Grok **ignores SessionStart stdout**, so protocol has to live in files Grok
actually loads: `$GROK_HOME/rules/*.md`.

## Shared vs Grok-only (all of it lives in this repo)

Claude and Grok both load from `claude-skills-suite` via junctions. Do **not**
copy skills. Do **not** import Claude `settings.json` hooks into Grok.

| Layer | Canonical | `~/.claude` | `~/.grok` |
|---|---|---|---|
| Skills | `skills/` | junction | junction (same target) |
| Agent roles | `agents/` | junction | junction (same target) |
| Hooks | Claude: `config/code/settings.json`; Grok: `config/grok/hooks/` | settings.json symlink | hooks junction. `[compat.claude] hooks = false` |
| Session protocol | Claude: SessionStart stdout; Grok: `config/grok/rules/` | n/a | rules junction |
| Secrets / MCP token | machine-local | `~/.claude.json` | `~/.grok/config.toml` (never committed) |

Why hooks are split: Claude's `settings.json` commands start with bare `bash`.
Claude Code forces Git Bash; Grok resolves `bash` to WSL
`C:\Windows\System32\bash.exe` (no distro `/bin/bash`) and spam-fails every
PostToolUse. Grok-native commands go through `config/grok/hooks/git-bash.cmd`.

Claude-compat **skills and agents stay on** so a repo's `.claude/skills/` and
`.claude/agents/` (e.g. ql-g3 `designer-feedback`, `bench-operator`) still
load. User-scoped copies are the junctions above; Grok dedupes by name.

## What this directory adds

| Path | Purpose |
|------|---------|
| `rules/` | Always-on Grok instructions (session orient, MCP calling, memory routing) |
| `hooks/` | Grok-native matchers (`write`, `gateway__memory_call`, …) |
| `config.toml.template` | Non-secret Grok config. Secrets stay in `~/.grok/config.toml` |
| `interagent-dispatch.sh` | Unattended pickup of `to=dell-xps-grok` mail (headless `grok -p` per id) |
| `worker-interagent.md` | Rules injected into those headless runs only |

Junctions (maintained by `scripts/verify-symlinks.sh`):

- `~/.grok/rules` → `config/grok/rules`
- `~/.grok/hooks` → `config/grok/hooks`
- `~/.grok/skills` → `skills/` (same as `~/.claude/skills`)
- `~/.grok/agents` → `agents/` (same as `~/.claude/agents`)

`~/.grok/config.toml` is machine-local (Cloudflare Access token). Do not commit it.

## First session after a change

Restart Grok (or `/new`). Home rules and hooks are read at session start.
Confirm with `grok inspect`: Project Instructions should list
`~/.grok/rules/00-orient.md`.

## Interagent — assign, reply, idle pickup

Agent name is `dell-xps-grok` when launched via `grok-agent` (sets
`INTERAGENT_MACHINE`). Plain `grok` still reads `.machine-id` and looks like
Claude personal — do not use that for mail.

On this machine `Documents` is OneDrive-redirected. Resolve `$PROFILE` at
runtime; the live files are
`~/OneDrive/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` and
`~/OneDrive/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`. Do not
write to `~/Documents/...`. `.bashrc` is still `~/.bashrc`.

Other agents assign work with `send {to:"dell-xps-grok", from:<their name>,
thread_id, topic, context_refs:[{type:"project", id:<git-root basename>}]}`.
Grok replies with `send` back to `from_agent` on the same `thread_id`, then
`complete`. Table: `skills/interagent/SKILL.md`.

Two pickup layers (pick one, not both):

| When | Mechanism |
|------|-----------|
| Live `grok-agent` TUI | `/monitor-interagent` — Grok `monitor` tool runs `hooks/interagent-monitor-poll.sh` |
| No TUI / logon | `config/grok/interagent-dispatch.sh` — polls SSH, launches `grok -p` per new id |

The dispatcher is **not** a hook and **not** an agent. It only picks up
`to=dell-xps-grok` (never `any` broadcasts). Worker instructions:
`config/grok/worker-interagent.md` (passed via `--rules`, not loaded as a home rule).

```bash
# start (Git Bash) — leave the window open, or schtasks it later
bash /c/dev/claude-skills-suite/config/grok/interagent-dispatch.sh

# one poll (test)
bash /c/dev/claude-skills-suite/config/grok/interagent-dispatch.sh --once

# stop / status
bash /c/dev/claude-skills-suite/config/grok/interagent-dispatch.sh --stop
bash /c/dev/claude-skills-suite/config/grok/interagent-dispatch.sh --status
```

Logs and pid: `%LOCALAPPDATA%/grok-interagent/` (not synced). Seen-file is
machine-wide (`seen-dell-xps-grok.txt`), unlike Claude's per-project poller
seen-files. Interval default 5s. Each worker: `--max-turns 40 --always-approve
--no-subagents`. `--always-approve` is required because headless has no TTY
for MCP prompts; bound the blast radius with max-turns and no-subagents, not
an empty allowlist (MCP `use_tool` is not a builtin `--tools` id).

Proposed poller fix (do not apply here; hooks are shared):
`interagent-monitor-poll.sh` SQL drops rows with `ttl_hours IS NULL` (durable
todos). Dispatcher query includes them.

## Do not enable Grok native memory

`[memory] enabled = false` in `~/.grok/config.toml`. Narrative memory is
Qdrant via `gateway__memory_call`. Grok's `~/.grok/memory/` files are not
cross-project searchable and would split the memory plane.
