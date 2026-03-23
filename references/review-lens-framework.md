# Review Lens Framework

> Shared boilerplate for all code-analysis review lenses. Each lens SKILL.md
> references this file instead of duplicating the patterns below.

## Outputs

Every review lens stores findings in the artifact DB using the same pattern.
Replace `{LENS}` with the lens name (e.g., `security-review`, `perf-review`).

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert '{LENS}' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings:
  - Sonnet: `db_upsert '{LENS}' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert '{LENS}' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert '{LENS}' 'findings' 'gemini' "$CONTENT"`

Not all lenses use all 3 models. The meta-review skill determines which
models run for each lens. The skill only writes to slots it was assigned.

## Fresh Findings Check

Before running a new scan, check for fresh results:

```bash
source artifacts/db.sh
AGE=$(db_age_hours '{LENS}' 'findings' 'standalone')
```

If `$AGE` is non-empty and less than 24:
- Report: "Found fresh {LENS} findings from $AGE hours ago. Reuse them? (y/n)"
- If yes: read from DB with `db_read '{LENS}' 'findings' 'standalone'`
- If no: proceed with a fresh scan

For multi-model mode, check the relevant model label instead of `standalone`.

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`)
  with this skill's lens instructions and input files. Store findings as
  `db_upsert '{LENS}' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while
  Codex (`/codex`) and/or Gemini (`/gemini`) run in parallel with the same
  prompt. Each model stores findings under its own label (`sonnet`, `codex`,
  `gemini`). The meta-review skill handles synthesis.

## Finding Format

All lenses use severity tiers: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**.

Each finding must include at minimum:
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **Location**: file:line
- **Problem**: what's wrong
- **Recommendation**: how to fix it

Individual lenses add domain-specific fields (e.g., CWE for security, Package
for dep-audit, Screenshot for browser-review).

## Cross-Cutting Rules

Before completing, read and follow `cross-cutting-rules.md` (in this same
`references/` directory).
