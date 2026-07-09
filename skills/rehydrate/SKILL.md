---
name: rehydrate
description: "Orient a fresh agent into an existing project by reading the load-bearing artifacts in the documented order (GROUNDING, CLAUDE, plan doc, last notebook entries, GOTCHAS, artifact DB, MCP memory). Read-only for project state; bounded session-bookkeeping and session-janitor memory writes ARE part of the contract. Default: apply ≤5 memory auto-heals after rehydrate. Use at session start, after /clear, when picking up a project after time away, or when an agent feels disoriented. Triggers on 'rehydrate', 'orient me', 'load me into <project>', 'catch me up', and explicit /rehydrate."
argument-hint: "[topic — focus for memory rehydrate] [--quick] [--no-mcp] [--no-pipeline] [--no-hygiene]"
---

# rehydrate

Load an agent into a project by reading the load-bearing artifacts in the order
documented in `behavioral-reminders.txt` and the project's own CLAUDE.md.

**Read-only for project state.** The skill does not scaffold, create
notebook entries, or modify plans/docs/code. If artifacts are missing,
report — do not create them. Use `/project-organize` for scaffolding,
`/meta-join` for full onboard.

**Bounded writes ARE allowed** — two classes:

1. **Session bookkeeping** — Step 6 (`coordination_call > register_session`
   etc.) and any steps a project's `.claude/rehydrate-extra.md` declares
   (discipline-gate audit records, memory digest writeback). Continuity
   between sessions, not project-state changes.
2. **Session janitor (Step 8, default on)** — ≤5 memory auto-heals
   (supersede / update / confirm / tag). Removes gunk from the active
   surface so the next agent is not steered by stale claims. Supersede-only
   — never `memory_call > delete`. Not a full `/memory-sleep` pass.

**If you skip bookkeeping or janitor citing "read-only," you are misreading
the contract** — the read-only boundary is project state (code, plans, docs,
notebooks), not session metadata or memory-surface cleanup. Documented
failure mode 2026-05-13 PM in quicklinks-g3-enterprise: fresh agent treated
rehydrate-extra writes as violations, skipped them, broke memory continuity.

## When to use

- Session start, immediately after the `SessionStart` hook fires
- After `/clear` or context compaction in a long session
- Picking a project back up after days/weeks away
- Director handing a fresh subagent into a project (subagent runs this first)
- Any time the agent feels uncertain about project state

## Input

- `topic` (optional, positional) — focus string for `gateway_call > rehydrate`
  and `db_search`. Defaults to project slug. Examples: `"phase D firmware"`,
  `"bench bring-up"`, `"network architecture"`.
- `--quick` — tier-1 only (GROUNDING + CLAUDE + last 1 notebook entry). Skip
  MCP, pipeline, artifact DB. Use when you just need the why+how, not the
  recent journey.
- `--no-mcp` — skip MCP gateway calls (Qdrant/Neo4j/pipeline). Use offline or
  when the gateway is degraded. Don't fail the whole rehydration on a gateway
  miss either way; this flag just suppresses the attempt.
- `--no-pipeline` — skip `project_call > list_phases` but keep memory rehydrate.
- `--no-hygiene` — orient only: skip Step 8 session janitor (no memory auto-heals).
  Use when you only need the contract and recent context without touching Qdrant
  writes. Default is janitor **on** when MCP rehydrate runs.

## Instructions

### 1. Detect project root + slug

- Project root = git root of cwd. If not in a git repo, use cwd.
- Project slug = derive from the directory name in lowercase-kebab. Override
  if `GROUNDING.md` declares one (e.g. a `project_slug:` frontmatter line, or
  a "Project slug:" line in the header).
- If the path matches a known mapping (e.g. `QL-G3-Enterprise` →
  `quicklinks-g3-enterprise`), prefer that — `gateway_call > rehydrate`
  expects the pipeline slug, not the directory name.

### 2. Detect load-bearing artifacts

Build a present/absent map. Report it before reading anything. This is the
single most useful output of the skill — it tells the agent what kind of
project it has landed in.

