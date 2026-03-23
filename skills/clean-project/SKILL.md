---
name: clean-project
description: Audits and tidies project structure for agent-optimal navigation. Detects duplicate DBs, orphaned files, config scatter, naming drift, and bloat. Proposes then executes approved changes safely.
---

# Clean Project

Audit a project's file structure, detect mess, propose fixes, and execute
approved changes without breaking anything. Optimized for making projects
easy for AI agents to navigate — predictable layout, minimal root, clear
separation of concerns.

**Context-window strategy**: Phase 1 (audit) runs inline with targeted
`find`/`grep`/`glob` commands. Phase 2 (plan) is inline presentation.
Phase 3 (execute) uses subagents for large batch moves.

## Inputs

| Input | Source | Required |
|---|---|---|
| Project root | Working directory or `--cd` arg | Yes |
| `.gitignore` | Project root | No (will note if missing) |
| `project-context.md` | Project root | No (helps understand intent) |
| `CLAUDE.md` / `AGENTS.md` | Project root | No (audited for context rot) |

## Outputs

- **Audit report**: `artifacts/reviews/clean-project-audit.md`
- **Execution log**: `artifacts/reviews/clean-project-changes.md` (if Phase 3 runs)
- **DB store**: `db_upsert 'clean-project' 'findings' 'standalone' "$CONTENT"`

## Instructions

### Phase 1: Structural Audit (Read-Only)

Run ALL of the following checks. Present results as a categorized report.
Do NOT modify any files in this phase.

#### 1.1 Root Census

Count and categorize every file at the project root (not recursively):

```bash
ls -1A "$PROJECT_ROOT" | head -80
```

Categorize each root file as:
- **Required at root**: README.md, LICENSE, .gitignore, package manifest (package.json, Cargo.toml, pyproject.toml, go.mod), CI config (.github/), CLAUDE.md
- **Tolerable at root**: Makefile, Dockerfile, docker-compose.yml, tsconfig.json
- **Should move**: anything else — assess case-by-case

Flag if root has >20 files (warning) or >30 files (critical).

#### 1.2 Database Discovery

Find ALL database files in the project:

```bash
find "$PROJECT_ROOT" -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \
  -o -name "*.db-shm" -o -name "*.db-wal" -o -name "*.db-journal" 2>/dev/null
```

For each database found:
1. Report: path, size, last modified
2. If SQLite, dump schema: `sqlite3 "$DB" ".schema" 2>/dev/null | head -50`
3. Row count per table: `sqlite3 "$DB" "SELECT name, (SELECT count(*) FROM [name]) FROM sqlite_master WHERE type='table';" 2>/dev/null`
4. Assess: is this a duplicate of another DB? Same schema = likely duplicate
5. Assess: is it in the right place? (should be under `artifacts/` or `data/`, gitignored)
6. Assess: is it orphaned? (no code references it)

Present a **Database Summary Table**:
```
| Path | Size | Tables | Rows | Gitignored | Referenced | Verdict |
```

Verdicts: `OK`, `MISPLACED`, `DUPLICATE`, `ORPHANED`, `MERGE_CANDIDATE`

#### 1.3 Duplicate File Detection

Find files with identical content (by checksum):

```bash
find "$PROJECT_ROOT" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -not -path '*/.next/*' -not -path '*/dist/*' -not -path '*/build/*' \
  -exec md5 -r {} \; 2>/dev/null | sort | uniq -D -w 32
```

On Linux use `md5sum` instead of `md5 -r`.

