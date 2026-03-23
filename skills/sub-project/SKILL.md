---
name: sub-project
description: "Creates an isolated sub-project workspace within a parent project to keep Claude's context focused and high-quality. Invoke with /sub-project."
---

# Sub-Project

Partitions a parent project into a focused sub-workspace so Claude operates
within a lean, high-quality context instead of degrading across a bloated one.
Quality at 100K tokens is fundamentally different from quality at 500K — this
skill exists to keep every session in the high-accuracy zone.

**Context-window strategy**: Non-interactive phases delegate to subagents.
The discovery interview (Phase 2) stays inline. Each subagent reads its own
instructions from `agents/` — never load reference files into main context
unless explicitly needed.

## Inputs

| Input | Source | Required |
|---|---|---|
| Sub-project name | User prompt | Yes |
| Sub-project path | User prompt or `<parent>/<name>/` | Yes |
| Task description | User prompt | Yes |
| Parent project root | cwd or user prompt | Yes |
| `--worktree` | Flag | No (opt-in git isolation) |
| `--no-interview` | Flag | No (skip Phase 2 discovery) |

## Outputs

- Sub-project directory with tailored project docs
- `architecture.md` — distilled parent context + sub-project specifics
- `build-plan.md` — sub-project-specific implementation plan
- `features.md` — sub-project feature set
- CLAUDE.md or `rules/` config (mirrors parent pattern)
- Symlinked shared config (coterie.md, linting, etc.)
- `cnotes.md` — fresh collaboration log
- `todo.md` — fresh task tracker

## Instructions

### Phase 0: Detect Parent Pattern

Before anything else, detect how the parent project configures Claude:

1. Check for `CLAUDE.md` in parent root
2. Check for `.claude/rules/*.md` or `rules/*.md` in parent root
3. Check for both

Store the result — the sub-project mirrors whichever pattern(s) the parent
uses.

Check for existing sub-projects (directories with their own `architecture.md`
or `CLAUDE.md` inside the parent). If siblings exist, list them and warn about
potential conflicts with shared parent dependencies.

Pre-calculate relative symlink paths from the sub-project directory back to
the parent root. Pass these as explicit values to the scaffolder — do not
delegate path math to the subagent.

Also detect:
- Does `coterie.md` exist? (symlink target)
- Does `project-context.md` exist? (distillation source)
- Does `project-plan.md` exist? (scope reference)
- Does `features.md` exist? (feature reference)
- Does `architecture.md` exist? (architecture reference)
- What's in `.gitignore`? (inherit relevant patterns)

### Phase 1: Analyze Parent Project [Subagent]

Dispatch a Sonnet subagent to analyze the parent project. Read
`agents/analyzer.md` for the prompt template — fill in placeholders before
spawning.

The analyzer extracts:
- Dependency graph (imports, exports, module boundaries)
- Tech stack and framework versions
- API surface of modules relevant to the sub-project task
- Type definitions and shared interfaces
- Build/test/lint commands
- Coding conventions (from linting config, existing code patterns)
- Cross-cutting concerns (auth, logging, DB, design tokens)

The analyzer writes its findings to a temp file. Read the output when complete.

**Exit condition**: Analyzer output exists with dependency graph, API surface,
and conventions extracted.

### Phase 2: Discovery Interview [Inline]

Show the analyzer's findings to the user, then ask up to 3 targeted questions
to fill gaps automation cannot:

1. **What is the primary deliverable and merge-back timeline?**
   (Intent and constraints not inferrable from code)

2. **What must NOT be modified in the parent project?**
   (Tribal knowledge — frozen APIs, shared state, protected paths)

3. **What conventions apply locally but aren't enforced in code?**
   (Naming patterns, architectural decisions, team norms)

Skip questions the analyzer already answered. If the analyzer covered
everything, skip the interview entirely and confirm with the user:
> "Automated analysis looks complete. Anything to add before I scaffold?"

**Exit condition**: User confirms the scope is clear.

