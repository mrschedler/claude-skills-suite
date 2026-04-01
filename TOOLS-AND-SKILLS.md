# Tools & Skills Reference

> Complete inventory of available Claude Code tools, MCP gateway modules, and skills.
> Generated 2026-03-30 from the claude-skills-suite workspace.

---

## Table of Contents

1. [Native Claude Code Tools](#native-claude-code-tools)
2. [MCP Gateway Modules (35 modules, 300+ tools)](#mcp-gateway-modules)
3. [Local MCP Servers](#local-mcp-servers)
4. [Gmail Integration](#gmail-integration)
5. [Skills Suite (44 skills)](#skills-suite)
   - [Development & Planning](#development--planning)
   - [Review Lenses](#review-lenses)
   - [Project Setup & Organization](#project-setup--organization)
   - [Git & Release Management](#git--release-management)
   - [Meta / Orchestration](#meta--orchestration)
   - [Research](#research)
   - [Infrastructure](#infrastructure)
   - [Skill Management](#skill-management)
   - [CLI Drivers (internal)](#cli-drivers-internal)
   - [Utility (internal)](#utility-internal)
   - [Archived / Deprecated](#archived--deprecated)

---

## Native Claude Code Tools

These are always available — built into Claude Code, not MCP.

| Tool | Purpose |
|------|---------|
| **Read** | Read files by absolute path (text, images, PDFs, notebooks) |
| **Write** | Create or overwrite files |
| **Edit** | Exact string replacement in existing files |
| **Glob** | Fast file pattern matching (`**/*.ts`, `src/**/*.py`) |
| **Grep** | Regex content search powered by ripgrep |
| **Bash** | Shell command execution (Git Bash on Windows) |
| **Agent** | Spawn specialized subagents (Explore, Plan, general-purpose) |
| **WebFetch** | Fetch and process URL content |
| **WebSearch** | Web search via Bing |
| **TaskCreate/Update/List** | Break work into tracked steps within a session |
| **Skill** | Invoke a registered slash-command skill |
| **NotebookEdit** | Edit Jupyter notebook cells |

---

## MCP Gateway Modules

**Endpoint:** `https://mcp.epiphanyco.com/mcp` — 35 modules, 300+ tools.
Each module exposes a `_call` (execute) and `_list` (discover available tools) endpoint.

### Knowledge & Memory

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **memory** | `memory_call` | Qdrant semantic memory — decisions, reasoning, gotchas, preferences, session history. Primary search layer. |
| **graph** | `graph_call` | Neo4j knowledge graph — structural relationships, dependencies, entity connections. `merge_node`/`merge_relationship`. |
| **obsidian** | `obsidian_call` | Obsidian vault indexing and semantic search. |

### Project & Task Management

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **project** | `project_call` | Project pipeline lifecycle — sprints, tasks, questions, events. `get_project`, `list_projects`. |
| **task** | `task_call` | Universal work tracking — punch lists, diagnostics, infrastructure, research, stories. |
| **blueprint** | `blueprint_call` | Agent blueprints — modular automation specs with guardrails (action budgets, approval gates). |
| **workspace** | `workspace_call` | Project workspace orchestration — repos, sessions, designs, artifacts. |

### Data Storage & Querying

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **pg** | `pg_call` | PostgreSQL database tools — query, manage tables. |
| **mongodb** | `mongodb_call` | MongoDB — databases, collections, documents, indexes, aggregation. DB=homelab, collection=docs. |
| **redis** | `redis_call` | Shared Redis cache/message broker — key ops, pub/sub, server stats (db0=general, db1=Dify, db2=plugin). |
| **rabbitmq** | `rabbitmq_call` | RabbitMQ message queue — exchanges, bindings, connections. |

### Infrastructure & DevOps

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **docker** | `docker_call` | Docker container management — inspect, run, stop, restart. |
| **recipe** | `recipe_call` | Container recipes — reusable templates stored in Vault (list, deploy, redeploy, teardown). |
| **traefik** | `traefik_call` | Traefik reverse proxy inspection (read-only) — routers, services, middlewares. |
| **vault** | `vault_call` | HashiCorp Vault secrets management. |
| **prometheus** | `prometheus_call` | Prometheus metrics and monitoring queries. |
| **uptime** | `uptime_call` | Uptime Kuma service availability monitoring. |

### Automation & AI

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **n8n** | `n8n_call` | n8n workflow automation — list, create, update, execute, delete workflows. |
| **dify** | `dify_call` | Self-hosted Dify AI app builder — apps, models, tools, knowledge bases, workflows. |
| **openhands** | `openhands_call` | Self-hosted OpenHands autonomous coding agent — conversations, agent control, events. |
| **ai** | `ai_call` | OpenRouter AI — call other LLMs (Gemini, GPT, Mistral, etc.) from within a session. |
| **context7** | `context7_call` | Up-to-date documentation for code libraries and frameworks. |

### External Integrations

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **github** | `github_call` | GitHub — repos, issues, PRs, checks, releases. |
| **browser** | `browser_call` | Browser automation — Playwright-based web interactions. |
| **figma** | `figma_call` | Figma design files — read files, extract components/styles, render images, manage comments. |
| **mattermost** | `mattermost_call` | Team chat at chat.epiphanyco.com — channels, posts, threaded replies. **LAN-only, backup notifications only.** |
| **telegram** | `telegram_call` | Telegram bot — send messages, photos, inline keyboards, webhooks. |
| **contacts** | `contacts_call` | Email intelligence — contact dossiers, email search, business context summaries. |

### Coordination & Configuration

| Module | Tools Prefix | Purpose |
|--------|-------------|---------|
| **gateway** | `gateway_call` | Gateway orchestration — includes `rehydrate` for session startup. |
| **coordination** | `coordination_call` | Inter-agent session registration, coordination signals, resource locks. |
| **interagent** | `interagent_call` | Inter-agent messaging — inbox, claim, complete. Cross-machine task handoff. |
| **activity** | `activity_call` | Activity log querying — track all tool calls across sessions. |
| **pref** | `pref_call` | User preferences (legacy read access; migrated to Qdrant `category: preference`). |

---

## Local MCP Servers

### Homelab (`mcp__homelab__*`)

Direct Unraid infrastructure management, configured locally per machine.

| Tool | Purpose |
|------|---------|
| `list_workflows` / `get_workflow` | Inspect n8n workflows |
| `create_workflow` / `update_workflow` / `delete_workflow` | Manage n8n workflows |
| `activate_workflow` / `deactivate_workflow` | Toggle n8n workflow state |
| `list_executions` / `get_execution` | View n8n execution history |
| `query_mariadb` / `list_mariadb_tables` | Tour database (MariaDB) |
| `query_postgres` / `list_postgres_tables` | Mailmine database (PostgreSQL) |
| `describe_table` | Schema inspection for either DB |
| `list_containers` / `container_logs` | Docker container inspection |
| `container_restart` / `container_stop` / `container_start` | Docker container lifecycle |
| `ssh_command` / `ssh_device` | SSH to Unraid, Jetson, Pi-106, Pi-105 |

### Playwright (`playwright`)

Browser automation via `@playwright/mcp@latest`. Used by `browser-review` skill.

---

## Gmail Integration

**Prefix:** `mcp__claude_ai_Gmail__gmail_*`

| Tool | Purpose |
|------|---------|
| `gmail_get_profile` | User profile and mailbox stats |
| `gmail_search_messages` | Search with full Gmail query syntax |
| `gmail_read_message` | Fetch complete message content |
| `gmail_read_thread` | Fetch entire conversation thread |
| `gmail_list_drafts` | List unsent drafts with pagination |
| `gmail_list_labels` | List system and user-created labels |
| `gmail_create_draft` | Create new draft (plain text or HTML, reply-to-thread) |

---

## Skills Suite

**60 total skills** — 46 user-invocable, 12 internal-only, 2 deprecated.
Invoked via `/skill-name` in Claude Code. Each skill lives in `skills/<name>/SKILL.md`.

### Development & Planning

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/feature-dev` | Yes | Unified feature development. Routes by complexity: simple (just do it), medium (light plan), complex (Ralph mode with PRD, artifact DB progress, iterative story-per-commit). |
| `/quick-plan` | Yes | Lightweight in-session planning. Phases, acceptance criteria, open questions. Not for formal project-plan.md. |
| `/build-plan` | Yes | Generates `project-plan.md` with phases, milestones, technical approach, and parallelizable work units. |
| `/evolve` | Yes | Updates `project-context.md` and `project-plan.md` to reflect current truth. |
| `/ui-design` | Yes | Generates UI components and pages following the project design system. |
| `/claude-api` | Yes | Build apps with the Claude API or Anthropic SDK. Triggers when code imports `anthropic` or `@anthropic-ai/sdk`. |
| `/simplify` | Yes | Review changed code for reuse, quality, and efficiency, then fix any issues found. |

### Review Lenses

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/security-review` | Yes | Security audit — dependencies, auth, secrets, input validation, network boundaries, supply chain, IaC. P0/P1/P2 tiers. |
| `/compliance-review` | Yes | Checks code against documented rules (CLAUDE.md, cross-cutting-rules.md). |
| `/completeness-review` | Yes | Scans for stubs, TODOs, placeholders, empty bodies, unfinished code. |
| `/test-review` | Yes | Evaluates test coverage, quality, and gaps. Catches AI tendencies to skip or stub tests. |
| `/perf-review` | Yes | N+1 queries, missing indexes, memory leaks, O(n²) loops, caching gaps, DB query issues. |
| `/refactor-review` | Yes | Over-engineering, duplication, bloat, truncated code, unnecessary abstractions. |
| `/integration-review` | Yes | Dead wiring, missing config/env entries, incomplete teardown, unbundled assets. |
| `/ui-review` | Yes | AI anti-patterns, token violations, a11y failures, inconsistency in UI code. |
| `/log-review` | Yes | Logging and observability gaps — silent catches, missing context, no structured logging. |
| `/counter-review` | Yes | Adversarial red-team review. Attacks architecture, completeness, drift, abuse cases, attack chains. |
| `/drift-review` | Yes | Compares code against project documentation to find drift. |
| `/doc-audit` | Yes | Documentation quality, completeness, and accuracy. Stale READMEs, undocumented APIs. |
| `/dep-audit` | Yes | Dependency health — CVEs, outdated versions, license conflicts, abandoned packages. |
| `/breaking-change-review` | Yes | Detects breaking API, dependency, and schema changes before they ship. |
| `/browser-review` | Yes | Visual QA via browser MCP tools (Playwright/browser-use). |

### Project Setup & Organization

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/project-organize` | Yes | Organizes any project (new or existing) with GROUNDING.md, engineering notebook, clean structure. Replaces deprecated scaffold + clean-project. |
| `/project-context` | Yes | Writes `project-context.md`, a comprehensive handoff document. Complements GROUNDING.md. |
| `/notebook-init` | Yes | Creates an engineering or inventor's notebook in a project. |
| `/sub-project` | Yes | Creates an isolated sub-project workspace to keep context focused. |
| `/sub-project-merge` | Yes | Merges a completed sub-project back into its parent. |
| `/project-questions` | Internal | Deep-dive interview to surface assumptions, gaps, and constraints. |

### Git & Release Management

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/github-pull` | Yes | Pulls latest changes from remote. |
| `/github-sync` | Yes | Commits and pushes changes to GitHub. |

### Meta / Orchestration

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/meta-init` | Yes | Full new-project workflow. Chains scaffold, interview, context, and build plan. |
| `/meta-join` | Yes | Join an existing project. Full onboard (7 steps) or quick catch-up. |
| `/meta-review` | Yes | Runs multiple review lenses in parallel and synthesizes findings. |
| `/review-fix` | Yes | Implement fixes from review findings. Parses findings, presents items for approval. |
| `/meta-production` | Yes | Scored production readiness assessment (READY / CONDITIONAL / NOT READY) across 12 dimensions. |
| `/meta-context-save` | Yes | Save session state and optionally commit+clear. End-of-session workflow. |

### Research

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/claude-light-research` | Yes | Lightweight research with artifact DB storage. Claude researches naturally — no subagent fan-out, no adversarial debate. Everyday research. |
| `/claude-deep-research` | Yes | Claude-only deep research with steelman debate. ~15 workers, convergence scoring. No external CLIs required. |
| `/claude-deep-research-execute` | Internal | Opus subagent for Claude-only deep research. Dispatched by `/claude-deep-research`. |

### Infrastructure

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/deploy-gateway` | Internal | Deploy, rebuild, or restart the MCP gateway container. CI images, Traefik labels, health checks. |
| `/infra-health` | Internal | Check service health — containers, endpoints, Uptime Kuma, Prometheus alerts. |

### Skill Management

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/skill-forge` | Yes | Creates or edits skills. Scaffolds directory, writes SKILL.md from template. |
| `/skill-doctor` | Yes | Self-diagnostic for the skill suite. Run after install or when a skill fails. |

### Utility (internal)

| Skill | Description |
|-------|-------------|
| `/init-db` | Initializes artifact store (`artifacts/project.db`, SQLite+FTS5). Idempotent. |
| `/test-gen` | Generates tests from test-review findings or for untested code. |
| `/log-gen` | Generates logging instrumentation from log-review findings. |

### Session & Scheduling

| Skill | Invocable | Description |
|-------|:---------:|-------------|
| `/loop` | Yes | Run a prompt or slash command on a recurring interval (e.g., `/loop 5m /foo`). |
| `/schedule` | Yes | Create, update, list, or run scheduled remote agents (triggers) on a cron schedule. |
| `/update-config` | Yes | Configure Claude Code harness — hooks, permissions, env vars, settings.json. |
| `/keybindings-help` | Yes | Customize keyboard shortcuts and keybindings. |

### Archived / Deprecated

| Skill | Replacement |
|-------|-------------|
| `/project-scaffold` | Use `/project-organize` instead |
| `/clean-project` | Use `/project-organize` instead |
| `/meta-research` | Use `/claude-light-research` instead |
| `/research-execute` | Use `/claude-light-research` instead |
| `/meta-deep-research` | Use `/claude-deep-research` instead |
| `/meta-deep-research-execute` | Use `/claude-deep-research-execute` instead |
| `/ralph-workflow` | Merged into `/feature-dev` Ralph mode |
| `/release-prep` | Just instructions — Claude does this from a prompt |
| `/repo-create` | Just instructions — Claude does this from a prompt |
| `/sync-skills` | Just instructions — compare and copy |
| `/todo-features` | Just instructions — Claude does this from a prompt |
| `/meta-execute` | Requires 5 external CLIs (Codex, Copilot, Cursor, Gemini, Vibe) |
| `/codex` | CLI driver — orphaned after meta-execute archived |
| `/copilot` | CLI driver — orphaned after meta-execute archived |
| `/cursor` | CLI driver — orphaned after meta-execute archived |
| `/gemini` | CLI driver — orphaned after meta-execute archived |
| `/vibe` | CLI driver — orphaned after meta-execute archived |

---

## Quick Reference: Common Workflows

| I want to... | Use |
|---------------|-----|
| Start a new project from scratch | `/meta-init` |
| Join an existing project | `/meta-join` |
| Build a feature | `/feature-dev` |
| Plan before building | `/build-plan` or `/quick-plan` |
| Run a comprehensive review | `/meta-review` |
| Fix review findings | `/review-fix` |
| Check if we can ship | `/meta-production` |
| Research a topic | `/claude-light-research` |
| Deep research a topic | `/claude-deep-research` |
| Commit and push | `/github-sync` |
| Prepare a release | `gh release create` (no skill needed) |
| Create a new skill | `/skill-forge` |
| Diagnose skill issues | `/skill-doctor` |
| Save session and wrap up | `/meta-context-save` |
| Search past decisions | `memory_call > search` (Qdrant) |
| Find entity relationships | `graph_call > query` (Neo4j) |
| Check project status | `project_call > get_project` |
| Manage secrets | `vault_call` |
| Monitor services | `/infra-health` or `uptime_call` |
