---
name: review-fix
description: Implement fixes from review findings. Parses findings, presents actionable items for user approval, executes fixes, verifies. Use after meta-review or any review lens.
---

# review-fix

Takes review findings and turns them into implemented fixes. Parses findings,
extracts actionable items, gets user approval, implements fixes, verifies.

## When to use

- After `/meta-review` or any individual review lens
- User says "fix the issues", "implement the fixes"
- Review findings exist and need to be acted on

## Inputs

| Input | Source | Required |
|---|---|---|
| Review findings | meta-review output or individual lens output | Yes |
| GROUNDING.md | Project root | Yes |
| Full codebase | Project root | Yes |

## Instructions

### Phase 1: Parse Findings

1. Gather findings from the most recent review (meta-review synthesis or
   individual lens output).

2. Extract every finding with a **specific, actionable fix**. Skip:
   - Informational findings with no code change needed
   - "Consider" or "evaluate" without concrete action
   - Already resolved findings

3. For each actionable finding, extract:
   - **ID**: `RF-{NNN}` (sequential)
   - **Source lens**: which review found it
   - **Severity**: CRITICAL / HIGH / MEDIUM / LOW
   - **Files affected**: specific paths and lines
   - **Finding**: what's wrong
   - **Fix**: what needs to change

4. **Group findings** that touch the same files into a single fix unit.
   This reduces effort and avoids merge conflicts.

### Phase 2: Present & Approve

Present the fix list as a numbered table:

```
| # | ID | Severity | Files | Finding | Fix |
|---|-----|----------|-------|---------|-----|
| 1 | RF-001 | HIGH | src/auth.ts:42 | SQL injection in login | Parameterized query |
| 2 | RF-002 | MEDIUM | src/api.ts:15 | Missing validation | Add schema validation |
```

Summary: `X findings: N CRITICAL, N HIGH, N MEDIUM, N LOW`
`Select: numbers (1,2,5), range (1-3), or "all"`

**STOP and wait for user selection.** Do NOT proceed automatically.

### Phase 3: Execute Fixes

For each approved fix unit:

1. **Read the affected files** to understand current state
2. **Implement the fix** — make the minimum change needed
3. **Verify**: lint passes, no regressions, the original finding is resolved
4. If verification fails, retry with error context (max 3 attempts per fix)
5. After 3 failures, mark as `failed` and report

Execute fixes in severity order: CRITICAL first, then HIGH, MEDIUM, LOW.

The executing agent decides how to parallelize (worktree isolation for
parallel fixes, sequential for overlapping files).

### Phase 4: Summary

```
Review Fix complete.
- Approved: X fixes
- Completed: Y/X
- Failed (needs manual fix): Z [list them]

Files modified: [list]
```

If any fixes failed, recommend:
- Fix manually
- Re-run `/review-fix` after adjustments
- Accept as known risks

## Examples

```
User: [after meta-review] "Fix the issues"
→ Parse findings. Present table. Wait for selection. Execute.
```

```
User: "Fix only the critical and high severity items"
→ Present all, pre-select CRITICAL+HIGH. Confirm. Execute.
```

```
User: "That's a false positive, skip it"
→ Remove from queue. Note in summary.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
