---
name: meta-init
description: Full new-project workflow. Chains scaffold, interview, context, and build plan into one flow. Use when starting a project from scratch.
---

# meta-init

End-to-end project initialization. Takes a project from idea to approved build
plan in one workflow.

## When to use

- Starting a brand new project
- User says "new project", "let's build X from scratch", "initialize"
- A directory exists but has no structure or context docs

## Flow

```
project-questions → project-organize → build-plan
```

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

## Examples

```
User: "I want to build a REST API for inventory management"
→ Interview → Scaffold → Build plan → Present for approval.
```

```
User: "New project, skip interview. FastAPI, PG, on Unraid."
→ Scaffold with provided info → Offer project-context → Build plan.
```

```
User: "I have code at C:\dev\my-app but no docs or plan"
→ Skip scaffold → Interview → GROUNDING.md → Build plan for remaining work.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