Report duplicate groups. For each group: which copy is canonical (closest
to where it's referenced), which are redundant.

#### 1.4 Orphan Detection

Find files that nothing references:

1. List all non-source files (not `.ts`, `.js`, `.py`, `.go`, `.rs`, `.java`, etc.)
   that are not in `.git/`, `node_modules/`, `dist/`, `build/`
2. For each, grep the entire project for its filename (basename):
   ```bash
   grep -r "$(basename "$FILE")" "$PROJECT_ROOT" --include='*.{ts,js,py,go,rs,md,json,yaml,yml,toml,sh}' -l 2>/dev/null
   ```
3. Files with zero references are orphan candidates
4. Exclude: README.md, LICENSE, .gitignore, CLAUDE.md, AGENTS.md (these are
   convention-based, not import-based)

#### 1.5 Config Scatter

Count dotfiles and config files at root:

```bash
ls -1d "$PROJECT_ROOT"/.* "$PROJECT_ROOT"/*.config.* "$PROJECT_ROOT"/*rc \
  "$PROJECT_ROOT"/*.json "$PROJECT_ROOT"/*.toml "$PROJECT_ROOT"/*.yaml \
  "$PROJECT_ROOT"/*.yml 2>/dev/null | grep -v '^\.$' | grep -v '^\.\.$'
```

Flag patterns:
- 5+ config files at root → suggest `.config/` consolidation
- `.env` committed (not gitignored) → security warning
- Multiple overlapping configs (`.eslintrc` + `.eslintrc.js` + `eslint.config.mjs`)

#### 1.6 Naming Consistency

Sample 50 files and check naming convention consistency:

```bash
find "$PROJECT_ROOT" -maxdepth 3 -type f -not -path '*/.git/*' \
  -not -path '*/node_modules/*' | head -50
```

Classify each as: kebab-case, snake_case, camelCase, PascalCase, SCREAMING_CASE, or mixed.
Report the dominant convention and any outliers.

#### 1.7 Gitignore Coverage

Verify that generated/ephemeral content is properly ignored:

Must be gitignored:
- `node_modules/`, `dist/`, `build/`, `target/`, `.next/`
- `*.db`, `*.sqlite`, `*.db-wal`, `*.db-shm` (unless intentionally tracked)
- `.env` (security)
- `tmp/`, `.cache/`, `compact/`
- `*.log`

Check: `git check-ignore -v <path>` for each pattern.

#### 1.8 Directory Depth & Bloat

```bash
find "$PROJECT_ROOT" -type d -not -path '*/.git/*' -not -path '*/node_modules/*' \
  | while read -r dir; do
    count=$(find "$dir" -maxdepth 1 -type f | wc -l)
    echo "$count $dir"
  done | sort -rn | head -20
```

Flag directories with >50 files (bloat warning).
Flag depth >6 levels (complexity warning).

#### 1.9 Agent Context Health

Check for agent instruction files:
- `CLAUDE.md` — exists? Size? Over 300 lines = context rot warning
- `AGENTS.md` — exists?
- `.cursor/rules/` — exists? Scoped `.mdc` files?
- `.github/copilot-instructions.md` — exists?
- `.codex/` config — exists?

For each that exists and exceeds 300 lines, flag as context rot risk.

#### 1.10 Artifact Organization

Check if generated/output files follow the `artifacts/` convention:
- Research files outside `artifacts/research/` → flag
- Review files outside `artifacts/reviews/` → flag
- Build outputs outside `dist/`/`build/`/`artifacts/` → flag
- Logs outside `logs/` → flag

### Phase 2: Present Findings & Propose Plan

Present the audit as a structured report with severity levels:

| Severity | Meaning | Action |
|----------|---------|--------|
| CRITICAL | Security risk or data loss risk | Must fix |
| HIGH | Agent navigation significantly impaired | Should fix |
| MEDIUM | Suboptimal but not breaking | Nice to fix |
| LOW | Minor cosmetic issue | Optional |
| INFO | Observation, no action needed | — |

Group proposed actions into batches:

**Batch A — Safe (no code changes)**:
- Add gitignore entries
- Create missing directories (`artifacts/`, `logs/`, `tmp/`)

**Batch B — Moderate (file moves, no code changes)**:
- Move misplaced files to correct directories
- Consolidate config files into `.config/`
- Move DBs to `artifacts/` or `data/`

**Batch C — Risky (requires path updates)**:
- Rename files for naming consistency
- Merge duplicate databases
- Delete orphaned files

Present the full plan and ask:

> "Project audit complete. Found N issues (CRITICAL: X, HIGH: Y, MEDIUM: Z).
>
> 1. **Execute all** — run batches A, B, C in order with verification
> 2. **Safe only** — run Batch A only (gitignore + directory creation)
> 3. **Cherry-pick** — tell me which specific items to fix
> 4. **Stop here** — keep the audit report, fix later"

Wait for the user's answer. Do not assume.

### Phase 3: Execute Approved Changes

Execute changes in strict order with safety rails:

#### Safety Protocol

Before ANY file operations:
1. Check for uncommitted changes: `git status --porcelain`
2. If dirty, ask user to commit or stash first
3. Create a checkpoint: `git stash push -m "clean-project checkpoint"`
   (only if user approves)

#### Batch A Execution (Safe)

1. Add missing gitignore entries → `git add .gitignore && git commit -m "chore: update gitignore for project cleanliness"`
2. Create missing directories → add `.gitkeep` if needed
3. No further verification needed

#### Batch B Execution (Moderate)

For each file move:
1. **Pre-check**: grep entire project for the old path
   ```bash
   grep -r "OLD_PATH" "$PROJECT_ROOT" --include='*.{ts,js,py,go,rs,md,json,yaml,yml,toml,sh,css,html}' -l
   ```
2. If references exist, list them and ask user whether to:
   - Auto-update references (if straightforward string replacement)
   - Skip this move
3. Execute: `git mv OLD_PATH NEW_PATH`
4. **Pure-move commit**: `git commit -m "refactor: move FILE to DEST"`
5. Do NOT mix content changes with moves

#### Batch C Execution (Risky)

**Database merges**:
1. Dump both schemas, present diff
2. If schemas match: dump data, merge into canonical DB, verify row counts
3. If schemas differ: explain differences, ask user for merge strategy
4. Back up originals before any merge

**File deletes**:
1. Show file content preview (first 20 lines)
2. Confirm: "Delete FILE? (y/n)" — per file, no batch delete
3. `git rm FILE` and commit

**Renames for naming consistency**:
1. Show old → new name
2. Grep for old name in all files
3. Auto-update references if safe
4. `git mv` + pure-move commit

#### Post-Execution Verification

After all approved changes:
1. Run project tests if test runner detected: `npm test`, `pytest`, `go test ./...`, `cargo test`
2. Run linter if detected
3. `git status` to verify clean state
4. Compare file count before/after
5. Present summary: N files moved, N deleted, N renamed, N gitignore entries added

### Phase 4: Report

Write final report to `artifacts/reviews/clean-project-audit.md`:

```markdown
# Clean Project Audit — {project-name}

**Date**: {date}
**Project**: {path}
**Files scanned**: N
**Issues found**: N (CRITICAL: X, HIGH: Y, MEDIUM: Z, LOW: W)

## Database Summary
{table from 1.2}

## Duplicate Files
{groups from 1.3}

## Orphaned Files
{list from 1.4}

## Config Scatter
{findings from 1.5}

## Naming Consistency
{report from 1.6}

## Gitignore Coverage
{findings from 1.7}

## Agent Context Health
{findings from 1.9}

## Changes Applied
{list of changes from Phase 3, or "No changes — audit only"}

## Remaining Recommendations
{items the user deferred or declined}
```

Store in artifact DB:
```bash
source artifacts/db.sh
db_upsert 'clean-project' 'findings' 'standalone' "$REPORT"
```

## Error Handling

- If `sqlite3` is not installed, skip DB schema inspection but still report file locations/sizes
- If `md5`/`md5sum` not available, skip duplicate detection and note it
- If no `.gitignore` exists, flag as CRITICAL and offer to create one
- If git working tree is dirty and user won't stash, run Phase 1 only (audit) and skip Phase 3

## Examples

```
User: "Clean up this project"
Action: Run full Phase 1 audit. Present findings. Ask which batches to execute.
```

```
User: "Why do I have 3 SQLite databases?"
Action: Run Phase 1.2 (database discovery) focused. Explain each DB's purpose,
        whether they're duplicates, and whether they should merge.
```

```
User: "Just audit, don't change anything"
Action: Run Phase 1 only. Present report. Skip Phase 2 approval gate.
```

```
User: "/clean-project"
Action: Full pipeline — audit, plan, execute approved changes.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