### Phase 3: Scaffold Sub-Project [Subagent]

Dispatch a Sonnet subagent to create the sub-project directory structure.
Read `agents/scaffolder.md` for the prompt template.

The scaffolder creates:

```
<sub-project>/
  artifacts/
    research/
      summary/
    reviews/
    compact/
  references/
  CLAUDE.md (or rules/, or both — mirrors parent)
  coterie.md -> ../../coterie.md (symlink)
  .gitignore (inherited + sub-project additions)
  cnotes.md (fresh from template)
  todo.md (fresh from template)
```

**Symlinked files** (always current, single source of truth):
- `coterie.md` — collaboration rules are project-wide
- Linting configs (`.eslintrc`, `.prettierrc`, etc.) if they exist
- `.editorconfig` if it exists
- Design token files if they exist

**Generated fresh** (tailored to sub-project scope):
- `architecture.md` — Phase 4 handles this
- `build-plan.md` — Phase 5 handles this
- `features.md` — Phase 5 handles this
- `project-context.md` — lightweight, sub-project scoped
- `CLAUDE.md` / `rules/` — references sub-project docs, not parent
- `cnotes.md` — empty template
- `todo.md` — empty template

**Exit condition**: Directory structure exists. Symlinks verified. Fresh files
created with template content.

### Phase 4: Distill Architecture [Subagent]

This is the critical phase. Dispatch an Opus subagent to generate
`architecture.md`. Read `agents/distiller.md` for the prompt template.

The distiller receives:
- Analyzer output from Phase 1
- User answers from Phase 2
- Parent's `project-context.md`, `architecture.md`, and `project-plan.md`

It produces `architecture.md` with these 11 sections:

1. **Project Overview** — 1 paragraph: what this sub-project builds and why
2. **Tech Stack** — languages, frameworks, versions (from parent)
3. **Architecture** — relevant components and their relationships
4. **Directory Structure** — annotated tree of the sub-project
5. **API Surface** — interfaces, types, exported contracts from parent that
   this sub-project consumes or produces
6. **Cross-Cutting Concerns** — auth, logging, DB schema, design tokens —
   only what's relevant to this sub-project's scope
7. **Coding Conventions** — style rules with code examples (from parent).
   Includes a **Testing** subsection: test file structure, runner, mocking
   patterns, coverage expectations
8. **Commands** — build, test, lint with full flags (adapted for sub-project)
9. **Known Constraints** — performance, security, compatibility requirements
10. **Parent Dependencies** — explicit list of what this sub-project imports
    from the parent, with file paths and version constraints
11. **Parent Modifications** — explicit list of parent files this sub-project
    will modify (migrations, shared types, API endpoints), with the nature
    of each change. Empty if sub-project is purely additive

**Design principle**: This file must contain almost everything Claude needs to
complete the sub-project build. Minimize trips back to the parent project.
Think of it as a "context distillation" — 70-98% compression of the parent
while preserving all information relevant to this scope.

**Exit condition**: `architecture.md` exists with all 11 sections populated.
No placeholders, no "TBD", no "see parent project."

### Phase 5: Generate Project Docs [Subagent]

Dispatch a Sonnet subagent to generate the remaining project docs. Read
`agents/doc-generator.md` for the prompt template.

Generate:
- **`build-plan.md`** — Sub-project specific. Phases, milestones, work units
  sized for the sub-project scope. Follow the same format as the parent's
  `project-plan.md` but scoped to this deliverable only.
- **`features.md`** — Sub-project feature set. What this sub-project delivers,
  acceptance criteria, status tracking.
- **`project-context.md`** — Lightweight context doc. Scope, constraints,
  decisions specific to this sub-project. References `architecture.md` for
  technical details rather than duplicating.
- **CLAUDE.md** (or rules/) — References sub-project docs. Points to
  `architecture.md`, `build-plan.md`, `features.md`, `coterie.md`.

**Exit condition**: All docs exist, internally consistent, no references to
missing files.

