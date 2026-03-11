---
name: compliance-review
description: Checks code against documented rules (coterie.md, CLAUDE.md, cross-cutting-rules.md). Use after major changes, before merges, or to verify the codebase follows its own standards.
---

# Compliance Review

## Purpose

Verify the codebase follows its own documented rules. Most projects accumulate rules
over time — coding standards, architectural constraints, deployment patterns, naming
conventions — and store them in files like `coterie.md`, `cross-cutting-rules.md`,
`CLAUDE.md`, or project-specific configs. This skill extracts every rule from those
files and cross-references them against the actual code to find violations.

The key principle: if a rule isn't explicitly documented, it's not a compliance violation.
Undocumented best practices are suggestions, not violations. This skill only enforces
what's written down.

## Inputs

- The full codebase
- `coterie.md` — shared team rules and conventions
- `cross-cutting-rules.md` — rules that apply across all skills and workflows
- `CLAUDE.md` — project-root Claude instructions (if exists)
- `project-context.md` — project-specific constraints and decisions
- Any other rule files referenced by the above

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'compliance-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings in the artifact DB:
  - Sonnet: `db_upsert 'compliance-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'compliance-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'compliance-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'compliance-review' 'findings' 'standalone')
# For multi-model: db_age_hours 'compliance-review' 'findings' 'sonnet'
```
If `$AGE` is non-empty and less than 24, report: "Found fresh compliance-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB: `db_read 'compliance-review' 'findings' 'standalone'` (or `sonnet`/`codex`/`gemini` as appropriate).
If no record exists or user says no, proceed with a fresh scan.

### 1. Collect All Rule Sources

Read every rule document, in order:
1. `coterie.md` (if exists in project root or references dir)
2. `cross-cutting-rules.md` (references directory)
3. `CLAUDE.md` (project root, if exists)
4. `project-context.md` (for constraints and architectural decisions)
5. Any files referenced by the above (e.g., "see coding-standards.md")

If a rule source doesn't exist, skip it — don't invent rules.

### 2. Extract Rules

From each source, extract individual, testable rules. A "rule" is a statement that can
be verified as followed or violated by examining the code. Examples:

- "All API responses use the `ApiResponse<T>` wrapper type" — testable
- "Keep code clean" — not testable, skip
- "Environment variables use empty-string fallbacks" — testable
- "Prefer simplicity" — not testable, skip
- "Docker containers run on the `traefik_proxy` network" — testable
- "Never hardcode secrets in source" — testable

Build a numbered list of extracted rules with the source document and section for each.
This list becomes the compliance checklist.

### 3. Cross-Reference Against Codebase

For each extracted rule, search the codebase for violations:
- Use grep/ripgrep for pattern-based rules (naming conventions, forbidden patterns)
- Read specific files for architectural rules (module structure, dependency direction)
- Check configuration files for infrastructure rules (Docker, CI, deployment)

Be thorough but fair:
- A rule with no violations is a passing check — note it as passing in the summary
- A rule that's ambiguous should be flagged as "unclear rule" rather than a violation
- Code in test files may be exempt from some rules (e.g., hardcoded values in test fixtures)

### 4. Produce Findings

Write findings to the output file with this structure per finding:

```
## [SEVERITY] Finding Title

**Rule Violated**: "exact quote of the rule from the source document"
**Rule Source**: document name, section heading
**Location**: file/path:line

**Violation**: What the code does that breaks the rule.

**Evidence**: Code snippet showing the violation.

**Fix**: Specific change to bring the code into compliance.
```

The rule quote is mandatory. If you can't quote a specific documented rule, it's not
a compliance finding — it's a suggestion. Move suggestions to a separate "Recommendations"
section at the end.

Severity levels:
- **CRITICAL** — Violation of a security or deployment rule that could cause outages
  or data exposure
- **HIGH** — Violation of an architectural or structural rule that undermines project
  consistency
- **MEDIUM** — Violation of a coding convention or pattern rule
- **LOW** — Minor style or naming violation

### 5. Separate Suggestions from Violations

At the end of the findings, add a clearly separated section:

```
## Suggestions (Not Rule Violations)

These are improvements that align with the spirit of the rules but aren't explicitly
documented. Consider adding them as rules if the team agrees.
```

This separation is critical. Mixing documented violations with undocumented opinions
undermines trust in the compliance process.

### 6. Summarize

End with:
- A compliance checklist table: rule number | rule summary | status (pass/fail/unclear) | finding count
- Count of violations by severity
- Count of suggestions (separate from violations)
- Overall compliance score: rules passing / total rules
- Assessment: is the codebase in good compliance, or does it need a standards pass?

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'compliance-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## Examples

```
User: Are we following our own rules? Check CLAUDE.md and coterie.md compliance.
→ Triggers compliance-review. Extract rules from both files, cross-reference against
  codebase, produce findings with exact rule quotes.
```

```
User: I just updated cross-cutting-rules.md. Check if the codebase complies with the new rules.
→ Triggers compliance-review focused on the changed rule file. Identify which new rules
  have existing violations.
```

```
User: Before we onboard the new dev, make sure our codebase matches our documented standards.
→ Triggers compliance-review. Full check across all rule sources. Frame as "here's what
  to fix before the new dev starts learning bad patterns from the code."
```

```
User: Review this PR against our coding standards.
→ Triggers compliance-review scoped to changed files. Check only the diff against the
  full rule set.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
