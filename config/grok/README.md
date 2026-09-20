# config/grok/ — Grok Build wiring

Grok Build (this machine: `~/.grok`) is a second agent harness on the same
projects, skills, MCP gateway, and role files that Claude Code uses.

Claude Code injects `behavioral-reminders.txt` via SessionStart hook stdout.
Grok **ignores SessionStart stdout**, so protocol has to live in files Grok
actually loads: `$GROK_HOME/rules/*.md`.

## What is already shared (no Grok-specific copy)

| Layer | How Grok gets it |
|-------|------------------|
| Skills | Claude compat scans `~/.claude/skills` → this repo `skills/` |
| Agent roles | Claude compat scans `~/.claude/agents` → this repo `agents/` |
| Project docs | Grok loads `CLAUDE.md` / `Claude.md` / `AGENTS.md` as project rules |
| MCP gateway | Native HTTP in `~/.grok/config.toml` (`mcp_servers.gateway`) |
| Local hooks (side effects) | **Grok-native only:** `~/.grok/hooks` → `config/grok/hooks/grok-hooks.json`. Do **not** import Claude `settings.json` hooks on this machine (`[compat.claude] hooks = false`). Claude's hooks start with bare `bash`, which Grok resolves to WSL `C:\Windows\System32\bash.exe` (no distro `/bin/bash`) and spam-fails every PostToolUse. Claude Code forces Git Bash; Grok does not. Grok-native commands go through `config/grok/hooks/git-bash.cmd`. |

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
