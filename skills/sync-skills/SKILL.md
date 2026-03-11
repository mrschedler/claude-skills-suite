---
description: Checks project files against skill suite templates and injects missing or stale files. Use after template updates, when joining a project, or after scaffold.
disable-model-invocation: true
---

# sync-skills

## Purpose

Ensure a project has the latest versions of all template-derived files from
the skill suite. Can inject missing files or update existing ones.

## Inputs

- **Project root**: The target project directory (default: current working directory)
- **Mode**: `check` (report only) or `sync` (apply changes). Default: `check`.

## Steps

### 1. Discover Template Set

Read the template table from `project-scaffold/SKILL.md` to get the canonical
list of templates and their output destinations:

| Template | Output |
|---|---|
| `coterie-template.md` | `coterie.md` |
| `cnotes-template.md` | `cnotes.md` |
| `todo-template.md` | `todo.md` |
| `features-template.md` | `features.md` |
| `claude-md-template.md` | `CLAUDE.md` |
| `agents-md-template.md` | `AGENTS.md` |
| `gemini-md-template.md` | `GEMINI.md` |
| `gitignore-template` | `.gitignore` |

Also check for:
- `project-context.md` (from `project-context/templates/context-template.md`)
- `project-plan.md` (from `build-plan/templates/plan-template.md`)
  - Required WU columns (post-002D): `LOC Est`, `Key Files`, `Acceptance Criteria`
  - Legacy columns to flag: `Complexity` (replaced by LOC), `Agent hint` (removed)

### 2. Check Each File

For each template → output pair:

1. **Missing**: Output file does not exist in project root → mark as `MISSING`
2. **Present**: Output file exists → compare key structural markers (headers,
   required sections) against the template. If the template has sections the
   project file lacks → mark as `STALE`
3. **Current**: Output file has all expected sections → mark as `OK`

Do NOT compare content verbatim — project files are personalized. Only check
for structural completeness (expected headers, required sections).

### 3. Report

Print a status table:

```
## sync-skills Report

| File | Status | Action Needed |
|---|---|---|
| coterie.md | OK | — |
| cnotes.md | OK | — |
| CLAUDE.md | MISSING | Inject from template |
| AGENTS.md | STALE | Missing: ## Rules section |
| ... | ... | ... |
```

### 4. Apply (sync mode only)

If mode is `sync`:

- **MISSING files**: Copy from template, replace `{{PROJECT_NAME}}` with the
  project name (derived from the directory name or `project-context.md` title).
- **STALE files**: Show the user a diff of what sections would be added. Ask
  for confirmation before modifying. Never overwrite user-customized content —
  only append missing sections.
- **OK files**: Skip.

### 5. Legacy Path Migration

Check for files/directories that belong under `artifacts/` but exist at the wrong location (old project layouts). Canonical locations are:

| Legacy path (wrong) | Correct path |
|---|---|
| `research/` | `artifacts/research/` |
| `reviews/` | `artifacts/reviews/` |
| `compact/` | `artifacts/compact/` |
| `research-plan.md` | `artifacts/research/` |
| `review-synthesis.md` | `artifacts/reviews/` |
| `production-readiness.md` | `artifacts/reviews/` |
| `claude-compact.md` | `artifacts/compact/` |
| `codex-compact.md` | `artifacts/compact/` |

For each legacy path found:
- **check mode**: flag as `MISPLACED` in the report
- **sync mode**: `mkdir -p` the correct parent, then `mv` the file/dir to the correct location. Report what was moved.

Never move files that are already in the correct location. If both the legacy path AND the correct path exist, flag as `CONFLICT` and ask the user to resolve manually — do not overwrite.

```
| research/         | MISPLACED | Moved → artifacts/research/ |
| compact/          | MISPLACED | Moved → artifacts/compact/  |
| review-synthesis.md | CONFLICT | Both root and artifacts/reviews/ exist — resolve manually |
```

### 6. Artifact Store

Check whether the artifact store is initialized:

1. If `artifacts/db.sh` is **missing** → run `/init-db` (or its equivalent steps inline) to create `artifacts/`, copy `db.sh`, and initialize `artifacts/project.db`
2. If `artifacts/db.sh` **exists** but `artifacts/project.db` does **not** → run `source artifacts/db.sh && db_init` to create the DB
3. If both exist → skip (already initialized)

Report the artifact store status alongside the file status table:

```
| artifacts/db.sh    | MISSING | Initialized via init-db |
| artifacts/project.db | MISSING | Created via db_init    |
```

### 7. Cross-Cutting Compliance

Before completing, read and follow `references/cross-cutting-rules.md`.

## Examples

```
User: sync skills
--> Run in check mode. Report which files are missing or stale.

User: sync skills --apply
--> Run in sync mode. Inject missing files, prompt before updating stale ones.

User: /meta-join  (calls this skill as step 2)
--> Run in sync mode automatically as part of the join flow.
```
