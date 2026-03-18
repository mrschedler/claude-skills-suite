---
name: meta-execute
description: Parallel implementation from a build plan using cross-model Best-of-2 (Vibe+Cursor) and 5-reviewer panel. Use when an approved project-plan.md exists and multi-unit execution should begin.
---

# meta-execute

Meta-skill that decomposes a build plan into work units and executes them in
parallel using cross-model generation (Vibe + Cursor), with a 5-reviewer
panel (Codex + Sonnet + Cursor + Copilot + Gemini) and Claude as orchestrator.

**Context-window strategy**: Implementation runs in Vibe/Cursor workers.
Reviews run in Codex + subagents. The main thread only handles orchestration
(queue management, verdict synthesis, retry decisions) — never reads full
implementation code for comprehension. Exception: the main thread MAY run
mechanical verification commands (lint, type-check, grep for stubs) via Bash
for Best-of-2 candidate selection.

**Research basis**: Design principles from 002D deep research
(208 cited sources). Key insight: orchestration topology > model selection >
prompt engineering. Cross-model Best-of-N provides more diversity than
same-model N>1. See `artifacts/research/summary/002D-meta-execute-quality.md`.

```
Delegation key:
  [S] = subagent   — runs out of main context
  [I] = inline     — stays in main thread
  [V] = Vibe       — Mistral CLI (fast generation)
  [C] = Cursor     — Cursor Agent CLI (generation or review)
  [X] = Codex      — Codex CLI (review+fix)
  [W] = worker     — any external CLI agent (disposable)

  Decomposition[I] -> Pool Setup[I] ->
    ┌──────────────────── per wave ────────────────────┐
    │ Context Assembly[I] -> Generation[V+C]            │
    │   -> Verify & Pick[I] -> 5-Reviewer Panel[X+S+C] │
    │   -> Merge[I] -> github-sync -> meta-review       │
    │   -> User Approval Gate                           │
    └──────────────────────────────────────────────────┘
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

Check availability of all CLIs. Load each driver skill for its path
discovery pattern:
- `/vibe` — generation CLI path discovery
- `/cursor` — Cursor Agent CLI path discovery
- `/codex` — Codex CLI path discovery
- `/copilot` — Copilot CLI path discovery
- `/gemini` — Gemini CLI path discovery

Note which CLIs are available (available / unavailable) before proceeding.

**Generation requires both Vibe AND Cursor** for cross-model Best-of-2. If
either is unavailable, fall back:
- Vibe unavailable → use Codex as second generator alongside Cursor
- Cursor unavailable → use Codex as second generator alongside Vibe
- Both unavailable → fall back to Codex-only Best-of-2 (original pattern)
- Note any fallbacks to the user.

**Review requires Codex** (the only reviewer that applies fixes). If Codex is
unavailable, fall back to Sonnet subagents for all 5 review slots.
Copilot and Gemini are optional reviewers — skip if unavailable.

**Pool limits — generation** (conservative start, raise after validation):
- Vibe: **2 concurrent** (hard max: 3)
- Cursor: **2 concurrent** (hard max: 3)
- Best-of-2: each WU consumes 1 Vibe + 1 Cursor slot → **2 WUs at a time**
- Trivial units (<50 LOC, single file): Skip Best-of-2, use Vibe-only (N=1)

**Pool limits — review** (5-reviewer panel):
- Codex: 2 concurrent (of 5 max) — reserved for review+fix
- Cursor `--mode ask`: 2 concurrent (freed from generation as WUs complete)
- Copilot: 2 concurrent (hard max: 2)
- Gemini: 2 concurrent (hard max: 2)
- Sonnet subagents: 2 concurrent (no hard limit, matching review throughput)
- All 5 reviewers for a single WU run in parallel
- **2 WUs can be reviewed simultaneously** (Copilot/Gemini bottleneck)

**Pipeline stagger**: Generation and review overlap. When WU-1's generation
finishes, its Cursor slot frees up for WU-1's review while WU-2's Cursor
is still generating. This keeps Cursor ≤ 3 total (2 generating + 1 reviewing).

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

#### Generation Strategy: Cross-Model Best-of-2

For each work unit, generate **2 candidates** using **different models** in
parallel. Cross-model diversity provides stronger candidate variation than
same-model N>1 (SWE-Master TTS, S* framework).

**Generators:**
- **Vibe** (Mistral/Codestral) — fast generation, code-optimized
- **Cursor** (configurable model, default `sonnet-4.6-thinking`) — full
  tool access, built-in worktree isolation

1. Dispatch both generators with the **same prompt** (from `agents/worker.md`):

   - **Vibe candidate** — load `/vibe` for invocation syntax. Write prompt to
     `/tmp/wu-{ID}-prompt.md`, invoke with 180s timeout, `--workdir <project-root>`.
     Output goes to `/tmp/wu-{ID}-vibe.md`.
   - **Cursor candidate** — load `/cursor` for invocation syntax. Write prompt to
     `/tmp/wu-{ID}-prompt.md`, invoke with 300s timeout, worktree `wu-{ID}-cursor`.
     Output goes to `/tmp/wu-{ID}-cursor-output.md`.

   Launch both with `run_in_background: true`. Do NOT poll.

2. When both complete, run **quick verification** on each candidate via
   Bash commands (mechanical gate-checking, not code comprehension):
   - Lint pass (no errors)
   - Type-check pass (no errors)
   - Unit tests pass (if tests exist)
   - Stub detection: `grep -rn '// \.\.\.\|TODO\|implement later\|placeholder' <files>`
3. Store verification results in the artifact DB for traceability:
   ```bash
   source artifacts/db.sh
   db_write 'meta-execute' 'verification' '{WU-ID}-vibe' "$VIBE_RESULTS"
   db_write 'meta-execute' 'verification' '{WU-ID}-cursor' "$CURSOR_RESULTS"
   ```
4. Select the candidate that passes more gates. If tied, prefer the one
   with fewer LOC (simpler = better). Record the selection:
   ```bash
   db_write 'meta-execute' 'selection' '{WU-ID}' "selected: vibe|cursor, reason: ..."
   ```
5. If both fail verification, generate a **fresh attempt with a different
   approach** — do not iterate on either broken candidate. On retry, swap
   models (e.g., Cursor with a different `--model`, Vibe with a different `--agent` config).

**Exception**: Skip Best-of-2 for trivial units (<50 LOC, single file).
Use Vibe-only (N=1) for these — it's the fastest generator.

**Vibe output handling**: Vibe generates text output (not file writes).
After selecting a Vibe candidate, apply the generated code to the project
files using Claude's Edit tool or a Codex worker with the Vibe output as
context. Cursor candidates write files directly via `--force`.

#### Queue Management (Wave-Gated)

Execution proceeds **one wave at a time**. Do NOT start Wave N+1 until
Wave N completes, passes review, merges, and the user approves.

Maintain a work queue with states: `ready`, `in-progress`, `done`,
`failed`, `blocked`.

**Within a single wave:**

1. Identify all `ready` units in the **current wave only**.
2. Assign ready units to worker slots respecting concurrency:
   - Best-of-2: **2 WUs at a time** (2 Vibe + 2 Cursor slots)
   - Trivial N=1 (Vibe-only): 2 slots, can mix with 1 Best-of-2 WU
3. As each generator pair/single completes, run quick verification and select best.
4. Dispatch 5-reviewer panel for the selected candidate (Phase 4).
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

#### Generator Invocations

Write the worker prompt (from `agents/worker.md`) to a temp file first:
```bash
cat > /tmp/wu-{ID}-prompt.md << 'PROMPT_EOF'
... filled worker.md template ...
PROMPT_EOF
```

**Vibe generator** — load `/vibe` for exact invocation syntax. Key params:
prompt file `/tmp/wu-{ID}-prompt.md`, 180s timeout, `--workdir <project-root>`,
output to `/tmp/wu-{ID}-vibe-output.md`. Vibe outputs text, not file writes.

**Cursor generator** — load `/cursor` for exact invocation syntax. Key params:
prompt file `/tmp/wu-{ID}-prompt.md`, 300s timeout, worktree `wu-{ID}-cursor`,
`--workspace <project-root>`, output to `/tmp/wu-{ID}-cursor-output.md`.
Cursor writes files directly via `--force`.

Use `run_in_background: true` for both Bash calls. Do NOT poll — wait for
notification of completion.

Store execution output in the artifact DB:
```bash
source artifacts/db.sh
db_write 'meta-execute' 'execution-log' '{WU-ID}-vibe' "$VIBE_OUTPUT"
db_write 'meta-execute' 'execution-log' '{WU-ID}-cursor' "$CURSOR_OUTPUT"
```

#### Applying Vibe Output

Vibe generates text (code blocks in markdown), not file writes. After
selecting a Vibe candidate as the winner:
1. Parse the code blocks from the output
2. Apply via Claude's Edit/Write tools, OR
3. Dispatch a short Codex worker with `--sandbox workspace-write` that
   receives the Vibe output as "implement exactly this code" context

Cursor candidates are already applied via `--force` in the worktree.

#### Fallback Generators

If the primary generators are unavailable:

| Missing CLI | Fallback |
|-------------|----------|
| Vibe only | Codex `exec --sandbox workspace-write` as second generator |
| Cursor only | Codex `exec --sandbox workspace-write` as second generator |
| Both | Codex Best-of-2 (original pattern) with Sonnet subagent fallback |

Codex fallback invocation — load `/codex` for invocation syntax. Key params:
`--sandbox workspace-write`, `--ephemeral`, `--cd <project-root>`, 180s timeout.
Prompt source: `/tmp/wu-{ID}-prompt.md` via stdin
(`- < /tmp/wu-{ID}-prompt.md`).

Sonnet subagent fallback:
1. Each subagent receives the same prompt built from `agents/worker.md`.
2. Use `isolation: "worktree"` for parallel subagents to avoid file conflicts.
3. Subagents have full tool access (Read, Write, Edit, Bash, Grep, Glob).

### Phase 4: 5-Reviewer Panel [Multi-Model]

**Context-window strategy**: Dispatch 5 reviewers per completed work unit
across different models. Each reviewer scores the code independently. The
main thread synthesizes verdicts — it never reads full implementation code.
Codex is the only reviewer that applies fixes; the other 4 are read-only
advisors.

#### Reviewer Panel Composition

All 5 reviewers launch in parallel for each WU. Read `agents/reviewer.md`
for the shared review prompt template. Fill in [WU-ID], [description],
acceptance criteria, conventions, and the **worktree path or branch name**.

| # | Reviewer | CLI | Mode | Role | Invocation |
|---|----------|-----|------|------|------------|
| 1 | **Codex** | codex exec | review+fix | Reads code, reviews against rubric, applies fixes in-place | See `agents/codex-reviewer.md` |
| 2 | **Sonnet** | subagent | Agentic Rubrics | Generates checklist from spec BEFORE reading code | `agents/reviewer.md` (unchanged) |
| 3 | **Cursor** | agent --mode ask | read-only review | Reviews with thinking model, full codebase access | Read-only, no writes |
| 4 | **Copilot** | copilot -p | read-only review | Different model perspective (claude/gpt) | Read-only, no writes |
| 5 | **Gemini** | gemini -p | best practices | Web-grounded review for industry patterns | Read-only, no writes |

**Do NOT add reviewers beyond what is listed.** 5 is the panel size.

#### Reviewer Invocations

Write the review prompt to a file first (from `agents/reviewer.md`, with
all placeholders filled):
```bash
cat > /tmp/wu-{ID}-review-prompt.md << 'REVIEW_EOF'
... filled reviewer.md template ...
REVIEW_EOF
```
For Codex specifically, feed the prompt file via stdin. Do not inline it as
`$(cat /tmp/...md)`.

**1. Codex (review+fix)** — the only reviewer that writes files.
Load `/codex` for invocation syntax. Key params: `--sandbox workspace-write`,
`--ephemeral`, `--cd <worktree-or-branch-path>`, 180s timeout.
Prompt source: `/tmp/wu-{ID}-codex-review-prompt.md` via stdin
(`- < /tmp/wu-{ID}-codex-review-prompt.md`). Output to
`/tmp/wu-{ID}-review-codex.md` via `-o`.
Uses the specialized prompt from `agents/codex-reviewer.md` which includes
fix-application instructions.

**2. Sonnet subagent** — Agentic Rubrics (unchanged from original):
```
Agent tool with prompt from agents/reviewer.md, model: sonnet
```

**3. Cursor (read-only)** — freed from generation, now reviews.
Load `/cursor` for invocation syntax. Key params: `--mode ask`,
`--workspace <worktree-or-branch-path>`, 120s timeout.
Prompt: `$(cat /tmp/wu-{ID}-review-prompt.md)`. Output to
`/tmp/wu-{ID}-review-cursor.md`.

**4. Copilot (read-only)** — load `/copilot` for invocation syntax.
Key params: `--add-dir <worktree-or-branch-path>`, 120s timeout.
Prompt: `$(cat /tmp/wu-{ID}-review-prompt.md)`. Output to
`/tmp/wu-{ID}-review-copilot.md`.

**5. Gemini (best practices)** — load `/gemini` for invocation syntax.
Key params: 120s timeout. Prompt: `$(cat /tmp/wu-{ID}-review-prompt.md)`.
Output to `/tmp/wu-{ID}-review-gemini.md`.
Gemini fallback: if unavailable or times out, retry with Copilot (using a
different `--model`). If both fail, proceed with 4 reviewers.

Launch all 5 with `run_in_background: true`. Do NOT poll.

#### Verdict Synthesis

After all 5 reviewers return, the main thread synthesizes (NEVER rely on
subagents to write to the DB — extract response text and write via
`db_upsert` in the main thread):

```bash
source artifacts/db.sh
db_write 'meta-execute' 'review' '{WU-ID}-codex' "$CODEX_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-sonnet' "$SONNET_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-cursor' "$CURSOR_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-copilot' "$COPILOT_REVIEW"
db_write 'meta-execute' 'review' '{WU-ID}-gemini' "$GEMINI_REVIEW"
```

**Synthesis rules:**
- **3+ of 5 ACCEPT** (or MINOR_FIX that Codex already fixed) → **ACCEPT**
- **Any reviewer flags REJECT** → Codex applies fixes informed by ALL 5
  reviewer perspectives, then one more Sonnet pass to verify the fix
- **Disagreement (2 ACCEPT, 2 REJECT, 1 MINOR_FIX)** → Claude reads the
  5 summaries (NOT the code) and makes the call. Escalate to user if
  uncertain.
- **Unanimous REJECT** → classify failure type and retry (see below)

Store the synthesized verdict:
```bash
db_upsert 'meta-execute' 'verdict' '{WU-ID}' "$SYNTHESIZED_VERDICT"
```

**Confidence scoring** (for the completion summary):
- 5/5 agree: HIGH confidence
- 4/5 agree: HIGH confidence
- 3/5 agree: MEDIUM confidence
- Disagreement requiring Claude synthesis: LOW confidence (flag for user)

#### Processing Verdicts

Based on the synthesized verdict:

- **ACCEPT**: Mark the unit as `done`. Update `project-plan.md` via the
  evolve-plan pattern (mark complete, append changelog).
- **MINOR_FIX**: If Codex already applied fixes during its review pass,
  verify with one more Sonnet pass. If clean, mark `done`.
- **REJECT**: Mark as `failed`. Classify the failure type (see retry logic).
  The unit goes back in the queue for retry.

#### Retry Logic: Failure Classification

**Transient errors** (syntax, import, type errors — the code approach is
sound but has mechanical bugs):
- Retry with error output appended to context. Max 3 retries.
- Codex can often fix these directly during its review+fix pass.

**Permanent errors** (logic gaps, architectural misunderstanding, wrong
approach — the fundamental strategy is flawed):
- Do NOT retry the same approach. This wastes tokens without progress.
- Generate a **fresh attempt with a different approach** (new prompt angle).
  Swap generator models (e.g., different `--model` for Cursor, different
  `--agent` config for Vibe). See `/cursor` and `/vibe` for syntax.
- If 2nd fresh attempt also fails: escalate to Opus review for feedback,
  then one more attempt with Opus feedback included.
- 3rd failure on permanent errors: flag for human review. Move to `blocked`.

How to classify: If the rejection mentions wrong logic, missing understanding,
architectural mismatch, or wrong API usage → permanent. If it mentions
syntax, missing import, wrong type, formatting → transient.

#### Pipeline Optimization

Reviews run in parallel with ongoing generation. When WU-1's generation
finishes while WU-2 is still generating:
1. WU-1's Cursor slot frees → available for WU-1's Cursor review
2. WU-1's Vibe slot frees → available for next WU's generation
3. Dispatch WU-1's 5-reviewer panel immediately — do not wait for WU-2

This staggered pipeline keeps all CLI slots productive and respects
concurrency limits (Cursor never exceeds 3: max 2 generating + 1 reviewing).

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

4. **Logging pass (optional)**: If the meta-review from any wave flagged
   log-review findings, suggest running `/log-gen` as a post-implementation
   pass to add logging instrumentation to the newly generated code. LLM-
   generated code almost never includes adequate logging — this catches it
   before the first production incident.

Note: each wave was already committed & pushed via `/github-sync` at its
gate, and each wave already received a `/meta-review`. No additional
push or review is needed at this stage unless the user requests one.

## Error Handling

### Timeout Guards

- Set a mental time limit of 5 minutes per phase. If a phase has not produced output in 5 minutes, check if the subprocess is still running.
- For Gemini CLI calls: always use `$GTIMEOUT` with skill-appropriate values (120s for read-only analysis, 180s for larger prompts). If it times out, skip and note "Gemini timed out — skipping."
- For Codex CLI calls: always use `$GTIMEOUT` with skill-appropriate values (120s for read-only review, 180s for generation or large prompts). Same fallback.
- If a subagent has been running for more than 10 minutes with no output, consider it stalled and move on.
- Report any timeouts in the completion summary so the user knows what was skipped.

### Budget Cap

Each work unit gets a maximum of **6 worker invocations** (2 for Best-of-N
initial generation + up to 4 retries across transient/permanent paths). If a
unit exhausts its budget, it moves to `blocked` for human review regardless
of failure type. This prevents cost spirals on intractable problems.

## Constraints

- **Claude is the orchestrator, not the implementer.** Claude reads plans,
  assigns work, synthesizes verdicts, manages the queue. Claude does NOT
  write application code directly unless applying a Vibe candidate's output.
- **Workers are disposable.** Each Vibe/Cursor/Codex/Sonnet invocation is
  stateless and ephemeral. All context must be passed in the prompt — do
  not assume workers remember previous invocations.
- **Concurrency ceilings.** Vibe: 2 (conservative start, hard max 3).
  Cursor: 2 generating + 1 reviewing = 3 max. Codex: 2 reviewing (of 5
  max). Copilot: 2. Gemini: 2. With Best-of-2, this means 2 WUs generating
  and 2 WUs reviewing at a time.
- **5-reviewer panel is mandatory.** No work unit is marked `done` without
  all 5 reviewers scoring it. Codex reviews+fixes; Sonnet, Cursor, Copilot,
  Gemini provide read-only perspectives. 3/5 agreement required for ACCEPT.
  Unreviewed code is untrusted code.
- **Codex is editor, not coder.** Codex's role is review+fix, not
  generation. Vibe and Cursor handle generation. This is a higher-value
  use of Codex's capabilities.
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
