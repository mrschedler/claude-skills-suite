---
name: feature-dev
description: "Unified feature development skill. Automatically determines appropriate rigor level based on task complexity. Use for any development work - from quick fixes to complex features. Triggers on \"build a feature\", \"implement\", \"develop\", \"create functionality\", or when user describes work that needs planning."
---

# feature-dev

One skill that adapts to what you're building. Routes to the right level of
rigor based on complexity. No ceremony for simple tasks. Full iterative
workflow when complexity demands it.

## Step 1: Read Project Context

1. Read `GROUNDING.md` if it exists — understand why the project exists,
   decisions, constraints
2. Read `PROGRESS.md` if it exists — pick up where the last session left off
3. Read `prd.json` or `USER_STORIES.md` if they exist — active story state

If resuming mid-feature (PROGRESS.md + prd.json exist), skip to Step 3.

## Step 2: Assess Complexity

| Complexity | Signals | Approach |
|------------|---------|----------|
| **Simple** | Single file, clear fix, under 30 min | Do it. Commit. Done. |
| **Medium** | 2-4 files, clear scope, 1-2 hours | Light plan → implement → commit |
| **Complex** | 5+ files, multi-session, unclear edges | Ralph mode (see below) |

**Simple and medium:** Just work. Follow existing code patterns, run tests,
commit with a descriptive message. No PRD, no progress files, no ceremony.

**Complex:** Continue to Step 3.

## Step 3: Ralph Mode — Iterative Multi-Session Development

### Prerequisites

Ralph mode requires project-organize to have run first. If `GROUNDING.md`
does not exist:

```
This feature needs iterative development, but the project has no GROUNDING.md.
Run /project-organize first to set up project structure and artifact DB.
```

Stop and prompt the user. Do not proceed without GROUNDING.md.

### 3a: Initialize (first time only)

**Set up artifact DB** (skip if already initialized):
```bash
export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
export PROJECT_DB="$(pwd)/artifacts/project.db"
source artifacts/db.sh && db_init 2>/dev/null || true
```

**Create prd.json** with right-sized stories. See `references/prd-schema.md`.

Right-sized means:
- Completable in a single focused session
- Clear acceptance criteria
- No dependencies on uncommitted work

Stories numbered as `X.Y` (phase.sequence): `1.1`, `1.2`, `2.1`, etc.

**Create PROGRESS.md** — thin state pointer only:

```markdown
# Progress
| Field | Value |
|-------|-------|
| Current Story | 1.1 - {title} |
| Last Completed | — |
| Blockers | None |

## Next
1. Read prd.json story 1.1
2. {specific first action}
```

**Add Development Workflow section to GROUNDING.md:**

```markdown
## Development Workflow
Uses iterative story-based development (feature-dev Ralph mode).
- Task definitions: prd.json
- Current state: PROGRESS.md (pointer only — history in artifact DB)
- Story completions: artifact DB (skill=dev, phase=story-complete)
- Lessons learned: Qdrant memory (category: {project-slug})
```

### 3b: Pick Up Work (every session)

1. Read `PROGRESS.md` — know current story and next action
2. Read `prd.json` — find the story details and acceptance criteria
3. `git log --oneline -5` — see recent commits
4. Run build/tests — fix failures before new work

### 3c: Implement One Story

- Focus on ONE story only
- Follow existing code patterns
- Make minimal, focused changes
- Run build + tests frequently

### 3d: Complete Story

**Quality gates (non-negotiable):**
- Build passes
- Related tests pass
- UI verified if applicable (use Playwright MCP)
- Code follows existing patterns

If ANY gate fails: do not mark complete. Document the failure in artifact DB
and move on.

**Record completion in artifact DB:**
```bash
source artifacts/db.sh
db_write "dev" "story-complete" "{X.Y}/{story-slug}" \
  "Story {X.Y}: {title}. Files: {list}. Gotcha: {issue or None}. Verified: {how}."
```

**Store gotchas/lessons to Qdrant** (if worth remembering across sessions):
```
memory_call > store
  content: [gotcha or lesson, self-contained]
  tags: dev, gotcha, {project-name}
  category: {project-slug}
```

**Commit:**
```
feat|fix|refactor: {description} (Story {X.Y})
```
One story = one atomic commit = one rollback point.

**Update prd.json:** Set `"passes": true` on the completed story.

**Update PROGRESS.md** — overwrite (not append):
```markdown
# Progress
| Field | Value |
|-------|-------|
| Current Story | {next X.Y} - {title} |
| Last Completed | {X.Y} - {title} ({date}) |
| Blockers | None |

## Next
1. {specific next action}
2. {specific next action}
```

### 3e: Phase Transitions

When all stories in a phase are complete:

```bash
source artifacts/db.sh
db_read_all "dev" "story-complete"  # review what was built
```

Before starting the next phase:
1. Review lessons from completed phase (query artifact DB)
2. Confirm with user before proceeding
3. Check if remaining stories still make sense given what was learned

### 3f: Validation

At phase transitions, every 5 stories, or after context reset:

```bash
source artifacts/db.sh
# Check all stories completed in order
db_read_all "dev" "story-complete"
# Check for gaps or out-of-order completions
```

Cross-check: artifact DB completion records match `prd.json` passes flags
match `PROGRESS.md` current story pointer.

## What Ralph Is Good For

- CRUD endpoints and API routes
- Pattern migrations (updating many similar files)
- Test coverage expansion
- UI wiring, form implementations
- Database schema additions
- Mechanical, well-defined work

## What Ralph Is Bad For

- Fuzzy product definitions (plan first with `/build-plan`)
- Core architecture decisions
- Security-sensitive changes (use `/security-review`)
- Performance optimization (needs human judgment)
- Complex business logic with edge cases

**Rule of thumb:** Ralph excels at mechanical work with clear patterns. If
the task requires judgment calls, do it yourself or break it into smaller
mechanical pieces.

## Autonomous Execution (No Human Oversight)

Same workflow, stricter discipline:

1. Read PROGRESS.md + prd.json + git log (mandatory)
2. Implement ONE story only
3. All quality gates must pass
4. Commit + record to artifact DB + update PROGRESS.md
5. If something breaks: record failure in DB, do NOT mark complete

Fresh context each session. Files and DB are the source of truth,
not conversation history.

## Errors

- No GROUNDING.md → prompt user to run `/project-organize`
- No artifact DB → run `db_init` (creates it)
- No sqlite3 → fall back to appending completions to `PROGRESS.md`
- No MCP Gateway → skip Qdrant memory sync, note in commit message

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
