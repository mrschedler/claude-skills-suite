---
name: meta-execute
description: Parallel implementation from a build plan using Codex workers (Sonnet fallback). Use when an approved project-plan.md exists and multi-unit execution should begin.
---

# meta-execute

Meta-skill that decomposes a build plan into work units and executes them in
parallel using a Codex worker pool, with Claude as orchestrator and reviewer.

**Context-window strategy**: Implementation runs in Codex/Sonnet workers.
Reviews run in subagents that write verdicts to the artifact DB
(skill=`meta-execute`, phase=`verdict`, label=`{WU-ID}`). The main thread
only handles orchestration (queue management, verdict processing, retry
decisions) — never reads full implementation code for comprehension.
Exception: the main thread MAY run mechanical verification commands (lint,
type-check, grep for stubs) via Bash for Best-of-N candidate selection.

**Research basis**: Design principles from 002D deep research
(208 cited sources). Key insight: orchestration topology > model selection >
prompt engineering. See `artifacts/research/summary/002D-meta-execute-quality.md`.

```
Delegation key:
  [S] = subagent   — runs out of main context
  [I] = inline     — stays in main thread
  [W] = worker     — Codex exec or Sonnet subagent (disposable)

  Decomposition[I] -> Pool Setup[I] ->
    ┌─────────────────── per wave ───────────────────┐
    │ Context Assembly[I] -> Execution[W] -> Review[S]│
    │   -> Merge[I] -> github-sync -> meta-review     │
    │   -> User Approval Gate                         │
    └─────────────────────────────────────────────────┘
    -> Completion[I]
```

## Inputs

| Input | Source | Required |
|---|---|---|
| project-plan.md | Project root | Yes |
| project-context.md | Project root | Yes |

**Note**: Workers do NOT receive the full codebase. Each worker gets a curated
context package (10k-50k tokens) assembled in Phase 3. Context stuffing
degrades output quality — less is more.

## Outputs

- Implemented code for each work unit
- Per-unit completion notes in artifact DB (skill=`meta-execute`, phase=`execution-log` or `verdict`, label=`{WU-ID}`)
- Updated `project-plan.md` (work units marked complete as they finish)

## Instructions

### Phase 1: Decomposition [Inline]

Read `project-plan.md` and `project-context.md`. If the plan already has
`LOC Est`, `Key Files`, and `Acceptance Criteria` columns (post-002D
build-plan format), this phase is a **validation and refinement pass** —
verify the estimates and add file ownership details. If the plan uses legacy
columns (`Complexity`, `Agent hint`), do a full re-decomposition.

For each work unit in the plan, determine:

1. **Independence**: Can this unit be implemented without waiting for another
   unit's output? Tag as `parallel` or `sequential`.

2. **Dependencies**: Which other work units must complete first? Build a
   dependency graph. A unit is ready when all its dependencies are satisfied.

3. **LOC estimate**: Estimate lines of code changed/added. Target the
   **50-200 LOC goldilocks zone** across 2-5 files. Units >200 LOC must be
   decomposed further. Units <50 LOC can be batched with related work.
   (Evidence: SWE-bench Pro median ~107 LOC; multi-commit features drop
   success from 74% to 11%.)

4. **File ownership**: List the specific files each unit modifies. Each
   **mutable file is owned by exactly one worker** — no two parallel units
   may modify the same file. Classify shared files:
   - **Read-only**: Type definitions, constants — safe to share freely
   - **Additive-only**: Central export files (index.ts), config arrays —
     safe to share but require **sequential merge lock** (merge these files
     one at a time in Phase 5 to avoid conflict)
   - **Mutable**: Everything else — exclusive ownership required

5. **Independently verifiable**: Each unit must produce at least one new or
   modified export that can be tested with a self-contained test file. If a
   unit can't be independently verified, it's scoped wrong — re-scope it.

6. **Wave assignment**: Group units into dependency waves. Wave 1 = all
   units with zero dependencies. Wave 2 = units whose dependencies are all
   in Wave 1. Wave N = units whose dependencies are all in Waves 1..N-1.
   Units within a wave run in parallel; waves run sequentially with a
   **mandatory review gate** between them (see Phase 3).

Present the decomposition to the user as a table:

```
| Unit | Wave | Status | Type | LOC Est | Dependencies | Owned Files | Shared Reads |
|------|------|--------|------|---------|--------------|-------------|--------------|
| WU-1 | 1    | ready  | parallel | ~80  | none         | src/a.ts    | types/...    |
| WU-2 | 1    | ready  | parallel | ~150 | none         | src/b.ts    | types/...    |
| WU-3 | 2    | blocked| sequential| ~60 | WU-1         | src/a.ts    | src/b.ts     |
```

