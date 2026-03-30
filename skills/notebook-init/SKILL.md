---
name: notebook-init
description: "Creates an engineering or inventor's notebook in a project. Use when starting a new project, adding a notebook to an existing project, or when user says 'notebook', 'engineering log', or 'inventor's notebook'."
---

# notebook-init

Create a timestamped, git-tracked notebook for recording design evolution,
decisions, failed approaches, and key insights. Every project benefits from one.
The notebook is the long-term record of WHY things evolved the way they did —
GROUNDING.md captures the current state, the notebook captures the journey.

## When to use

- User says "notebook", "engineering notebook", "inventor's notebook", "dev log"
- Called from `/project-organize` or `/meta-init` as part of project setup
- User asks to add a notebook to an existing project
- A project has a GROUNDING.md but no notebook

## Notebook types

| Type | When | Key difference |
|------|------|----------------|
| **Engineering Notebook** | Default for all projects | Records what was tried, what worked, what failed, and why. Evidence references optional. |
| **Inventor's Notebook** | Patent-related projects only | Stricter evidence requirements. Every entry needs dated evidence with immutability classification. Git SHAs are primary timestamps. Legal standing. |

Ask the user which type if the project touches patent work. Default to
Engineering Notebook if not asked or if the user doesn't specify.

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | GROUNDING.md, user prompt, or directory name | Yes |
| Project root path | User prompt or cwd | Yes |
| Notebook type | User prompt (default: engineering) | No |
| Pipeline slug | GROUNDING.md or user | No |
| Project start date | GROUNDING.md, git log, or user | No |

## Instructions

1. **Read GROUNDING.md** if it exists — extract project name, purpose, start
   date, and pipeline slug. Do not ask the user for information already there.

2. **Check for existing notebook** — look for `ENGINEERING-NOTEBOOK.md`,
   `INVENTORS-NOTEBOOK.md`, or any `*NOTEBOOK*` file. If one exists, report it
   and ask what the user wants (update, replace, or abort).

3. **Determine placement:**
   - Engineering Notebook: `<project-root>/ENGINEERING-NOTEBOOK.md`
   - Inventor's Notebook: `<project-root>/invention/INVENTORS-NOTEBOOK.md`
     (create `invention/` directory if needed)

4. **Create the notebook** using the appropriate template below.

5. **Seed Entry 0** — every notebook starts with an origin entry. Ask the user:
   "What's the origin story? When and why did this project start?" Use their
   answer to write Entry 0. If GROUNDING.md already explains this, draft Entry 0
   from it and confirm with the user.

6. Confirm creation with the user.

## Engineering Notebook Template

```markdown
# {{PROJECT_NAME}} — Engineering Notebook

Project: {{PROJECT_NAME}}{{PIPELINE_SLUG}}
Started: {{PROJECT_START_DATE}}
Notebook started: {{TODAY}}

This notebook records the evolution of {{PROJECT_NAME}}: what was tried, what
worked, what failed, and why. Entries are dated; git commit history provides
authenticated timestamps. Each entry should capture reasoning, not just outcomes.

---

## Entry 0 — Origin ({{ORIGIN_DATE}})

**What:** {{Origin description}}

**Why:** {{Why this project was started}}

**Evidence:** {{Git SHA, Qdrant search hint, or other reference if available}}

---

<!-- New entries go above this line. Use the format:

## Entry N — Title (YYYY-MM-DD)

**What:** What was done or decided.

**Why:** Why this approach was chosen. What alternatives were considered.

**Result:** What happened. Did it work? What was learned?

**Evidence:** Git SHAs, Qdrant search hints (not UUIDs — IDs break on migration), file refs.

---
-->
```

## Inventor's Notebook Template

```markdown
# Inventor's Notebook — Record of Conception and Development

## {{INVENTION_TITLE}}
**Inventor:** {{INVENTOR_NAME}}
**Record initiated:** {{TODAY}}
**Purpose:** This document records the inventor's thought process, design
evolution, failed approaches, key insights, and the path to the inventive
concept. It serves as evidence of inventorship, conception date, and
non-obviousness. Entries are dated individually; git commit history provides
authenticated timestamps for each update.

---

## Entry — {{DATE}} — {{TITLE}}

**Recorded:** {{TODAY}} (documenting events from {{EVENT_DATE}})
**Evidence:** {{Evidence references with immutability classification}}

### {{Section heading}}

{{Narrative description of what happened, what was tried, what failed, what
was learned. Include specific technical details — vague summaries have no
evidentiary value.}}

### Evidence
- {{Source}}: {{Description}}. *{{Immutability classification: Immutable /
  Corroborative / Inventor recollection}}*

---

<!-- New entries go above this line.

EVIDENCE RULES for inventor's notebooks:
- Every entry MUST have dated evidence
- Classify each piece: Immutable (git SHA, USPTO, government record),
  Corroborative (Qdrant, backups, third-party hosted), or
  Inventor recollection (unverifiable, state explicitly)
- Git commit SHAs are your strongest timestamps
- Record events AS THEY HAPPEN when possible. Retroactive entries must note
  the recording date vs. event date.
-->
```

## Integration with other skills

This skill is designed to be called from:
- `/project-organize` — as Phase 2.3 after GROUNDING.md creation
- `/meta-init` — as part of the full project initialization flow

When called from another skill, skip the confirmation prompts and use
information already gathered by the parent skill.

## Do NOT create

- Duplicate notebooks in the same project
- Notebooks in `docs/` (they live at root or in `invention/`)
- Any other project files (GROUNDING.md, project-plan.md, etc.)

## Exit condition

Notebook file exists with header and Entry 0 filled. User has confirmed.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