| Artifact | Path | Required? |
|---|---|---|
| GROUNDING.md | `<root>/GROUNDING.md` | strongly recommended |
| CLAUDE.md | `<root>/CLAUDE.md` | strongly recommended |
| Plan doc | `<root>/artifacts/plans/current.md` (file or symlink) | long-arc projects |
| Engineering notebook | `<root>/ENGINEERING-NOTEBOOK.md` | long-arc projects |
| GOTCHAS.md | `<root>/GOTCHAS.md` | optional, scan-before-risk |
| Artifact DB | `<root>/artifacts/project.db` + `<root>/artifacts/db.sh` | long-arc projects |
| Project-specific extension | `<root>/.claude/rehydrate-extra.md` | optional |
| PROGRESS.md | `<root>/PROGRESS.md` | long-arc projects — the NOW file (current state, blockers; standard as of 2026-07-07) |

If `GROUNDING.md` is missing entirely, stop and tell the user this looks like
an unorganized project — suggest `/project-organize` and exit.

### 3. Read tier 1 — always

- **GROUNDING.md** — full read. The why, the constraints, the anti-patterns.
- **CLAUDE.md** — full read. The how-to-work-here, the SSH patterns, the
  reading-order overrides for this specific project.
- **Follow CLAUDE.md's "read once per session" pointers** — language like
  "read once per session", "read this AFTER GROUNDING", "Overrides ... on
  conflict". Chase every hit before tier 2. Skipping them is a known failure
  mode (agents treat CLAUDE.md as terminal and ignore project behavior rules).

These reads are the contract. Everything else is journey/state.

### 4. Read tier 2 — if present (skip on `--quick` except last notebook entry)

- **`artifacts/plans/current.md`** — full read. Active phase, exit gates.
- **`PROGRESS.md`** — full read if present. Note any "URGENT correction"
  callouts at the top before any other content.
- **GOTCHAS.md** — full read if small (<500 lines), else scan section headers
  and read sections relevant to `topic`.
- **Last 2-3 ENGINEERING-NOTEBOOK entries** — never full-read this file
  (often megabytes). Use:
  ```bash
  grep -n "^## Entry " ENGINEERING-NOTEBOOK.md | tail -3
  ```
  Then `Read` with `offset` + `limit` from the last `^## Entry ` line to EOF.
  On `--quick`, read only the most recent entry.

### 5. Artifact DB — if present and not `--quick`

```bash
export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
source artifacts/db.sh
db_list | head -20            # 20 most recent records, headlines only
db_search "<topic>" | head -10  # if topic provided
```

Surface record IDs and labels. Don't dump full record bodies — the agent reads
specific records on demand once it knows what's there.

### 6. MCP Gateway rehydrate — if available and not `--no-mcp` / `--quick`

