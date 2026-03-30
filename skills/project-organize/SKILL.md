---
name: project-organize
description: "Organizes any project — new or existing — with GROUNDING.md, engineering notebook, and clean structure. Subsumes project-scaffold and clean-project. Use when a project needs structure, onboarding docs, or cleanup."
---

# project-organize

Get any project to the point where a cold-start agent can be productive in
under 2 minutes. Detects what exists, creates what's missing, fixes what's stale.

## What it creates

Every project gets these two files (minimum viable onboarding):

| File | Purpose |
|------|---------|
| **GROUNDING.md** | WHY — product context, decisions, constraints, anti-patterns |
| **CLAUDE.md** | QUICKSTART — reading order, access patterns, guardrails |

Created if the project warrants them:

| File | When to create |
|------|---------------|
| **ENGINEERING-NOTEBOOK.md** | Projects with significant design history (hardware, multi-sprint, exploratory) |
| **project-context.md** | Technically complex projects (multiple services, non-obvious architecture) |
| **CURRENT-STATE.md** | Projects with live devices or deployed infrastructure |
| **PLAN-*.md** | Projects with active development roadmaps |

Does NOT create: coterie.md, cnotes.md, todo.md, features.md, project-plan.md, prd.json, progress.txt (per cross-cutting rule 2).

## Inputs

| Input | Source | Required |
|---|---|---|
| Project root path | cwd or user prompt | Yes |
| Project name | GROUNDING.md, README, user, or directory name | Yes |

## Instructions

### Phase 1: Discover (read-only)

Before creating or changing anything, understand what exists.

#### 1.1 Read GROUNDING.md

If it exists, read it. It's the authority on this project. Everything
else must be consistent with it.

#### 1.2 Inventory existing files

Catalog root files and directories. Categorize each root file as:
- **Project docs**: GROUNDING.md, ENGINEERING-NOTEBOOK.md, CLAUDE.md,
  project-context.md, CURRENT-STATE.md, PLAN-*.md, README.md
- **Config**: .gitignore, package manifests, Dockerfile, CI config
- **Stale/legacy**: Files that predate GROUNDING.md and may conflict
- **Unknown**: Assess case-by-case

#### 1.3 Read existing documentation

Read ALL markdown files at root and in docs/. Note:
- Product name inconsistencies (old names, old SKU structure)
- "What's next" sections that describe completed or abandoned work
- Reading order conflicts (multiple files claiming "read this first")
- Dates of last update vs. recent git commits (staleness)

#### 1.4 Mine memory systems (if MCP Gateway available)

Search all layers for project context. This is what turns a shallow
GROUNDING.md into a rich one.

```
# Qdrant — narrative context, decisions, gotchas
memory_call > search {query: "<project-name> architecture decisions", limit: 15}
memory_call > search {query: "<project-name> gotcha failure lesson", limit: 10}

# MongoDB — reference documents, research
mongodb_call > find_documents {db: "homelab", collection: "docs",
  filter: {slug: {$regex: "<project-slug>"}}}

# Obsidian — vault notes (via Qdrant obsidian source)
memory_call > search {query: "<project-name>", limit: 10,
  tags: "source:obsidian"}

# Neo4j — entity relationships
graph_call > find_node {name: "<ProjectNodeName>"}
graph_call > get_neighbors {name: "<ProjectNodeName>", depth: 2}

# Project pipeline — sprints, tasks, stage
project_call > get_project {slug: "<pipeline-slug>"}
```

Skip gracefully if MCP is not available — memory enriches but doesn't block.

#### 1.5 Read git history

```bash
git log --oneline --reverse          # full chronological history
git log --oneline -5                 # recent activity
git log --format="%ad %s" --date=short | head -1   # project start date
```

#### 1.6 Classify the project

Determine: empty vs. existing, needs notebook?, needs project-context?, needs
CURRENT-STATE?, has pipeline entry?, has stale docs?

Present the classification to the user:
> "Project assessment:
> - [NEW/EXISTING] project, [N] files, started [date]
> - GROUNDING.md: [EXISTS/MISSING]
> - Engineering notebook: [EXISTS/MISSING] — [RECOMMEND/SKIP] because [reason]
> - Stale docs: [list or 'none']
> - Pipeline entry: [EXISTS slug / MISSING]
>
> Plan: [Create GROUNDING.md + notebook, fix N stale docs, update pipeline]
> Proceed? (y/n/adjust)"

Wait for confirmation before writing anything.

### Phase 2: Create missing docs

#### 2.1 GROUNDING.md (if missing)

This is the most important deliverable. Use the template below and fill
it from Phase 1 discovery (memories, git history, existing docs, user input).

