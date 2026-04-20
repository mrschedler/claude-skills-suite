---
name: notebook-init
description: "Creates an engineering or inventor's notebook in a project. Use when starting a new project, adding a notebook to an existing project, or when user says 'notebook', 'engineering log', or 'inventor's notebook'."
---

# notebook-init

Git-tracked notebook for design evolution, decisions, failed approaches, and key insights.
GROUNDING.md = current state. Notebook = the journey.

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

Default: Engineering Notebook. Ask user if project touches patent work.

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | GROUNDING.md, user prompt, or directory name | Yes |
| Project root path | User prompt or cwd | Yes |
| Notebook type | User prompt (default: engineering) | No |
| Pipeline slug | GROUNDING.md or user | No |
| Project start date | GROUNDING.md, git log, or user | No |

## Instructions

1. **Read GROUNDING.md** — extract project name, purpose, start date, pipeline slug.
2. **Check for existing notebook** — glob `*NOTEBOOK*`. If found: ask user (update, replace, abort).
3. **Placement:**
   - Engineering: `<project-root>/ENGINEERING-NOTEBOOK.md`
   - Inventor's: `<project-root>/invention/INVENTORS-NOTEBOOK.md`
4. **Create notebook** from template below.
5. **Seed Entry 0** — origin entry. Source from GROUNDING.md if available, else ask user.

6. **Generate Index** — per ENGINEERING NOTEBOOK FORMAT in behavioral-reminders.txt.
7. Confirm creation with the user.

## Engineering Notebook Template

```markdown
# {{PROJECT_NAME}} — Engineering Notebook

project={{PROJECT_NAME}}
pipeline={{PIPELINE_SLUG}}
started={{PROJECT_START_DATE}}
notebook_created={{TODAY}}

<!-- Entry and index format defined in behavioral-reminders.txt (ENGINEERING NOTEBOOK FORMAT section). -->

## Index
| # | Title | Date | Type | Line |
|---|-------|------|------|------|
| 0 | Origin | {{ORIGIN_DATE}} | decision | XX |

---

## Entry 0 -- Origin

date={{ORIGIN_DATE}}
type=decision

**Decisions:**
| Decision | Reason |
|----------|--------|
| {{why project started}} | {{context}} |

**Evidence:** {{Qdrant search hint, git ref}}

---
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

## Integration

Called from: `/project-organize` (Phase 2.3), `/meta-init`
When called from parent skill: skip confirmations, use already-gathered inputs.

## Do NOT create

- Duplicate notebooks in the same project
- Notebooks in `docs/` (they live at root or in `invention/`)
- Any other project files (GROUNDING.md, project-plan.md, etc.)

## Exit condition

Notebook file exists with header, TOC, and Entry 0. User confirmed.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
