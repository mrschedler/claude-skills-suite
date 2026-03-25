# Agent-Optimal Project Layout Standards

> Derived from 009 research (33 sources). These standards inform the
> clean-project skill's severity ratings and recommendations.

## Root File Budget

**Target: ≤15 files at project root.**

### Must be at root
- `README.md` — project overview
- `LICENSE` — legal
- `.gitignore` — VCS exclusions
- Package manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`)
- `CLAUDE.md` / `AGENTS.md` — agent instructions (≤300 lines each)

### Tolerable at root
- `Makefile` / `Justfile` — build entry point
- `Dockerfile` / `docker-compose.yml` — if single-container
- `tsconfig.json` — if TypeScript (tools require root placement)
- CI config (`.github/`, `.gitlab-ci.yml`)

### Should NOT be at root
- SQLite databases → `artifacts/` or `data/`
- Research artifacts → `artifacts/research/`
- Review output → `artifacts/reviews/`
- Logs → `logs/`
- Temporary files → `tmp/` or `.cache/`
- Multiple config dotfiles → consolidate into `.config/`

## Directory Conventions

```
project/
├── src/              # Source code (or language convention: lib/, pkg/, cmd/)
├── tests/            # Test files
├── artifacts/        # Generated outputs (gitignored contents)
│   ├── project.db    # SQLite artifact store
│   ├── research/     # Research investigation outputs
│   ├── reviews/      # Review synthesis outputs
│   └── compact/      # Session state (ephemeral)
├── data/             # Persistent data files (if not using artifacts/)
├── docs/             # Documentation beyond README
├── logs/             # Application logs (gitignored)
├── tmp/              # Ephemeral scratch files (gitignored)
├── .config/          # Consolidated tool configs (if many)
├── scripts/          # Build/deploy/utility scripts
└── .github/          # CI/CD workflows
```

## Agent-Specific Findings

### Context window impact
- 80% of agent tokens wasted on file discovery in disorganized projects
- AGENTS.md reduces median runtime by 29% and output tokens by 17%
- Agent performance degrades sharply when 3+ files must be modified across
  a disorganized codebase (SWE-EVO benchmark)

### Context rot threshold
- CLAUDE.md / AGENTS.md over 300 lines = context rot risk
- Use nested instruction files for subsystems instead of one giant file
- Progressive disclosure: load information only when needed

### Naming conventions
- Pick ONE convention and enforce it project-wide
- Kebab-case for web/URL files, snake_case for Python/data
- Consistent naming enables reliable glob patterns for agent discovery

## Database Placement Rules

1. **Project-local DBs** → `artifacts/` directory, gitignored
2. **User-global DBs** → `~/.local/share/<app>/` (XDG spec)
3. **Never at project root** — confuses agents, pollutes git status
4. **One DB per purpose** — if two DBs have the same schema, merge them
5. **WAL files** (`*.db-wal`, `*.db-shm`) must be gitignored

## Safe Reorganization Protocol

1. Commit or stash all pending changes
2. Pure-move commits only (no content changes mixed with moves)
3. Grep for old paths before every move
4. Update: imports, configs, CI, Dockerfiles, Makefiles
5. Run tests after each batch
6. Use `git mv` (not `mv` + `git add`)

## Sources

- Finding 5: 80% token waste — medium.com/@jakenesler
- Finding 10: Google uniform layout — qeunit.com
- Finding 14: XDG spec for DBs — alchemists.io
- Finding 17: Pure-move commits — esmithy.net
- Finding 23: Context rot — augmentcode.com, jetbrains.com
- Finding 33: Knowledge graphs > scanning — arxiv.org
- Full source list: artifacts/research/009/web-findings.md