### Phase 6: Transfer Research [Inline]

Check the parent's `artifacts/research/` for relevant prior research.

1. List all research summaries in `artifacts/research/summary/`
2. For each, read the title and executive summary
3. Present relevant ones to the user:
   > "Found {N} research summaries. These look relevant to the sub-project:
   > - 003D: Authentication patterns for microservices
   > - 005: WebSocket scaling strategies
   > Copy these to the sub-project? (y/n/pick)"
4. Copy selected summaries to `<sub-project>/artifacts/research/summary/`

**Exit condition**: Relevant research transferred (or none if not applicable).

### Phase 7: Worktree Setup [Inline, Opt-In]

If the user passed `--worktree` or requests git isolation:

1. Create a git branch: `sub/<sub-project-name>`
2. Create a worktree: `git worktree add <sub-project-path> sub/<sub-project-name>`
3. Verify the worktree is functional

If not requested, the sub-project lives as a subdirectory in the main worktree.
Present the option:
> "Sub-project is ready as a subdirectory. Want git isolation via worktree?
> (Recommended for parallel development or risky refactors)"

**Exit condition**: Worktree created if requested, or user confirmed subdirectory
mode.

### Phase 8: Validation & Presentation [Inline]

Final checks:
1. All symlinks resolve correctly
2. All generated docs exist and have content
3. `architecture.md` has all 11 sections
4. `build-plan.md` has work units with acceptance criteria
5. No broken file references in CLAUDE.md / rules/
6. Sub-project can be `cd`'d into and Claude would have full context

Present the summary:
> "Sub-project `{name}` is ready at `{path}`.
>
> **Symlinked** (stays current): coterie.md, [linting configs]
> **Generated** (sub-project specific): architecture.md, build-plan.md,
>   features.md, project-context.md, CLAUDE.md
> **Research transferred**: [list or "none"]
> **Git isolation**: worktree on `sub/{name}` / subdirectory mode
>
> Next steps:
> 1. `cd {path}` and start building
> 2. Run `/meta-execute` to implement the build plan
> 3. Run `/meta-review` to review the sub-project docs first"

## Error Handling

- If parent has no `project-context.md`, warn and proceed — the analyzer and
  interview must compensate.
- If parent has no `architecture.md`, the distiller works from analyzer output
  and `project-context.md` alone.
- If symlink creation fails (Windows, permissions), fall back to copy with a
  warning: "Symlink failed — copied instead. This copy will NOT auto-update."
- If the analyzer subagent fails, fall back to the interview for all context
  gathering. Skip Phase 1 findings presentation.

## Merge-Back Guidance

When the sub-project is complete and ready to merge back:

1. Run integration tests from the parent root
2. Check for convention drift (run `/compliance-review` from parent)
3. Update parent's `project-plan.md` to reflect completed work
4. Remove worktree if used: `git worktree remove <path>`
5. Clean up the sub-project branch if merged

This guidance is documented in the sub-project's `architecture.md` under
"Known Constraints" so future sessions have it.

## Examples

```
User: "/sub-project auth-service — build the authentication microservice"
Action: Detect parent pattern. Analyze parent for auth-related modules.
        Interview for constraints. Scaffold auth-service/. Distill
        architecture.md with auth focus. Generate build-plan. Present.
```

```
User: "/sub-project frontend-redesign --worktree"
Action: Full flow with git worktree isolation. Branch sub/frontend-redesign.
        Distill architecture.md with frontend focus. Transfer relevant
        UI research.
```

```
User: "I need to break out the payment processing into its own context"
Action: Detect trigger. Create sub-project for payment processing.
        Heavy emphasis on API surface and cross-cutting concerns (auth,
        logging, DB schema for transactions).
```

```
User: "/sub-project api-v2 — rewrite the REST API to GraphQL"
Action: Analyze existing REST endpoints. Distill architecture.md with
        full API surface documentation. Generate build-plan for
        migration work units. Transfer API-related research.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
