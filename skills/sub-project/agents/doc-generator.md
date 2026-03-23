# Doc Generator Subagent Prompt

Prompt template for the Phase 5 project doc generation.
Fill in all [PLACEHOLDERS] before spawning.

---

```
You are generating project documentation for a sub-project.

## Inputs

- Sub-project name: [SUB_PROJECT_NAME]
- Sub-project path: [SUB_PROJECT_PATH]
- Task description: [TASK_DESCRIPTION]
- Parent root: [PARENT_ROOT]

Read the architecture.md that was just generated:
[SUB_PROJECT_PATH]/architecture.md

Read the parent's project-plan.md if it exists:
[PARENT_ROOT]/project-plan.md

Read the parent's features.md if it exists:
[PARENT_ROOT]/features.md

## Files to Generate

### 1. build-plan.md

Follow the same format as the parent's project-plan.md but scoped to this
sub-project only. Include:

- 2-4 phases (sub-projects are smaller than full projects)
- Milestones as concrete, testable statements
- Work units sized for AI execution (50-200 LOC, 2-5 files each)
- Dependencies between work units
- Parallelism tags (which units can run concurrently)
- Acceptance criteria for each unit (pass/fail, not vague)

Work units must be fully implementable — no "TBD", "wire up later", or
deferred integration. Every output must have a named consumer.

### 2. features.md

List the features this sub-project delivers:

```markdown
# Features — [SUB_PROJECT_NAME]

## Core Features

### F1: [Feature Name]
- **Description**: What it does
- **Acceptance Criteria**: How to verify it works
- **Status**: pending

### F2: [Feature Name]
...

## Out of Scope
[Explicitly list what this sub-project does NOT do]
```

Include an "Out of Scope" section — this prevents scope creep and helps
Claude understand boundaries.

### 3. project-context.md

Lightweight context doc. Do NOT duplicate architecture.md — reference it:

```markdown
# Project Context — [SUB_PROJECT_NAME]

## What
[1-2 sentences: what this sub-project builds]

## Why
[1-2 sentences: why it's a sub-project, not inline work]

## Scope
[What's in, what's out, what's the boundary]

## Constraints
[Timeline, technical constraints, dependencies on parent]

## Architecture
See `architecture.md` for full technical details.

## Decisions
[Key decisions made during setup, with rationale]
```

## Quality Rules

- All file references must point to files that exist in the sub-project
- build-plan.md work units must be implementable from architecture.md alone
- features.md must align with build-plan.md phases
- No circular references between docs
- No references to parent project files — everything needed is in
  architecture.md

## Report

When complete, list:
- Files created with line counts
- Number of phases and work units in build-plan.md
- Number of features in features.md
- Any gaps or assumptions made
```
