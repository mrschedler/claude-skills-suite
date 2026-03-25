---
name: project-scaffold
description: "Scaffolds a new project with standard folder structure, GROUNDING.md, and config files. Use when starting a new project or when a project directory is missing standard files."
---

# project-scaffold

Create the canonical folder structure and seed files for a new project. Every
project shares the same skeleton so any agent can cold-start and immediately
know where things live.

## When to use

- User says "new project", "scaffold", "init", or names a project to start.
- A project directory exists but is missing standard files.
- User asks "set up the folder structure" or "create the template files."

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | User prompt | Yes |
| Project root path | User prompt or cwd | Yes |

## Instructions

1. Confirm the project name and root path with the user. Do not assume — ask if
   ambiguous.

2. Create the following directory tree under the project root:

```
<project-root>/
  docs/
  src/
  tests/
```

   Adapt `src/` to the language convention if known (e.g., `app/` for Python/FastAPI,
   `src/` for Node/TypeScript, project name for Go). Ask if unclear.

3. Create the following files in the project root:

| File | Purpose |
|---|---|
| `GROUNDING.md` | Cold-start context: why this exists, key decisions, constraints, anti-patterns. See template below. |
| `.gitignore` | Standard ignores for the project's language/framework + .env, node_modules, __pycache__, .venv, etc. |

4. **GROUNDING.md** — fill in collaboratively with the user:

```markdown
# GROUNDING.md — {{PROJECT_NAME}}

## Why This Exists
[What problem does this solve? For whom? Why now?]

## What Matters
[2-4 bullets: the things that matter most for this project]

## Key Decisions
| Decision | Alternatives Considered | Why This One |
|----------|------------------------|--------------|
| ... | ... | ... |

## Tech Stack
[Languages, frameworks, databases, hosting — with version constraints if known]

## Constraints
[Hard limits: budget, timeline, platform, compliance, performance]

## What Will Hurt If You Get It Wrong
[Anti-patterns specific to this project. What should an agent NOT do?]

## Current State
[What exists today. Update on every major milestone.]
```

5. **Create Engineering Notebook** — run `/notebook-init` to create the project's
   engineering notebook. Pass the project name, root path, and start date already
   gathered. If the user declines, skip — the notebook can always be added later.

6. **Do NOT create** any of these (they belong to other workflows):
   - coterie.md, cnotes.md, todo.md, features.md
   - project-plan.md (created by `/build-plan`)
   - project-context.md (created by `/project-context`)
   - prd.json, progress.txt (created by `/feature-dev` or `/ralph-workflow`)
   - SQLite databases, artifacts/ directories
   - ENGINEERING-NOTEBOOK.md (created by `/notebook-init`)

7. After all files are created, list what was created and confirm with the user.

## Exit condition

Directories exist. GROUNDING.md has at least "Why This Exists" and "Tech Stack"
filled. .gitignore is present. User has confirmed.

## Examples

```
User: "Start a new project called nexus-api"
→ Ask for root path. Scaffold folders + files. Fill GROUNDING.md together.
```

```
User: "I have a project at C:\dev\dashboard but it's missing the standard files"
→ Check which files are missing. Create only the missing ones.
  Do not overwrite existing files without asking.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
