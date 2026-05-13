---
name: rehydrate
description: "Orient a fresh agent into an existing project by reading the load-bearing artifacts in the documented order (GROUNDING, CLAUDE, plan doc, last notebook entries, GOTCHAS, artifact DB, MCP memory). Read-only for project state; bounded session-bookkeeping writes (register_session, plus whatever .claude/rehydrate-extra.md authorizes) ARE part of the contract. Use at session start, after /clear, when picking up a project after time away, or when an agent feels disoriented. Triggers on 'rehydrate', 'orient me', 'load me into <project>', 'catch me up', and explicit /rehydrate."
argument-hint: "[topic — focus for memory rehydrate] [--quick] [--no-mcp] [--no-pipeline]"
---

# rehydrate

Load an agent into a project by reading the load-bearing artifacts in the order
documented in `behavioral-reminders.txt` and the project's own CLAUDE.md.

**Read-only for project state.** The skill does not scaffold, create
notebook entries, modify plans/docs, or auto-fix hygiene flags. If
artifacts are missing, report — do not create them. Use
`/project-organize` for scaffolding, `/meta-join` for full onboard.

**Bounded session-bookkeeping writes ARE allowed** — specifically, the
calls in Step 6 (`coordination_call > register_session` etc.) and any
steps a project's `.claude/rehydrate-extra.md` declares (e.g. a discipline
gate script that writes a `SESSION-START-AUDIT` DB record + memory
digest writeback). These exist to enable continuity between agent
sessions, not to change project state. **If you skip them citing the
"read-only" rule, you are misreading the contract** — the read-only
boundary is around project state (code, plans, docs, notebooks), not
around session metadata. Documented failure mode 2026-05-13 PM in
quicklinks-g3-enterprise: fresh agent treated rehydrate-extra writes as
violations of the read-only rule, skipped them, broke memory continuity.

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
| Legacy PROGRESS.md | `<root>/PROGRESS.md` | obsolete per behavioral-reminders, but read if present |

If `GROUNDING.md` is missing entirely, stop and tell the user this looks like
an unorganized project — suggest `/project-organize` and exit.

### 3. Read tier 1 — always

- **GROUNDING.md** — full read. The why, the constraints, the anti-patterns.
- **CLAUDE.md** — full read. The how-to-work-here, the SSH patterns, the
  reading-order overrides for this specific project.

These two are the contract. Everything else is journey/state.

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

Read and follow it verbatim. This is the project's hook for extending
rehydration with steps the generic skill cannot know about. **Extensions
may include bounded writes** (discipline-gate audit records, memory
digest writebacks, register_session calls, etc.) — these are
session-bookkeeping, not project state changes, and the "read-only"
contract in the skill's intro explicitly carves them out. Examples:

- Fetch specific governing Qdrant memories by UUID
- Run a bench-state probe (`bash bench/bench_state.sh --brief`)
- Verify a deployed binary md5 matches the documented binary
- Read project-specific agent templates (e.g. `docs/agent-templates/pre-test-checklist.md`)
- Apply a "first action of session is always X" gate that writes a
  `SESSION-START-AUDIT` record (or equivalent) to the artifact DB
- Write a memory-digest payload back to the audit record after the
  agent fetches recent Qdrant memories

**Honor the extension's writes as written.** Skipping an extension step
because "the skill is read-only" misreads the contract — the read-only
rule applies to project state (code, plans, docs, notebooks), not to
session-bookkeeping the extension explicitly authorizes. If you defer an
extension write, flag the conflict explicitly in the report rather than
silently choosing the skill's intro language over the extension.

If the extension file references commands or scripts that fail, surface
the failure in the report — do not silently swallow it. A broken
extension is a signal the project state has drifted.

### 8. Hygiene check — light, inline

Compare what came back from MCP rehydrate against what GROUNDING.md says.
Specific cheap checks:

- Do governing memories cited in GROUNDING.md / CLAUDE.md actually return from
  Qdrant? (search by hint, not UUID)
- Does the active phase per pipeline match the active phase per
  `artifacts/plans/current.md`?
- Does PROGRESS.md (if present) cite a firmware version / state that
  contradicts the latest notebook entry?

Report inconsistencies as flags. **Do not auto-fix.** That is `/hygiene-check`'s
job, run separately when the agent is ready to act on findings.

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

**Hygiene flags:** <list, or "none">

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
project slug, run extension if present, report.

```
User: /rehydrate phase D firmware
```
Same, but `topic = "phase D firmware"` for memory + DB search focus.

```
User: /rehydrate --quick
```
GROUNDING + CLAUDE + last notebook entry only. No MCP, no DB, no pipeline.
Use when you just need the contract and recent context.

```
User: /rehydrate --no-mcp
```
All local reads, skip gateway calls. Use offline.

```
[GROUNDING.md missing]
```
Stop. Report: "No GROUNDING.md found at <root>. This project isn't organized.
Run `/project-organize` to scaffold, then re-run `/rehydrate`."

## Non-goals

The skill does NOT:

- Scaffold project structure (use `/project-organize`)
- Run a full-onboard interview (use `/meta-join`)
- Run reviews (use `/meta-review` family)
- Auto-fix hygiene flags (use `/hygiene-check`)
- Create notebook entries, modify plans, or change project state (code, docs, notebooks, plans)
- Read the full `ENGINEERING-NOTEBOOK.md` — bounded to last 2-3 entries

What the skill DOES allow (these are NOT in the "no writes" non-goal):

- The MCP calls in Step 6, including `coordination_call > register_session` which writes coordination state
- Whatever bounded writes a project's `.claude/rehydrate-extra.md` authorizes (e.g. discipline-gate audit records, memory-digest writebacks). These are session-bookkeeping, not project state changes — see Step 7.

If you find yourself wanting to skip an extension write citing "the skill is read-only," re-read the intro. The read-only boundary is project state, not session metadata.

## Project-specific extension format

Projects extend rehydration by writing `<project-root>/.claude/rehydrate-extra.md`.
The file is plain instructions for an agent. Keep it under 100 lines. Example
shape:

```markdown
# rehydrate-extra — <project>

After the generic /rehydrate steps, do these:

1. Read PROGRESS.md head for governing memory UUIDs. Fetch each via
   `memory_call > get` (don't rely on rehydrate previews).
2. Run `bash bench/watcher_status.sh` and `bash bench/bench_state.sh`.
   Verify watcher verdict is HEALTHY or ARMED.
3. Read `docs/agent-templates/pre-test-checklist.md` before any bench action.
4. Verify deployed CM4 binary md5 matches the binary documented in
   PROGRESS.md head.

If any check fails, surface in the rehydration report and do NOT proceed
with bench work until resolved.
```

The generic skill reads and follows this file but does not interpret its
content beyond "execute the steps and report failures."

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
