# Research Synthesis — 009: Agent-Optimal Project Cleanliness

> 33 web sources, project structure audit, agent context file research
> Date: 2026-03-20

## Key Principles (Ranked by Agent Impact)

1. **Predictable structure > clever structure** — agents waste 80% of tokens on file discovery when layout is inconsistent (Finding 5). Google's uniform layout is the gold standard (Finding 10).

2. **Progressive disclosure** — root should be minimal. Heavy docs, research, artifacts in subdirectories. CLAUDE.md under 300 lines, use nested files for subsystems (Finding 23).

3. **Separate ephemeral from persistent** — `tmp/`/`.cache/` for ephemeral, `artifacts/`/`data/` for persistent. Never mix (Finding 13).

4. **SQLite files under `artifacts/` or `data/`, never root** — XDG spec for user-global, project `artifacts/` for project-local (Finding 14).

5. **Pure-move commits** — separate file moves from content changes for git blame preservation (Finding 17).

6. **Config consolidation** — use `.config/` or `package.json` keys, not 10+ dotfiles at root (Finding 11).

7. **Agent context files at predictable paths** — CLAUDE.md, AGENTS.md, .cursor/rules/ — cascading from root to subsystem (Finding 1).

8. **Consistent naming enables glob discovery** — pick one convention and enforce it (Finding 24).

## What the clean-project Skill Should Do

### Phase 1: Audit (Read-Only, Always Safe)
- Scan for duplicate files (checksums via `md5` or `shasum`)
- Find all SQLite/DB files, explain each, flag duplicates
- Detect orphaned files (not imported, not referenced, not gitignored)
- Map config scatter (dotfiles at root that could consolidate)
- Count files per directory, flag bloat
- Check naming consistency
- Verify .gitignore covers artifacts/tmp/build
- Check for agent context files (CLAUDE.md, AGENTS.md, .cursor/rules)
- Detect context rot (oversized instruction files)

### Phase 2: Plan (Propose, Don't Execute)
- Present findings as a categorized report
- For each issue: what, why, proposed fix, risk level
- Group actions: safe (gitignore additions) vs moderate (file moves) vs risky (deletes)
- Require explicit approval before any changes

### Phase 3: Execute (After Approval)
- Safe actions first (gitignore, config consolidation)
- File moves: pure-move commits, grep for old paths first
- DB consolidation: explain what each DB contains, propose merge strategy
- Delete orphaned files only with explicit user confirmation per file
- Update all path references (imports, configs, CI, Dockerfiles)
- Verify: run tests/lint after changes

### Anti-Patterns to Detect
- Multiple SQLite DBs that should be one
- Research/artifact files outside `artifacts/`
- Config files that belong in `.config/` or `package.json`
- Build outputs not gitignored
- Oversized CLAUDE.md/AGENTS.md (>300 lines)
- Mixed naming conventions
- Dead code / unused exports (via knip for JS/TS)
- Duplicate files (via checksum comparison)

### Safety Rails
- NEVER delete without explicit per-file approval
- NEVER modify code logic — only move/rename
- Always grep for old paths before moving
- Pure-move commits (no content changes mixed in)
- Run tests after each batch of changes
- Git stash user's work-in-progress before starting
