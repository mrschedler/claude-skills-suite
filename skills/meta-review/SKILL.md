---
name: meta-review
description: Runs multiple review lenses in parallel and synthesizes findings. Use for comprehensive code review before deployment, after major features, or when thorough quality assessment is needed.
---

# meta-review

## Inputs

| Input | Source | Required |
|---|---|---|
| Full codebase | Project root | Yes |
| GROUNDING.md | Project root | Yes |
| project-plan.md | Project root | No (improves drift + completeness checks) |

## Outputs

- Synthesized review with findings from all lenses
- Per-lens summaries
- Overall verdict: READY / CONDITIONAL / NOT READY

## Instructions

### 1. Select Review Lenses

Default lens set (run all unless user narrows scope):

| Lens | What it checks |
|---|---|
| `security-review` | Vulnerabilities, secrets, auth, injection, supply chain |
| `completeness-review` | Stubs, TODOs, placeholders, unfinished code |
| `test-review` | Test coverage, quality, gaps, AI anti-patterns |
| `drift-review` | Code vs documentation drift |

If the user specifies a subset ("just security and tests"), run only those.

### 2. Execute Lenses

Run all selected lenses. Each lens is an independent task — no dependencies
between them.

**How to execute** is up to the agent running this skill:
- Parallel sub-tasks (subagents, CLI tools, etc.)
- Sequential execution if parallelism isn't available
- Any combination

Each lens follows its own SKILL.md instructions and produces structured findings.

### 3. Collect Results

Gather findings from all lenses. For each lens, capture:
- Finding count by severity (CRITICAL / HIGH / MEDIUM / LOW)
- The full findings list
- The lens-specific summary/verdict

### 4. Synthesize

**Cross-lens patterns**: Identify findings in multiple lenses (e.g., a stub found by
completeness-review that's also a security gap). Deduplicate but note agreement —
multi-lens confirmation = higher confidence.

**Priority ranking**: Merge all findings into a single priority-ordered list.
CRITICAL from any lens stays CRITICAL.

**Verdict logic:**
- **NOT READY**: Any CRITICAL finding from any lens
- **CONDITIONAL**: HIGH findings exist but no CRITICAL
- **READY**: Only MEDIUM/LOW findings remain

### 5. Present Results

```markdown
# Review Synthesis — {{PROJECT_NAME}}

Date: {{date}}
Lenses run: security, completeness, test, drift

## Verdict: READY | CONDITIONAL | NOT READY

## Summary
| Lens | CRITICAL | HIGH | MEDIUM | LOW |
|------|----------|------|--------|-----|
| security-review | ... | ... | ... | ... |
| completeness-review | ... | ... | ... | ... |
| test-review | ... | ... | ... | ... |
| drift-review | ... | ... | ... | ... |
| **Total** | ... | ... | ... | ... |

## Critical + High Findings (Action Required)
[Deduplicated, priority-ordered list]

## Cross-Lens Patterns
[Findings confirmed by multiple lenses]

## Medium + Low Findings (Advisory)
[Grouped by category]

## Recommendations
[Ordered list of what to fix first]
```

### 6. Persist (if MCP available)

Store the synthesis to memory for future reference:
- Tags: `meta-review`, `review-synthesis`, `{project-name}`
- Content: verdict, finding counts, top findings

## Examples

```
User: "Full review before we ship"
→ Run all 4 lenses. Synthesize. Present verdict.
```

```
User: "Just check security and completeness"
→ Run 2 lenses. Synthesize. Present verdict.
```

```
User: "Is this ready for production?"
→ Run all 4 lenses. Frame as production readiness.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