Store the decomposition in the artifact DB for resume capability:
```bash
source artifacts/db.sh
db_upsert 'meta-execute' 'decomposition' 'table' "$DECOMPOSITION_TABLE"
```

**Exit condition**: User confirms the decomposition table. No file ownership
conflicts within the same wave. All units are in the 50-200 LOC range.
Wave assignments are visible and correct.

### Phase 2: Worker Pool Setup [Inline]

Check Codex availability using the dynamic path pattern:
```bash
CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
test -x "$CODEX" && echo "codex: available" || echo "codex: unavailable"
```

**If Codex is available**: Use Codex as the primary worker. Read
`../codex/SKILL.md` for invocation syntax. Always add `--skip-git-repo-check`.

**If Codex is unavailable**: Fall back to Sonnet subagents with worktree
isolation. Note the fallback to the user.

**Pool limits** (the math matters — get this right):
- Codex session limit: **5 concurrent** `codex exec` processes
- Active worktrees: **4 maximum** (CooperBench: 30% coordination penalty
  beyond this)
- With Best-of-N=2: each WU consumes **2 slots** during generation, so
  effective parallelism = **2 WUs at a time** (4 slots), with 1 slot
  reserved for overflow or review verification
- With N=1 (trivial units): up to 4 WUs at a time
- Sonnet subagent fallback: same 4-worktree cap applies, no Codex slot limit

### Phase 3: Context Assembly & Execution Loop [Inline + Workers]

#### Context Assembly (per work unit)

For each work unit, build a **curated context package** of 10k-50k tokens.
Read `agents/worker.md` for the prompt template — fill in all placeholders.

The context package contains:
1. Work unit specification + acceptance criteria (from the plan)
2. **Only the files this unit modifies** (full contents)
3. **Interface signatures** for directly imported modules (NOT implementations)
4. Relevant type definitions, constants, enums
5. Project conventions excerpt from `project-context.md` (keep under 2k tokens)

**Do NOT include**: full codebase, all project docs, change history, other
workers' specs, or unrelated files. Irrelevant context actively degrades
output (AGENTS.md study; SWE-Pruner: 23-54% token reduction with minimal
quality loss).

#### Generation Strategy: Best-of-N

For each work unit, generate **2 candidates** in parallel (Best-of-N with
N=2). This is the single highest-leverage quality investment — spending
compute on generation diversity beats sequential retry for catching logic
errors (SWE-Master TTS, S* framework).

1. Dispatch 2 workers with the **same prompt** for each unit.
   Use branch naming convention: `wu-{ID}-alpha` and `wu-{ID}-beta`.
2. When both complete, run **quick verification** on each candidate via
   Bash commands (this is mechanical gate-checking, not code comprehension):
   - Lint pass (no errors)
   - Type-check pass (no errors)
   - Unit tests pass (if tests exist)
   - Stub detection: `grep -rn '// \.\.\.\|TODO\|implement later\|placeholder' <files>`
3. Store verification results in the artifact DB for traceability:
   ```bash
   source artifacts/db.sh
   db_write 'meta-execute' 'verification' '{WU-ID}-alpha' "$ALPHA_RESULTS"
   db_write 'meta-execute' 'verification' '{WU-ID}-beta' "$BETA_RESULTS"
   ```
4. Select the candidate that passes more gates. If tied, prefer the one
   with fewer LOC (simpler = better). Record the selection:
   ```bash
   db_write 'meta-execute' 'selection' '{WU-ID}' "selected: alpha|beta, reason: ..."
   ```
5. If both fail verification, generate a **fresh attempt with a different
   approach** — do not iterate on either broken candidate.

**Exception**: Skip Best-of-N for trivial units (<50 LOC, single file).
Use N=1 for these.

#### Queue Management (Wave-Gated)

Execution proceeds **one wave at a time**. Do NOT start Wave N+1 until
Wave N completes, passes review, merges, and the user approves.

Maintain a work queue with states: `ready`, `in-progress`, `done`,
`failed`, `blocked`.

**Within a single wave:**

1. Identify all `ready` units in the **current wave only**.
2. Assign ready units to worker slots respecting concurrency:
   - With Best-of-N=2: **2 WUs at a time** (4 slots used, 1 reserved)
   - With N=1 (trivial units): up to **4 WUs at a time**
   - Mix allowed: 1 N=2 unit (2 slots) + 2 N=1 units (2 slots) = 4 slots
