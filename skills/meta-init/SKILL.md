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
project-questions → project-scaffold → project-context (optional) → build-plan
```

## Instructions

### Step 1: Interview (`/project-questions`)

Run the project-questions interview to surface problem, users, scope, non-goals,
tech stack, and constraints.

If the user says "skip the interview, I know what I want", respect that and
proceed with provided context.

### Step 2: Scaffold (`/project-scaffold`)

Create directory structure and GROUNDING.md. Fill GROUNDING.md from interview
output. Get user confirmation.

If a directory already exists with code, skip scaffolding but create
GROUNDING.md if missing.

### Step 2b: Engineering Notebook (Optional — `/notebook-init`)

Offer to create an engineering notebook for tracking design decisions:

Ask: "Want an engineering notebook to capture decisions and lessons as you
build? (Recommended for hardware, multi-sprint, or exploratory projects)"

If the project involves patent work, suggest an inventor's notebook instead.

### Step 3: Deep Context (Optional — `/project-context`)

For technically complex projects (multiple services, non-trivial architecture),
offer to write project-context.md. For simple projects, GROUNDING.md is enough.

Ask: "Want a detailed project-context.md, or is GROUNDING.md sufficient?"

### Step 4: Build Plan (`/build-plan`)

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
