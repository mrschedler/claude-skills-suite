---
name: review-fix
description: Implement fixes from meta-review findings. Parses review-synthesis.md, presents actionable items for user approval, dispatches Codex/Sonnet workers, verifies fixes. Use after meta-review or any review lens.
---

# review-fix

Takes review findings and turns them into implemented fixes. Parses the
review synthesis, extracts actionable items, gets user approval, dispatches
workers to fix, verifies each fix, and commits.

**Context-window strategy**: Fix implementation runs in Codex/Sonnet workers.
Verification runs in subagents. The main thread only handles orchestration
(parsing, presenting, queue management, verdict processing). Never reads
full implementation code for comprehension.

```
Delegation key:
  [S] = subagent   — runs out of main context
  [I] = inline     — stays in main thread
  [W] = worker     — Codex exec or Sonnet subagent (disposable)

  Parse Findings[I] -> Present & Approve[I] -> Group Fixes[I] ->
    Worker Pool Setup[I] ->
    ┌──── per fix unit ────┐
    │ Context Assembly[I]   │
    │ -> Execution[W]       │
    │ -> Verification[S]    │
    │ -> Merge[I]           │
    └───────────────────────┘
    -> github-sync -> Summary[I]
```

## Inputs

| Input | Source | Required |
|---|---|---|
| review-synthesis-N.md | `artifacts/reviews/` | Yes (or DB) |
| project-context.md | Project root | Yes |
| Full codebase | Project root | Yes (for context assembly) |

**Finding the latest synthesis**: Syntheses are incrementally numbered.
Always use the highest-numbered file:
```bash
ls artifacts/reviews/review-synthesis-*.md 2>/dev/null | sort -t- -k3 -n | tail -1
```

**Alternative input**: If no synthesis file exists, check the artifact
DB for standalone review findings:
```bash
source artifacts/db.sh
db_read_all '{lens}' 'findings'
```

## Outputs

- Fixed code committed via `/github-sync`
- Per-fix verdicts in artifact DB (skill=`review-fix`, phase=`verdict`, label=`{FIX-ID}`)
- Fix summary presented to user

## Instructions

### Phase 1: Parse Findings [Inline]

1. Find and read the latest synthesis file:
   ```bash
   ls artifacts/reviews/review-synthesis-*.md 2>/dev/null | sort -t- -k3 -n | tail -1
   ```
   If no synthesis file exists, check the artifact DB for the most recent
   review findings across all lenses.

2. Extract every finding that has a **specific, actionable fix**. Skip:
   - Informational findings with no code change needed
   - Findings that say "consider" or "evaluate" without a concrete action
   - Findings already marked as resolved

3. For each actionable finding, extract:
   - **ID**: `RF-{NNN}` (sequential)
   - **Source lens**: which review lens found it (security, refactor, etc.)
   - **Severity**: CRITICAL / HIGH / MEDIUM / LOW
   - **Confidence**: HIGH / MEDIUM (from synthesis)
   - **Files affected**: specific file paths and line numbers
   - **Finding**: what's wrong
   - **Fix**: what needs to change

4. **Logging findings**: If findings from `log-review` are present, delegate
   those to `/log-gen` instead of implementing them as generic fix units.
   Log-gen understands logging patterns, logger setup, and structured logging
   conventions. Pass the log-review findings directly to log-gen.

5. Group remaining findings that touch the **same files** into a single fix unit.
   Rationale: a worker already has those files in context, so batching
   related findings reduces total worker invocations and avoids merge
   conflicts between fixes to the same file.

   Grouping rules:
   - Same file(s) affected → group
   - Different files but same logical concern → group if ≤ 3 findings
   - Cross-cutting findings (e.g., "add input validation everywhere") →
     keep as separate fix units per file/module boundary

### Phase 2: Present & Approve [Inline]

Present the fix list to the user as a numbered table:

```
| # | ID | Severity | Confidence | Files | Finding | Fix |
|---|-----|----------|------------|-------|---------|-----|
| 1 | RF-001 | HIGH | HIGH | src/auth.ts:42 | SQL injection in login | Use parameterized query |
| 2 | RF-002 | MEDIUM | HIGH | src/api.ts:15,28 | Missing input validation | Add zod schema validation |
| 3 | RF-003 | LOW | MEDIUM | src/utils.ts:90 | Unused import | Remove dead import |
```

Summary line:
```
X findings total: N CRITICAL, N HIGH, N MEDIUM, N LOW
Select fixes to apply: numbers (e.g., 1,2,5), range (1-3), or "all"
```

**STOP and wait for user selection.** Do NOT proceed until the user picks
which fixes to implement. The user may also:
- Ask for more detail on a specific finding
- Reject a finding as a false positive
- Modify a finding's fix description
- Add custom fix items not in the review

### Phase 3: Execute Fixes [Workers]

#### Worker Pool Setup

