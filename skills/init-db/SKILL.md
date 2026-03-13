---
name: init-db
description: "Initializes the artifact store for the current project. Creates artifacts/ directory and artifacts/project.db (SQLite+FTS5). Safe to re-run — idempotent."
disable-model-invocation: true
argument-hint: ""
---

# Init DB

Bootstrap the skill suite artifact store for the current project.

## What it does

1. Creates `artifacts/` directory (and subdirs) if they don't exist
2. Copies `db.sh` from the skill suite references if `artifacts/db.sh` is missing
3. Runs `db_init` to create `artifacts/project.db` with the correct schema
4. Verifies the DB is usable

## Instructions

Run the following steps in order. Use the Bash tool for all commands.

### Step 1 — Locate the skill suite references

Find `db.sh` by checking these locations in order:
1. `artifacts/db.sh` (already present — skip copy)
2. The skill suite references dir: `~/Library/Mobile\ Documents/com~apple~CloudDocs/Shared/claude/references/db.sh`
3. If neither found, error out and tell the user to locate `db.sh` manually.

### Step 2 — Create directories

```bash
mkdir -p artifacts/research/summary artifacts/reviews
```

### Step 3 — Copy db.sh if missing

If `artifacts/db.sh` does not already exist:
```bash
cp "<path-to-references>/db.sh" artifacts/db.sh
chmod +x artifacts/db.sh
```

### Step 4 — Initialize the database

```bash
source artifacts/db.sh && db_init
```

If the project is **not** a git repo, `git rev-parse` will fail and `_DB` will be empty. In that case, set `PROJECT_DB` explicitly:

```bash
export PROJECT_DB="$(pwd)/artifacts/project.db"
source artifacts/db.sh && db_init
```

### Step 5 — Verify

```bash
source artifacts/db.sh && db_list
```

Should return no rows (empty) on a fresh DB, or existing rows if already initialized.

### Step 6 — Report

Tell the user:
- `artifacts/project.db` created (or already existed)
- `artifacts/db.sh` present and executable
- Subdirectories created: `artifacts/research/summary/`, `artifacts/reviews/`
- Whether it was a fresh init or already existed

## Idempotency

All operations are safe to re-run:
- `mkdir -p` is a no-op if dirs exist
- `db_init` uses `CREATE TABLE IF NOT EXISTS` — won't clobber existing data
- `cp` is only run if `artifacts/db.sh` is absent

## Error cases

| Symptom | Fix |
|---------|-----|
| `db.sh` not found in references | User needs to provide path or check skill suite install |
| `_DB` resolves to `/artifacts/project.db` | Not in a git repo — set `PROJECT_DB=$(pwd)/artifacts/project.db` |
| `sqlite3: command not found` | Install sqlite3 (`brew install sqlite3` on macOS) |
