---
name: project-scaffold
description: "Scaffolds a new project with standard folder structure, templates, and config files. Triggers on scaffold, set up a new project, init project, or when standard files are missing."
disable-model-invocation: true
---

# project-scaffold

Create the canonical folder structure and seed files for a new project. Every
project in this suite shares the same skeleton so that any agent (Claude, Codex,
Gemini, Copilot) can cold-start from any project and immediately know where
things live.

## When to use

- User says "new project", "scaffold", "init", or names a project to start.
- A project directory exists but is missing standard files.
- User asks "set up the folder structure" or "create the template files."

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | User prompt | Yes |
| Project root path | User prompt or cwd | Yes |
| Templates | Bundled in `templates/` beside this skill | Yes |

## Instructions

1. Confirm the project name and root path with the user. Do not assume — ask if
   ambiguous.

2. Create the following directory tree under the project root:

```
<project-root>/
  artifacts/
    research/
      summary/
    reviews/
  docs/
  src/
```

**Artifact DB**: `artifacts/db.sh` is the skill suite's SQLite helper. It creates and manages `artifacts/project.db` on first use. All intermediate skill outputs (research findings, review findings, session state) are stored there. Final synthesis documents (`artifacts/research/summary/`, `artifacts/reviews/review-synthesis.md`, `artifacts/reviews/production-readiness.md`) remain as files.

3. Copy and personalize the following template files from `templates/` into the
   project root. Replace `{{PROJECT_NAME}}` placeholders with the actual project
   name:

| Template file | Destination |
|---|---|
| `coterie-template.md` | `coterie.md` |
| `cnotes-template.md` | `cnotes.md` |
| `todo-template.md` | `todo.md` |
| `features-template.md` | `features.md` |
| `claude-md-template.md` | `CLAUDE.md` |
| `agents-md-template.md` | `AGENTS.md` |
| `gemini-md-template.md` | `GEMINI.md` |
| `gitignore-template` | `.gitignore` |
| `../../../references/db.sh` | `artifacts/db.sh` |

After copying all templates, run: `chmod +x artifacts/db.sh`

4. **coterie.md specifics** — the coterie template is the shared rules file that
   all agents read. When copying it, verify it includes:

   - **Structured note schema** with author delimiters: `CODEX`, `CLAUDE`,
     `GEMINI`, `COPILOT`.
   - **Note ID format**: `CN-YYYYMMDD-HHMMSS-AUTHOR` (e.g.,
     `CN-20260306-143022-CLAUDE`).
   - **All 13 required fields** for structured notes (id, author, timestamp,
     category, status, priority, tags, related_files, related_notes, summary,
     detail, action_items, resolution).
   - **Communication style rules** — concise, no filler, bullet points over
     prose.
   - **Code standards** — language-agnostic defaults (consistent naming, no
     dead code, tests required).
   - **Commit message format** — conventional commits
     (`type(scope): description`).
   - Sections removed from template (now handled elsewhere): "When to Ask
     vs When to Act" (generic, Claude already knows this) and "Cross-Cutting
     Rules pointer" (schema is inlined in `references/cross-cutting-rules.md`).

5. After all files are created, list every file and directory created and
   confirm with the user.

## Exit condition

All directories (`artifacts/research/`, `artifacts/research/summary/`, `artifacts/reviews/`, `docs/`, `src/`) exist. All template
files are present and personalized. `artifacts/db.sh` is present and executable. The user has seen the summary and confirmed.

## Examples

```
User: "Start a new project called nexus-api"
Action: Ask for root path, scaffold all folders and files under that path with
        PROJECT_NAME = nexus-api.
```

```
User: "I have a project at ~/projects/dashboard but it's missing the standard files"
Action: Check which standard files are missing, create only the missing ones.
        Do not overwrite existing files without asking.
```

```
User: "scaffold"
Action: Ask for project name and path, then proceed.
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
