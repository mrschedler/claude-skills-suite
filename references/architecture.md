# Integrated Architecture: Skills, MCP Gateway, Hooks, and Memory

> How Claude Code's skills, hooks, MCP tools, and memory stores work together
> as one system. This is the reference for porting, onboarding, and debugging.

---

## System Overview

Three foundation projects form one integrated system:

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code CLI                       │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐    │
│  │ CLAUDE.md│  │  Skills  │  │      Hooks         │    │
│  │ (config) │  │ (44 active│  │ (6 lifecycle events)│    │
│  └──────────┘  └──────────┘  └────────────────────┘    │
└───────────────────────┬─────────────────────────────────┘
                        │ MCP over streamable HTTP
                        ▼
┌─────────────────────────────────────────────────────────┐
│              MCP Gateway (Unraid/DeepThought)            │
│              mcp.epiphanyco.com/mcp                      │
│                                                          │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────────────┐ │
│  │ Memory │ │ Graph  │ │Project │ │   34 modules     │ │
│  │(Qdrant)│ │(Neo4j) │ │Pipeline│ │   300+ tools     │ │
│  └────────┘ └────────┘ └────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

| Project | Role | Location |
|---------|------|----------|
| **Skills Suite** | Execution patterns — what agents do | `C:\dev\claude-skills-suite` |
| **MCP Gateway** | Infrastructure — tools agents call | Unraid, `mcp.epiphanyco.com/mcp` |
| **Memory System** | Persistence — how knowledge survives sessions | Qdrant + Neo4j + MongoDB + artifact DB |

---

## Session Lifecycle

```
SESSION START
│
├─ session-prewarm.sh (hook)
│  ├─ Read GROUNDING.md
│  ├─ gateway_call > rehydrate {topic, project_slug}
│  │   ├─ Qdrant: narrative memories
│  │   ├─ Neo4j: entity relationships
│  │   ├─ Project pipeline: sprints, tasks
│  │   ├─ Preferences
│  │   └─ Unanswered questions
│  ├─ interagent_call > inbox (pending assignments)
│  ├─ coordination_call > register_session
│  └─ mattermost_call > create_post (session thread)
│
├─ User triggers skill (e.g., /feature-dev)
│  ├─ SKILL.md loaded
│  ├─ Skill reads project context (GROUNDING.md, artifact DB)
│  ├─ Skill executes (may call MCP tools)
│  └─ Skill writes results (files, artifact DB, Qdrant)
│
├─ During execution (hooks fire on tool use)
│  ├─ PreToolUse (Bash): search-before-act.sh → gotcha recall
│  ├─ PreToolUse (Bash): pre-commit-lint.sh → blocks bad commits
│  └─ PostToolUse (Edit/Write): post-edit-complexity.sh → complexity gate
│
├─ On git commit
│  └─ post-commit-memory-sync.sh → memory checkpoint reminder
│
├─ On context compaction
│  └─ pre-compact-capture.sh → snapshots git state + modified files
│
SESSION END (2nd stop)
│
└─ session-end-summary.sh (hook)
   ├─ activity_call > sessions (fetch tool call summary)
   ├─ memory_call > store (session log to Qdrant)
   ├─ mattermost_call > reply_to_post (session thread)
   └─ coordination_call > deregister_session
```

---

## MCP Gateway

**Endpoint:** `https://mcp.epiphanyco.com/mcp`
**Transport:** MCP over streamable HTTP (not SSE, not stdio)
**Auth:** Cloudflare Access service tokens
**Path:** Client → Cloudflare Tunnel → Traefik → homelab-mcp-gateway:3500

**Tool pattern:** Every module exposes `{module}_list` and `{module}_call`.
Self-describing — agents discover tools without documentation.

**Auto-enrichment:** All Qdrant/Neo4j writes auto-inject `recorded_at`.
Embeddings use `nomic-embed-text-v1.5` (768-dim, 8K context, local ONNX model — no API dependency).

### Core Modules

| Module | Purpose |
|--------|---------|
| **memory** | Qdrant vector store — store, search, update, consolidate, rehydrate |
| **graph** | Neo4j knowledge graph — entities, relationships, merge operations |
| **project** | Project pipeline — sprints, tasks, research, architecture |
| **task** | Universal work tracking (PG-backed) |
| **coordination** | Multi-agent session coordination and signaling (Redis-backed) |
| **interagent** | Cross-machine agent messaging — inbox, claim, complete |
| **activity** | Activity logging — tracks all tool calls and sessions |
| **gateway** | Self-management, health, **rehydrate** (5-in-1 compound tool) |

### Data Stores

| Module | Purpose |
|--------|---------|
| **pg** | PostgreSQL queries |
| **mongodb** | MongoDB databases, collections, aggregation |
| **redis** | Redis cache/broker — key ops, pub/sub |
| **vault** | HashiCorp Vault secrets (KV v2) |

### Infrastructure

| Module | Purpose |
|--------|---------|
| **docker** | Container management via socket proxy |
| **n8n** | Workflow automation |
| **traefik** | Reverse proxy inspection (read-only) |
| **prometheus** | Metrics and monitoring |
| **uptime** | Uptime Kuma availability monitoring |
| **recipe** | Container recipe templates (Vault-backed) |

### External Integrations

| Module | Purpose |
|--------|---------|
| **github** | Repos, issues, PRs, releases |
| **browser** | Playwright-based web automation |
| **figma** | Design files, components, styles |
| **mattermost** | Team chat (LAN-only, backup notifications) |
| **telegram** | Bot messaging and notifications |
| **contacts** | CRM across PG, Neo4j, and Qdrant |
| **obsidian** | Vault indexing and semantic search |
| **dify** | Self-hosted AI app builder |
| **openhands** | Autonomous coding agent |
| **ai** | OpenRouter — call other LLMs |
| **context7** | Up-to-date library/framework docs |
| **workspace** | Workspace orchestration (GitLab, OpenHands, Figma) |
| **blueprint** | Agent blueprints with guardrails |

---

## Memory Architecture

Seven layers, each with distinct scope:

| Layer | Store | Scope | What It Holds | Access |
|-------|-------|-------|---------------|--------|
| **Narrative** | Qdrant | Cross-project | WHY — decisions, reasoning, gotchas | `memory_call` |
| **Structure** | Neo4j | Cross-project | WHAT connects — entities, dependencies | `graph_call` |
| **Reference** | MongoDB | Cross-project | Full documents — research, architecture plans | `mongodb_call` |
| **Pipeline** | PostgreSQL | Cross-project | Sprints, tasks, events, questions | `project_call` |
| **Preferences** | Qdrant | Cross-project | Work patterns, tool preferences | `memory_call` (category: preference) |
| **Human Notes** | Obsidian | Cross-project | Daily notes, guides, runbooks | `obsidian_call` |
| **Project Detail** | SQLite | Per-project | Full findings, debate rounds, story completions | `artifacts/db.sh` |

### Memory Types and Decay

| Type | Half-life | Examples |
|------|-----------|---------|
| **Semantic** | 365 days | Decisions, architecture, solutions, preferences |
| **Episodic** | 60 days | Session logs, auto-summaries, email intelligence |
| **Procedural** | 180 days | Workflows, runbooks, how-tos |

Auto-classified from tags at write time. Staleness decay applied at search time.

### Dual-Write Pattern

Skills that produce findings write to BOTH stores:

```bash
# Per-project detail (artifact DB)
source artifacts/db.sh
db_write "skill" "phase" "label" "content"

# Cross-project narrative (Qdrant)
memory_call > store
  content: [self-contained narrative]
  tags: [skill, project, type]
  category: {project-slug}
```

---

## Hook System

Six hooks registered in `settings.json`. All are bash scripts.

| Hook | Event | Blocks? | MCP Dependencies |
|------|-------|---------|-----------------|
| `session-prewarm.sh` | SessionStart | No | coordination, task, activity, mattermost, interagent |
| `pre-compact-capture.sh` | PreCompact | No | None |
| `search-before-act.sh` | PreToolUse (Bash) | No | None (reads local cache) |
| `pre-commit-lint.sh` | PreToolUse (Bash) | **Yes** | None (local linters) |
| `post-edit-complexity.sh` | PostToolUse (Edit/Write) | **Yes** | None (local linters) |
| `post-commit-memory-sync.sh` | PostToolUse (Bash) | No | None |
| `session-end-summary.sh` | Stop (2nd only) | No | activity, memory, mattermost, coordination |

### Hook Design Principles

- **Value test:** benefit must exceed token cost + latency + context pollution
- **Never block unless safety-critical:** only lint and complexity hooks block
- **Hooks enforce protocol so skills don't have to:** rehydration, memory sync,
  coordination happen automatically
- **Session-end fires on 2nd stop only:** avoids wasting SSH round-trips on
  mid-conversation responses

---

## Skills Architecture

44 active skills in `skills/`, 18 archived in `skills/archive/`.

### How Skills Reference MCP Tools

Skills document MCP usage as pseudo-code — the executing agent decides how:

```markdown
memory_call > search {query: "auth decisions", limit: 5}
graph_call > find_node {name: "AuthMiddleware"}
```

**Rule 5:** MCP is optional. Skills gracefully degrade without gateway access.

### Skill Categories

| Category | Skills | Pattern |
|----------|--------|---------|
| **Development** | feature-dev, ui-design, simplify, claude-api | Router to right rigor level |
| **Planning** | quick-plan, build-plan, sub-project, sub-project-merge | Structured output templates |
| **Project Lifecycle** | meta-init, meta-join, project-organize, project-context, evolve, notebook-init | Chain other skills |
| **Research** | claude-light-research, claude-deep-research + execute | Artifact DB + Qdrant storage |
| **Review Lenses** | 13 review skills + meta-review + review-fix | Parallel execution, findings format |
| **Infrastructure** | deploy-gateway, infra-health | Homelab-specific |
| **Skill Management** | skill-forge, skill-doctor | Meta — skills about skills |
| **Session** | meta-context-save, loop, schedule | Lifecycle management |

### Skill Composition Hierarchy

```
meta-init (greenfield)
├── project-questions
├── project-organize
│   └── notebook-init
└── build-plan

meta-join (existing project)
├── project-organize
├── meta-review
│   ├── security-review
│   ├── completeness-review
│   ├── test-review
│   └── drift-review
├── project-context
└── build-plan

feature-dev (daily driver)
├── Simple: just do it
├── Medium: light plan → implement
└── Complex (Ralph mode):
    ├── Requires: project-organize first
    ├── prd.json (task definitions)
    ├── PROGRESS.md (10-line state pointer)
    ├── artifact DB (story completions)
    └── Qdrant (lessons learned)
```

### Cross-Cutting Rules (10)

1. Read GROUNDING.md first
2. No project litter
3. Agent-agnostic (describe WHAT, not HOW)
4. External CLI gating with fallback
5. MCP optional, graceful degradation
6. Windows + Git Bash compatible
7. 300-line limit, overflow to references/
8. Memory sync after significant work
9. Don't duplicate feature-dev
10. Driver skill boundary (don't embed CLI commands)

---

## For the Docker Port (Luke and Elise)

### What's Required

- Claude Code CLI
- MCP Gateway (lighter version — core modules only)
- SQLite (for artifact DB)

### What's Optional

- Mattermost (LAN-only, skip for laptop)
- Obsidian (nice to have, not required)
- Playwright (only for browser-review/ui-review)
- Neo4j (graph queries — most skills don't need it)

### What's NOT Needed

- External CLIs (Codex, Gemini, Vibe, Cursor, Copilot) — all archived
- meta-execute — archived, requires 5 CLIs
- Cloudflare Tunnel — only for public access, not needed on LAN

### Minimum Viable MCP Modules

| Module | Why |
|--------|-----|
| **memory** | Session rehydration, cross-session recall |
| **project** | Project pipeline, task tracking |
| **activity** | Session logging |
| **gateway** | Rehydrate compound tool |
| **coordination** | Multi-agent signals (if running multiple sessions) |

Everything else is enhancement. Skills degrade gracefully without them.