3. As each worker pair/single completes, run quick verification and select best.
4. Dispatch review subagent for the selected candidate (Phase 4).
5. Assign the next `ready` unit **from this wave** to freed slots.
6. Repeat until all units in this wave are `done` or `failed`.
7. Track queue state in the artifact DB for resume capability:
   ```bash
   source artifacts/db.sh
   db_upsert 'meta-execute' 'queue-state' 'current' "$QUEUE_JSON"
   ```

**After all units in the current wave complete:**

8. Merge all completed units from this wave (Phase 5 — sequential rebase).
9. Commit & push this wave's changes via `/github-sync`.
10. Run `/meta-review` on the cumulative codebase. This is the **wave gate**
    — a full 7-lens x 3-model review of the project in its current state.
11. Present the wave summary + meta-review synthesis to the user:
    ```
    Wave N complete.
    - Units completed: X/Y
    - Failed (needs human review): Z [list them]
    - Meta-review findings: [summary from review-synthesis.md]
    - Next wave: Wave N+1 has M units [list them]
    Continue to Wave N+1? (yes / fix issues first / stop)
    ```
12. **STOP and wait for user approval** before starting the next wave.
    Do NOT proceed automatically. The user may want to fix issues,
    adjust the plan, or stop execution entirely.
13. On approval, advance to the next wave. Mark its units as `ready`
    and return to step 1.

#### Codex Worker Invocation

```bash
CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
timeout 120 "$CODEX" exec "WORKER_PROMPT" \
  --full-auto --ephemeral --skip-git-repo-check \
  --cd <project-root> --add-dir <relevant-dirs>
```

Use `run_in_background: true` for Bash calls. Do NOT poll — wait for
notification of completion.

Store execution output in the artifact DB:
```bash
source artifacts/db.sh
db_write 'meta-execute' 'execution-log' '{WU-ID}' "$OUTPUT"
```

#### Sonnet Subagent Fallback

If using Sonnet subagents instead of Codex:

1. Each subagent receives the same prompt built from `agents/worker.md`.
2. Use `isolation: "worktree"` for parallel subagents to avoid file conflicts.
3. Subagents have full tool access (Read, Write, Edit, Bash, Grep, Glob).

### Phase 4: Review Each Unit [Subagent-Delegated]

**Context-window strategy**: Dispatch a review subagent per completed work
unit. The subagent scores the code against a rubric generated from the spec
— NOT from the code. The main thread only processes verdicts.

After each work unit completes (post-verification), dispatch a review
subagent. Read `agents/reviewer.md` for the full prompt template — fill in
[WU-ID], [description], acceptance criteria, conventions, and the
**worktree path or branch name** where the worker's changes live. The
reviewer must check the correct branch, not main.

The reviewer uses **Agentic Rubrics**: it generates a checklist from the
work unit specification BEFORE reading any implementation code. This prevents
anchoring bias (where reviewers justify what they see rather than checking
what should exist).

#### Processing Verdicts

Based on the subagent's verdict:

- **ACCEPT**: Mark the unit as `done`. Update `project-plan.md` via the
  evolve-plan pattern (mark complete, append changelog).
