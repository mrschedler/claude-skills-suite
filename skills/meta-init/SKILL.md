---
name: meta-init
description: Full new-project workflow. Chains scaffold, interview, context, and build plan into one flow. Use when starting a project from scratch.
---

# meta-init

## Instructions

### Step 1: Interview (`/project-questions`)

Run the project-questions interview to surface problem, users, scope, non-goals,
tech stack, and constraints.

If the user says "skip the interview, I know what I want", respect that and
proceed with provided context.

### Step 2: Organize (`/project-organize`)

Runs the full project organization flow: creates GROUNDING.md, CLAUDE.md,
engineering notebook (if warranted), directory structure, .gitignore, and
fixes stale docs if the project already has content. Pass interview output
as context so GROUNDING.md is filled from the interview answers.

`/project-organize` handles both new and existing projects — it detects
what exists and adapts.

### Step 3: Build Plan (`/build-plan`)

Generate project-plan.md with phases, milestones, and work units.
Present for approval. Revise if needed.

### Completion

```
Project initialized:
- GROUNDING.md — context and decisions
- ENGINEERING-NOTEBOOK.md — design journal (if created)
- project-context.md — technical reference (if created)
- project-plan.md — phased build plan with N work units
- Directory structure ready

Next: /feature-dev to start building, or /meta-review after initial implementation.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
