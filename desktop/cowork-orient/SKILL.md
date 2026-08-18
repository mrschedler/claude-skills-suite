---
name: cowork-orient
description: Orients Cowork into a project folder — GROUNDING reading order, gateway rehydrate, Qdrant memory sync. Use before working in any connected project.
---

# Cowork Orient

Cowork loads no CLAUDE.md, no hooks, and no filesystem skills, so it starts blind in
project folders that Claude Code sessions navigate by protocol. This skill replaces the
session-start protocol: read the folder's load-bearing docs in order, rehydrate from
external state via the MCP gateway, and persist outcomes to Qdrant so Claude Code
sessions stay current.

## Inputs

- The connected project folder (any `C:\dev` project; self-documenting if it has a `GROUNDING.md`)
- MCP gateway tools if available: `memory_call`, `gateway_call`, `project_call` — these are
  enhancements, not requirements; skip gracefully when absent

## Outputs

- A stated orientation summary (project purpose, current phase, constraints) before any work begins
- Decisions, findings, and state changes stored to Qdrant via `memory_call > store`
- No new framework files in the project folder

## Instructions

### Phase 1: Read the folder

Read in this order, skipping files that don't exist:

1. `GROUNDING.md` — why the project exists, decisions made, what not to do
2. `CLAUDE.md` — quickstart, guardrails (Cowork does not auto-load this; read it manually)
3. `artifacts/plans/current.md` — the active plan
4. `ENGINEERING-NOTEBOOK.md` — last 3 entries only
5. `GOTCHAS.md` — scan for traps relevant to the task

Exit condition: you can state the project's purpose, current phase, and key constraints
in 2-3 sentences. State them to the user before starting work. If none of these files
exist, say so — the folder is not an organized project, so proceed on the user's
instructions alone and suggest organizing it from a Claude Code session later.

### Phase 2: Rehydrate from external state

If gateway MCP tools are available:

1. Call `gateway_call > rehydrate` with `{topic: <what the user is asking about>, project_slug: <slug>}`.
2. If the slug is unknown, find it via `project_call > list_projects` (match on folder name).
3. Treat recalled memories as background context reflecting what was true when written —
   verify anything load-bearing against the files before acting on it.

If the gateway is unavailable, note that to the user in one sentence and continue —
the folder docs from Phase 1 are sufficient to work safely.

### Phase 3: Ground rules while working

These are the suite's cross-cutting rules that apply inside Cowork:

- **No project litter** — create only files the user asked for; prefer updating existing
  docs over creating new ones.
- **Patent content never goes to chat channels** (Mattermost, Slack, Telegram). Git and
  immutable docs are the source of truth.
- **Mattermost is LAN-only, backup cron notifications only** — never project content.
- **artifacts/project.db** — query via `source artifacts/db.sh` only if `sqlite3` is
  available in the shell; otherwise leave findings in your output for the user to capture.
- **Memories are background, files are truth** — when a recalled memory conflicts with
  what the folder says, trust the folder and flag the conflict.

### Phase 4: Persist before finishing

If the session produced decisions, findings, or state changes worth remembering:

1. Search Qdrant first (`memory_call > search`) to avoid duplicating an existing memory;
   update rather than create when one already covers the topic.
2. Store the delta (`memory_call > store`) — self-contained content a zero-context session
   can understand, including the why. Tags: project name + type (decision, solution,
   state, gotcha) + relevant entity names. Category: the project name.
3. For significant work, append an `ENGINEERING-NOTEBOOK.md` entry in the project folder.
4. Work that needs a Claude Code session (commits/pushes, gateway code edits, anything
   SSH-dependent) — tell the user explicitly rather than attempting it from the VM.

Exit condition: external state reflects what happened, or the session genuinely produced
nothing worth persisting.

## Examples

```
User connects C:\dev\memory-system and asks about consolidation behavior.
→ Phase 1 reading order, rehydrate with topic "memory consolidation",
  slug "memory-system-optimization". Answer from docs + recall. Store nothing
  (no new decisions made).
```

```
User asks Cowork to draft a design decision in a project folder.
→ Orient (Phases 1-2), draft into the existing docs (no new files unless asked),
  store the decision to Qdrant with the why, note it for the notebook.
```

```
User connects a folder with no GROUNDING.md.
→ Report the folder is not an organized project, work from user instructions,
  suggest /project-organize from Claude Code later.
```