- **MINOR_FIX**: Apply fixes directly (Claude makes targeted edits based on
  the subagent's file:line references) or re-invoke the worker with the
  specific fix list. Then mark as `done`.
- **REJECT**: Mark as `failed`. Classify the failure type (see retry logic).
  The unit goes back in the queue for retry.

#### Retry Logic: Failure Classification

**Transient errors** (syntax, import, type errors — the code approach is
sound but has mechanical bugs):
- Retry with error output appended to context. Max 3 retries.
- Same worker type is fine.

**Permanent errors** (logic gaps, architectural misunderstanding, wrong
approach — the fundamental strategy is flawed):
- Do NOT retry the same approach. This wastes tokens without progress.
- Generate a **fresh attempt with a different approach** (new prompt angle).
- If 2nd fresh attempt also fails: escalate to Opus review for feedback,
  then one more Sonnet attempt with Opus feedback included.
- 3rd failure on permanent errors: flag for human review. Move to `blocked`.

How to classify: If the rejection mentions wrong logic, missing understanding,
architectural mismatch, or wrong API usage → permanent. If it mentions
syntax, missing import, wrong type, formatting → transient.

#### Parallel Review Optimization

Review subagents run in parallel with ongoing implementation workers.
When a worker completes WU-3 while WU-4 and WU-5 are still running,
dispatch the WU-3 review immediately — do not wait.

### Phase 5: Merge Strategy [Inline]

After units pass review, merge using **sequential rebase** in dependency
order (not all-at-once):

1. Merge the first completed unit's changes to the main working branch.
2. Rebase subsequent branches onto the updated main. Each merge gets the
   latest repository context.
3. For trivial conflicts (shared list entries, import additions), resolve
   automatically. For non-trivial conflicts, flag for human review.

4. After successful merge, **clean up the worktree**:
   ```bash
   git worktree remove <worktree-path> 2>/dev/null || true
   git branch -d wu-{ID}-alpha wu-{ID}-beta 2>/dev/null || true
   ```

This approach keeps <3 merge conflicts over extended work sessions when
file ownership is properly partitioned in Phase 1.

### Phase 6: Completion [Inline]

When all waves are done (the last wave's gate was approved):

1. **Tally results** across all waves:
   - Units completed successfully (and which wave each was in)
   - Units that required retries (note how many attempts, transient vs permanent)
   - Units that failed and are flagged for human review
   - Units still blocked (and what blocks them)
   - Number of waves executed, and meta-review findings per wave

2. **Update project-plan.md**: Run evolve-plan to mark all completed units
   and note any new work discovered during implementation.

3. **Present final summary** to the user:
   ```
   Execution complete.
   - Waves executed: W (with meta-review gate after each)
   - Completed: X/Y work units
   - Retried: R units (T transient, P permanent reclassified)
   - Failed (needs human review): Z units [list them]
   - Blocked: W units [list blockers]
   - New work discovered: N items [list them]
   ```

Note: each wave was already committed & pushed via `/github-sync` at its
gate, and each wave already received a `/meta-review`. No additional
push or review is needed at this stage unless the user requests one.

## Error Handling

### Timeout Guards

- Set a mental time limit of 5 minutes per phase. If a phase has not produced output in 5 minutes, check if the subprocess is still running.
- For Gemini CLI calls: always use `timeout 120` wrapper. If it times out, skip and note "Gemini timed out — skipping."
- For Codex CLI calls: always use `timeout 120` wrapper. Same fallback.
- If a subagent has been running for more than 10 minutes with no output, consider it stalled and move on.
- Report any timeouts in the completion summary so the user knows what was skipped.

### Budget Cap

Each work unit gets a maximum of **6 worker invocations** (2 for Best-of-N
initial generation + up to 4 retries across transient/permanent paths). If a
unit exhausts its budget, it moves to `blocked` for human review regardless
of failure type. This prevents cost spirals on intractable problems.

## Constraints

- **Claude is the orchestrator, not the implementer.** Claude reads plans,
  assigns work, reviews output, manages the queue. Claude does NOT write
  application code directly unless fixing a minor issue during review.
- **Workers are disposable.** Each Codex/Sonnet invocation is stateless and
  ephemeral. All context must be passed in the prompt — do not assume
  workers remember previous invocations.
- **4-worktree / 5-slot ceiling.** Never exceed 4 active worktrees or 5
  Codex sessions. With Best-of-N=2, this means 2 WUs generating at a time.
- **Review is mandatory.** No work unit is marked `done` without a review
  subagent scoring it against an Agentic Rubric. Unreviewed code is
  untrusted code.
- **No context stuffing.** Workers receive curated 10-50k token packages.
  Never pass the full codebase, full docs, or other workers' specifications.
- **Outcome > process.** Specify WHAT to build precisely. Leave HOW to the
  model. Over-specifying reasoning degrades performance.

## Examples

```
User: "Plan is approved. Let's build it."
Action: Read project-plan.md. Decompose into work units. Present the table.
        On confirmation, assemble context packages, spin up Best-of-N workers,
        and start the execution loop.
```

```
User: "/meta-execute"
Action: Same as above. Check that project-plan.md exists and is approved.
        If no plan exists, tell the user to run /meta-init first.
```

```
User: "Start building. Codex isn't working today."
Action: Check Codex availability — confirm unavailable. Fall back to Sonnet
        subagents with worktree isolation. Inform the user. Proceed with the
        same execution pattern using subagents instead.
```

```
User: "Resume execution — we stopped after WU-4 yesterday."
Action: Read project-plan.md. Identify which units are already marked done.
        Resume from the next ready unit. Do not re-execute completed work.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
