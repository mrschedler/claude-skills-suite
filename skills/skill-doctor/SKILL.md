---
name: skill-doctor
description: Self-diagnostic for the skill suite. Use after install, after adding/removing skills, or when a skill invocation fails. Run this before debugging manually.
---

# Skill Doctor

Comprehensive diagnostic of the skill suite. Checks all expected files exist, external CLIs are reachable, and paths resolve. Reports PASS/FAIL with fix instructions.

## Inputs

- **Skills root**: `/Users/byrum_work/Library/Mobile Documents/com~apple~CloudDocs/Shared/claude/skills/`
- **References root**: `/Users/byrum_work/Library/Mobile Documents/com~apple~CloudDocs/Shared/claude/references/`

## Instructions

### 1. Resolve Skills Root

Verify the skills directory exists. If not, report failure and stop.

### 2. Check Atomic Skills (21)

Each should have a `SKILL.md`:

```
quick-plan, build-plan, repo-create, github-sync,
deploy-gateway, todo-features, release-prep,
browser-review, codex, gemini,
completeness-review, compliance-review, counter-review, drift-review,
refactor-review, security-review, test-review,
project-organize, project-questions, project-context, infra-health
```

### 3. Check Research Skills (4+1)

```
research-plan, research-execute, meta-research, meta-deep-research
```

Also: `meta-deep-research-execute/SKILL.md` (internal, dispatched by meta-deep-research).

### 4. Check Meta/Orchestrator Skills (6)

```
meta-init, meta-join, meta-execute, meta-review,
meta-production, meta-context-save
```

### 5. Check Utility Skills (3)

```
evolve, skill-doctor, sync-skills
```

### 6. Check Templates

**In `archive/project-scaffold/templates/` (deprecated, retained for reference):**
```
coterie-template.md, cnotes-template.md, todo-template.md,
features-template.md, claude-md-template.md, agents-md-template.md,
gemini-md-template.md, codex-instructions-template.md,
gemini-instructions-template.md
```

**In `project-context/templates/`:** `context-template.md`

**In `build-plan/templates/`:** `plan-template.md`

### 7. Check Reference Files

In the references root:
```
cross-cutting-rules.md
evolve-context-diff.md
evolve-plan-diff.md
```

Every skill references `cross-cutting-rules.md` in its footer. If missing, skill completion steps fail.

### 8. Check External CLIs

| Tool | Check | Required |
|---|---|---|
| `gemini` | `which gemini >/dev/null 2>&1` | Optional |
| `codex` | Resolve NVM/Homebrew Codex path; verify executable exists | Optional |
| `jq` | `which jq >/dev/null 2>&1` | Required (hooks) |
| `gh` | `which gh >/dev/null 2>&1` | Required (github-sync, repo-create) |

Optional absent = WARNING. Required absent = FAIL with install instructions.

### 9. Check `disable-model-invocation` Flags

These skills should have `disable-model-invocation: true` (they're internal, not user-triggered):

```
meta-deep-research-execute, research-execute, research-plan,
project-questions, sync-skills, infra-health
```

Missing flag = WARNING (consuming description budget unnecessarily).

### 10. Produce Report

```
## Skill Doctor Report

| Category | Checked | Passed | Failed | Warnings |
|---|---|---|---|---|
| Atomic Skills | 21 | ... | ... | 0 |
| Research Skills | 5 | ... | ... | 0 |
| Meta Skills | 6 | ... | ... | 0 |
| Utility Skills | 3 | ... | ... | 0 |
| Templates | 11 | ... | ... | 0 |
| References | 3 | ... | ... | 0 |
| External CLIs | 4 | ... | ... | ... |
| Invocation Flags | 8 | ... | ... | ... |

### Failures
(list each with fix instruction)

### Warnings
(list each with recommendation)

### Verdict
All checks passed. / N failures require attention.
```

## Examples

```
User: I just set up skills on a new machine.
--> Full diagnostic. Check all categories. Report.
```

```
User: /skill-doctor
--> Full diagnostic. Print summary and failures.
```

```
User: Why did counter-review fail to call Gemini?
--> Check 8 (CLIs). Verify gemini installed. Note fallback behavior.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