Calls (skip silently if a call errors — don't fail the whole rehydration):

- `gateway_call > rehydrate {topic, project_slug}` — pulls Qdrant memories,
  recent activity, graph context in one shot. This is the primary memory call.
- `project_call > list_phases {project_slug}` — active phases. Skip on
  `--no-pipeline`.
- `interagent_call > inbox {from: <machine_id>}` — cross-machine assignments.
  Read `C:\dev\.machine-id` for machine_id.
- `coordination_call > register_session {session_id, cwd, project, hostname}`
  — registers this agent so other sessions/machines can see it. Best-effort.

Specific UUID fetches (e.g. governing memories named in PROGRESS.md head)
belong in the project-specific extension (step 7), not here. The generic
skill does not know which UUIDs matter.

### 7. Project-specific extension — if `.claude/rehydrate-extra.md` exists

Read and follow it verbatim (format below). Bounded writes in the extension
are session-bookkeeping — honor them; do not skip as "read-only" (see intro).
Surface failures in the report; a broken extension means project drift.

### 8. Session janitor (MCP only; skip on `--quick` / `--no-mcp` / `--no-hygiene`)

Bounded memory auto-heal: remove gunk from the *active surface* so this session
is not steered by stale claims. Full tiers, examples, and boundary vs
`/memory-sleep` → **`references/session-janitor.md`** (read it before acting).

**Must follow (summary):**

- **Quota:** ≤5 writes (`supersede` / `update` / `confirm` / tag) or ~60s; never
  unbounded; never `delete`
- **Sources:** hygiene block top findings → semantic audit vs GROUNDING /
  PROGRESS / pipeline / git → cheap structural checks
- **Auto-heal:** broken supersede links; clear stale-vs-pipeline state;
  tag import noise `gunk,exclude-from-default`; `confirm` verified truths
- **Ask/stop:** patent/protected/evolution; true contradictions; cluster
  consolidate; any delete
- **Over quota:** highest-confidence first; list deferred; optional hygiene
  subagent with same quota if findings > ~10

### 9. Report

One concise summary, scannable. Template:

```
## Rehydration — <project-slug> — <timestamp>

**Project:** <one-line from GROUNDING.md "why this exists">
**Active phase:** <from plan doc / pipeline>
**Last notebook entry:** Entry <N> — <title> (<date>, <type>)

**Artifacts present:** GROUNDING ✓ CLAUDE ✓ plan ✓ notebook ✓ GOTCHAS ✓ DB ✓ extra ✓
**Artifacts missing:** <list, or "none">

**Recent activity (DB):**
- <id>: <label> (<date>)
- <id>: <label> (<date>)

**Governing memories:** <2-4 search hints surfaced from rehydrate>

**Hygiene:** N fixed (brief what), M deferred, K need Matt — or "skipped (--no-hygiene|--quick|--no-mcp)" or "none"

**Suggested first action:** <e.g. "read artifacts/plans/current.md exit gate
before proposing work" or "run baseline bench reproduction per CLAUDE.md
First-10-Minutes step 6">
```

Keep it under 300 words. The agent now has the mental model; further reads
are on-demand.

## Examples

```
User: /rehydrate
```
Detect project, read tier 1+2, query artifact DB, MCP rehydrate with topic =
project slug, run extension if present, session janitor (≤5 auto-heals), report.

```
User: /rehydrate phase D firmware
```
Same, but `topic = "phase D firmware"` for memory + DB search focus.

```
User: /rehydrate --quick
```
GROUNDING + CLAUDE + last notebook entry only. No MCP, no DB, no pipeline,
no janitor. Use when you just need the contract and recent context.

```
User: /rehydrate --no-mcp
```
All local reads, skip gateway calls and janitor. Use offline.

```
User: /rehydrate --no-hygiene
```
Full orient including MCP, but skip Step 8 memory auto-heals. Use when you
must not write to Qdrant this turn.

```
[GROUNDING.md missing]
```
Stop. Report: "No GROUNDING.md found at <root>. This project isn't organized.
Run `/project-organize` to scaffold, then re-run `/rehydrate`."

## Non-goals

Does **not**: scaffold (`/project-organize`); full onboard (`/meta-join`);
reviews; `/memory-sleep` or hard delete; change project state (code/docs/
plans/notebooks); full notebook read; unbounded memory cleanup.

**Does allow:** Step 6 MCP including `register_session`; extension bookkeeping
writes; Step 8 janitor (≤5 supersede/update/confirm/tag). Skip janitor only via
`--no-hygiene` / `--quick` / `--no-mcp`. Skipping bookkeeping or janitor as
"read-only" misreads the intro.

## Project-specific extension format

`<project-root>/.claude/rehydrate-extra.md` — plain agent instructions, <100
lines. Execute steps; report failures. Example shape:

```markdown
# rehydrate-extra — <project>
1. Fetch governing memories by UUID from PROGRESS.md head (`memory_call > get`)
2. Run project probes (e.g. bench_state.sh); fail the report if unhealthy
3. Read any "first action" checklists named by the project
```

## References (on-demand)

- `references/session-janitor.md` — Step 8 tiers, quota, boundary vs sleep

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