Check Codex availability — load `/codex` for the path discovery pattern.
Note whether Codex is available or unavailable.

**Pool limits** (from `general.md`):
- Codex: **5 concurrent** exec processes
- Active worktrees: **4 maximum**
- Without Best-of-N: up to **4 fix units at a time**
- Sonnet fallback: same 4-worktree cap

#### Context Assembly (per fix unit)

For each approved fix unit, build a curated context package. Read
`agents/fixer.md` for the prompt template — fill in all placeholders.

The context package contains:
1. The finding and required fix (from Phase 1)
2. **Only the files this fix touches** (full contents)
3. **Interface signatures** for directly imported modules
4. Project conventions excerpt from `project-context.md` (under 2k tokens)

**Do NOT include**: full codebase, all project docs, unrelated files.

#### Worker Dispatch

For each approved fix unit, dispatch a worker:

**Codex worker** — load `/codex` for invocation syntax. Key params:
`--sandbox workspace-write`, `--ephemeral`, `--cd <project-root>`, 180s timeout.
Prompt: `FIXER_PROMPT` (from `agents/fixer.md` with all placeholders filled).

**Sonnet fallback:**
Use `isolation: "worktree"` for parallel subagents. Each receives the same
prompt built from `agents/fixer.md`.

#### Queue Management

Maintain a queue with states: `ready`, `in-progress`, `done`, `failed`.

1. Assign `ready` fix units to worker slots (up to 4 at a time).
2. As each worker completes, dispatch verification subagent (Phase 4).
3. Assign the next `ready` unit to freed slots.
4. Repeat until all approved fixes are `done` or `failed`.

Track state in the artifact DB:
```bash
source artifacts/db.sh
db_upsert 'review-fix' 'queue-state' 'current' "$QUEUE_JSON"
```

### Phase 4: Verify Each Fix [Subagent-Delegated]

After each fix completes, dispatch a verification subagent. Read
`agents/verifier.md` for the prompt template — fill in placeholders.

The verifier checks:
1. The original finding is actually resolved
2. No regressions were introduced
3. No stubs or truncated code

#### Processing Verdicts

- **PASS**: Mark fix as `done`. Merge to main branch.
- **PARTIAL**: Apply remaining changes inline (Claude makes targeted edits).
  Re-verify. If passes, mark `done`.
- **FAIL**: Retry the fix with error context appended to prompt.

#### Retry Logic

Simpler than meta-execute — no transient/permanent classification:
- **Attempt 1**: Original fix prompt
- **Attempt 2**: Fix prompt + verification failure details
- **Attempt 3**: Escalate to Opus for a fix strategy, then one more worker attempt
- **After 3 failures**: Mark as `failed`, report to user. Do not loop further.

Budget cap: **3 worker invocations per fix unit**.

### Phase 5: Merge & Commit [Inline]

After all approved fixes complete:

1. Merge completed fixes using **sequential rebase** (same as meta-execute
   Phase 5). Merge in severity order: CRITICAL first, then HIGH, MEDIUM, LOW.

2. For trivial conflicts (import additions, list entries), resolve
   automatically. For non-trivial conflicts, flag for user.

3. Clean up worktrees:
   ```bash
   git worktree remove <worktree-path> 2>/dev/null || true
   git branch -d fix-{ID} 2>/dev/null || true
   ```

4. Run `/github-sync` to commit and push all fixes.

### Phase 6: Summary [Inline]

Present the fix summary to the user:

```
Review Fix complete.
- Approved: X fixes
- Completed: Y/X
- Failed (needs manual fix): Z [list them]
- False positives identified: N [list them]

Files modified: [list]
Commit: [hash]
```

If any fixes failed, recommend the user either:
- Fix them manually
- Re-run `/review-fix` after manual adjustments
- Mark them as accepted risks

## Error Handling

- If no `review-synthesis-*.md` files exist and no DB findings exist, tell
  the user to run `/meta-review` first.
- If Codex is unavailable, fall back to Sonnet subagents silently.
- If a fix unit touches files currently modified by another fix unit
  (shouldn't happen if grouping is correct), serialize them — do not
  run in parallel.
- Report all timeouts and failures in the summary.

## Examples

```
User: [after meta-review] "Fix the issues"
Action: Find latest review-synthesis-N.md. Present actionable findings as
        numbered list. Wait for user to pick which to fix. Execute approved fixes.
```

```
User: "/review-fix"
Action: Same flow. Find most recent review findings.
```

```
User: "Fix only the critical and high severity items"
Action: Present all findings but note the user wants CRITICAL+HIGH only.
        Pre-select those in the table. Confirm before executing.
```

```
User: "Fix 1,3,5"
Action: Execute fix units 1, 3, and 5 from the presented table.
        Skip all others.
```

```
User: "That's a false positive, skip it"
Action: Mark the finding as false positive. Remove from fix queue.
        Note in the summary for future reference.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
