# Scaffolder Subagent Prompt

Prompt template for the Phase 3 sub-project scaffolder.
Fill in all [PLACEHOLDERS] before spawning.

---

```
You are scaffolding a sub-project directory within a parent project.

## Configuration

- Sub-project name: [SUB_PROJECT_NAME]
- Sub-project path: [SUB_PROJECT_PATH]
- Parent root: [PARENT_ROOT]
- Parent pattern: [PATTERN] (one of: claude-md, rules-dir, both)
- Symlink targets: [SYMLINK_LIST] (comma-separated list of files to symlink)

## Directory Structure

Create this structure at [SUB_PROJECT_PATH]:

```
[SUB_PROJECT_NAME]/
  artifacts/
    research/
      summary/
    reviews/
    compact/
  references/
```

## Symlinks

For each file in [SYMLINK_LIST], create a relative symlink from the
sub-project to the parent:

```bash
# Example for coterie.md if sub-project is one level deep:
ln -s ../coterie.md [SUB_PROJECT_PATH]/coterie.md
```

Calculate the correct relative path based on the depth of [SUB_PROJECT_PATH]
relative to [PARENT_ROOT]. Verify each symlink resolves with `ls -la`.

If any symlink fails, copy the file instead and report which ones failed.

## Claude Configuration

Based on [PATTERN]:

**If `claude-md`**: Create CLAUDE.md at [SUB_PROJECT_PATH]/CLAUDE.md with
this content (fill in the project name):

```markdown
# [SUB_PROJECT_NAME]

IMPORTANT: Read these files before starting any task:
- `architecture.md` — distilled parent context + sub-project architecture
- `build-plan.md` — implementation roadmap for this sub-project
- `features.md` — what this sub-project delivers
- `coterie.md` — collaboration rules (symlinked from parent)
- `cnotes.md` — collaboration log (newest first)

## Scope

This is a sub-project of the parent at [PARENT_ROOT].
Work within this directory. Consult the parent only when architecture.md
is insufficient for cross-boundary questions.

## Living Documents

After completing work, update:
- `cnotes.md` — log what you did
- `todo.md` — mark completed items, add new ones
- `features.md` — if your work changed what this sub-project delivers
```

**If `rules-dir`**: Create `rules/` directory with these files:
- `rules/sub-project.md` — Sub-project-specific rules: scope boundaries,
  local conventions, doc references (architecture.md, build-plan.md, etc.)
- `rules/parent-conventions.md` — Key parent rules this sub-project must
  follow, extracted from the analyzer output. A curated subset, not a copy
  of the full parent rules.

**If `both`**: Create both CLAUDE.md and rules directory.

## Template Files

Create `cnotes.md` with:
```markdown
# Collaboration Notes

## Notes (Newest First)
```

Create `todo.md` with:
```markdown
# Todo

## In Progress

## Pending

## Done
```

Create `.gitignore` with:
```
artifacts/compact/
artifacts/project.db
*.pyc
__pycache__/
node_modules/
.env
```

## Report

When complete, report:
- Directories created
- Files created
- Symlinks created (and whether they resolve)
- Any symlinks that failed (fell back to copy)
- Claude configuration pattern used
```
