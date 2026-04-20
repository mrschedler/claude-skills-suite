# Claude Code Config — Matt Schedler
# Behavioral protocol is in behavioral-reminders.txt (hook-injected, agent-agnostic).
# This file contains Claude Code-specific infrastructure and tool references only.

## Machine Identity
Read `C:\dev\.machine-id` at session start. This file is NOT synced — each machine has its own.
- **dell-xps** (DESKTOP-UJ4H1DQ) — Dell XPS 15, primary dev machine, fully configured
- **skip** — Surface laptop, secondary dev machine

## Workspace Layout
- `C:\dev\` is the single Syncthing share (`dev-projects`) — all code + Claude config in one share
- `C:\dev\.claude\` is the REAL config directory (hooks, settings, plugins, project memory)
- `C:\Users\matts\.claude\` is a junction → `C:\dev\.claude\` (so Claude Code finds its config)
- `C:\dev\.claude\skills\` is a symlink → `C:\dev\claude-skills-suite\skills\` (local per machine, not synced)
- Machine-specific files (NOT synced): `.machine-id`, `.credentials.json`, `machine-identity.json`, `settings.local.json`

## Infrastructure
- **Unraid (DeepThought):** `ssh deepthought` | 192.168.0.129 | MCP Gateway on port 3500
- **MCP Gateway:** `https://mcp.epiphanyco.com/mcp` — 35 modules, 300+ tools. Source on Unraid.
- **SSH:** Jetson `ssh matt@192.168.0.45` | Pi-106 `ssh pi@192.168.0.106` | Pi-105 `ssh pi@192.168.0.105`
- **`mcp__gateway__ssh_call`:** DO NOT USE — gateway can't SSH to itself. Use Bash SSH direct.
- **Obsidian:** Unraid `/mnt/user/device-sync/obsidian-vault/` | Local `C:\Users\matts\Syncthing\Obsidian-Vault\`

## Projects
Active projects live in `C:\DEV` with pipeline entries (`project_call > list_projects`). Most have a GROUNDING.md — read it before diving into code. Three foundation projects: Memory System, MCP Gateway, Skills Suite.

## System Tools
- **sqlite3:** `export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"` — run before any `db.sh` commands.

## Artifact DBs (SQLite)
- Location: `artifacts/project.db` per project. Init: `source artifacts/db.sh && db_init`.
- If `artifacts/db.sh` exists in a project, use it. Projects may add domain-specific tables beyond the base `artifacts` schema.

## Three Constraints
- `mattermost_call` — LAN-only, backup cron notifications ONLY. Never project/patent content.
- SSH file edits — base64 encode/decode. Never heredoc with backticks.
- Email — SMTP: smtp.quicklinkstechnologies.com:587 | IMAP: imap.quicklinkstechnologies.com:143 | User: info@quicklinkstechnologies.com

## Key Patterns
- GitHub: mrschedler
