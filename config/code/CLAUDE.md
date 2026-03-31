# Global Context — Matt Schedler

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
- Store findings in BOTH artifact DB (detailed, queryable, per-project) AND Qdrant (narrative, cross-project).

## Three Constraints
- `mattermost_call` — LAN-only, backup cron notifications ONLY. Never project/patent content.
- SSH file edits — base64 encode/decode. Never heredoc with backticks.
- Email — SMTP: smtp.quicklinkstechnologies.com:587 | IMAP: imap.quicklinkstechnologies.com:143 | User: info@quicklinkstechnologies.com

## Memory Protocol — OVERRIDES built-in memory

### Think Before Storing
Before storing any memory, evaluate:
- **Will a future session need this?** If not, don't store — it's ephemeral context.
- **Does it capture WHY, not just WHAT?** "Decided X" is less useful than "Decided X because Y, considered Z but rejected it because W." Rewrite to include reasoning.
- **Does an existing memory cover this?** Search first. Update existing rather than creating duplicates.
- **What consequence tier?**
  - **High** (patent, legal, critical decisions): Source of truth is git/immutable docs. Memory is a pointer for retrieval. Tag `protected` if evidence-grade.
  - **Medium** (architecture, project state, preferences): Memory IS the source of truth. Preserve reasoning when updating.
  - **Low** (session context, debugging): Store if useful, let decay naturally.

### Where Knowledge Lives
The system has specialized stores. Use the right one based on what you're looking for or storing:
- **Qdrant** (`memory_call`): Narrative context — decisions, reasoning, gotchas, preferences, session history. This is the primary search layer. Try 2-3 query variations. Use `exclude_category`/`exclude_memory_type` to filter noise.
- **Neo4j** (`graph_call`): Structural relationships — what depends on what, who works on what, entity connections. Use `merge_node`/`merge_relationship` (prefer merge over find+create). Query here for "what's connected to X" questions.
- **MongoDB** (`mongodb_call`): Reference-grade documents — research reports, architecture plans, decision records. DB=homelab, collection=docs, always include a slug for retrieval.
- **Project Pipeline** (`project_call`): Project lifecycle — sprints, tasks, questions, events. Use `get_project` for project context, `list_projects` when discussion shifts to planning.
- **Preferences** (`pref_call` or Qdrant `category: preference`): User preferences and work patterns. Migrated to Qdrant (March 28, 2026) — searchable via `memory_call > search` with `category: "preference"`. Legacy `pref_call` still works for reads.
- **Artifact DB** (`artifacts/project.db`): Per-project detailed records — subagent findings, decisions with rationale, assessments, debate rounds. Present in projects that use multi-agent research or review skills. Query with `source artifacts/db.sh && db_search "topic"`. Qdrant holds the cross-project narrative; the artifact DB holds the full detail within a project. Not every project has one — check before using.

Search MCP stores before asking the user. If all stores return nothing, then ask.

### Cross-Project Memory
Categorize for the project that needs to FIND the memory, not the project you are working in. Before storing: which project's rehydration should surface this? If multiple: store once, categorize for destination, tag both project names.

Do NOT use `~/.claude/projects/*/memory/` files. MEMORY.md is bootstrap index only.
`mattermost_call` — LAN-only, backup cron notifications only. NOT for project/patent content.

### Session Rehydration
1. `gateway_call` > `rehydrate` {topic, project_slug} — memories + project + sprints + unanswered + graph + preferences in one call
2. Check interagent inbox: `interagent_call` > `inbox` {machine: "<your .machine-id name>"} — pending assignments from other agents. Claim with `claim`, complete with `complete`.
3. Individual calls only for deeper drill-down

### New Project Setup
If session-prewarm reports `NO GROUNDING.md FOUND`, run `/project-organize` before other work.

When creating a new project (repo or pipeline entry), create a GROUNDING.md covering:
1. **Why does this exist?** Problem, who has it, why now.
2. **Key decisions made and why.** Not just conclusions — the reasoning.
3. **What should a new agent NOT do?** Anti-patterns specific to this project.
4. **Commercial model.** Who pays, how it creates value.
GROUNDING.md explains WHY. Procedural docs (PROGRESS.md, ARCHITECTURE.md) explain WHAT/HOW.

### Session-Start Background Hygiene
After rehydrate, if project has GROUNDING.md or pipeline entry, evaluate: does this session warrant a background hygiene subagent? Skip for trivial/quick sessions.

Spawn background agent when warranted:
- `memory_call > search` filtered to last 7 days for same topic (recency pass — semantic search under-ranks recent work)
- Check engineering notebook for TOC block; flag if missing/stale
- Search Qdrant for this project's memories that contradict current known state

Constraints:
- Read-heavy, minimal writes. Maintenance scope — not user-task findings.
- Report only if actionable. No output = nothing found.

### After Significant Work
If the session produced decisions, architecture changes, gotchas, or blockers — store them. The Think Before Storing criteria apply: store what a future session needs, capture the WHY, and check for duplicates first. Don't store mechanically; store thoughtfully.

## Key Patterns
- GitHub: mrschedler