```markdown
# GROUNDING.md — {{PROJECT_NAME}}

> Read this before touching code. It explains why this project exists,
> what matters, and what will hurt if you get it wrong.

## Why This Exists
[Problem, who has it, why now. 2-3 paragraphs max.]

## What Matters
[2-4 bullets: the things that matter most]

## Key Decisions
| Decision | Alternatives Considered | Why This One |
|----------|------------------------|--------------|

## Tech Stack
[Languages, frameworks, hardware, hosting — with version constraints]

## Constraints
[Hard limits: budget, timeline, platform, compliance, hardware]

## What Will Hurt If You Get It Wrong
[Anti-patterns specific to THIS project. Numbered list. Each one is a
learned lesson — if it's in GROUNDING.md, someone already got burned.]

## Current State
[What exists today. Last updated date. Phase/sprint if applicable.]

## Key Documents
| Document | Purpose |
|----------|---------|

## Related Projects
| Project | Repo | Relationship |
|---------|------|-------------|
```

**Quality bar:** A fresh agent reading only GROUNDING.md should understand
what the project is, what it must not do, and where to look next. If the
GROUNDING.md requires reading other files to make sense, it's too thin.

#### 2.2 CLAUDE.md (if missing or doesn't reference GROUNDING.md)

Create or update to include:
1. "Read GROUNDING.md first" as step 1
2. Reading order for all project docs
3. Rehydrate step if pipeline exists:
   `gateway_call > rehydrate {topic: "<name>", project_slug: "<slug>"}`
4. SSH access patterns if applicable
5. Default credentials if applicable (product defaults, not secrets)
6. Guardrails specific to this project

#### 2.3 ENGINEERING-NOTEBOOK.md (if recommended and user approved)

Run `/notebook-init` or create directly using the notebook template.
Seed Entry 0 from git history and memories. If the project has significant
history, backfill key entries from:
- Git commits (milestones, pivots, bug fixes)
- Qdrant memories (decisions, gotchas, failures)
- Dev logs (if they exist in the repo)

Evidence references use Qdrant search hints, not UUIDs:
`Qdrant: search "keywords describing the memory"`

#### 2.4 .gitignore (if missing or thin)

Create or expand based on the project's tech stack. Always include:
```
.env
*.log
tmp/
.cache/
*.bak
*~
```

Add language/framework-specific patterns as detected.

#### 2.5 Pipeline entry (if missing and MCP available)

Create via `project_call > create_project` with:
- Accurate description from GROUNDING.md
- Correct stage and priority
- Tags matching the project's domain

### Phase 3: Fix stale docs

For each stale doc found in Phase 1.3:

#### Staleness patterns and fixes

| Pattern | Fix |
|---------|-----|
| File says "read this first" but isn't GROUNDING.md | Remove banner, add redirect to GROUNDING.md |
| File uses old product/SKU name | Replace with current name |
| "What's next" describes completed/abandoned work | Update to current status or mark as historical |
| File predates GROUNDING.md and overlaps heavily | Replace content with redirect to GROUNDING.md |
| File has useful operational detail but stale framing | Add header: "Historical context from [date]. See GROUNDING.md for current state." |
| File references pipeline/sprints that no longer exist | Update or remove references |

**Rule:** Preserve operational detail. Dev bench procedures, SSH patterns,
deployment steps, and troubleshooting guides retain value even when the
project framing changes. Add context headers, don't delete content.

#### Specific patent boundary check

If the project has a related patent repo, scan for:
- Specific patent claim numbers (replace with general "covered by patent #X")
- Prior art analysis or legal strategy
- Inventor's notebook content

These must live in the patent repo, not the engineering repo.

### Phase 4: Audit structure

Run the structural checks from `/clean-project` Phase 1:

- **Root census**: Flag >20 files, categorize each
- **Orphan detection**: Files nothing references (exclude convention-based files)
- **Gitignore coverage**: Verify generated/ephemeral content is ignored
- **Naming consistency**: Check for convention drift
- **Archive candidates**: Superseded or deprecated files → `archive/`

Present findings with severity levels. Ask before executing changes.

### Phase 5: Commit and store

1. **Commit** all changes with a descriptive message documenting what was
   created, updated, and archived.

2. **Store Qdrant memory** summarizing what was done:
   "Project [name] organized: GROUNDING.md [created/updated], notebook
   [created with N entries / skipped], [N] stale docs fixed, pipeline
   [created/updated]. Key files: [list]."

3. **Update Neo4j** if new entity relationships were discovered.

4. **Present summary** to user with the reading order a new agent would follow.

## Adapting to project type

Read `references/type-adaptations.md` for type-specific guidance.

## Exit condition

- GROUNDING.md exists and a fresh agent can understand the project from it alone
- CLAUDE.md references GROUNDING.md as step 1
- No root docs claim "read this first" unless they're GROUNDING.md or CLAUDE.md
- No stale docs send agents to pursue wrong-era work
- .gitignore covers generated/ephemeral content
- All changes committed and pushed

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
