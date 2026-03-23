# Sub-Project Skill — Build Plan

> Last updated: 2026-03-20
> Status: planning
> Based on: artifacts/research/008D, artifacts/research/008D/contested-deep-dive.md

## Executive Summary

Build a `sub-project` skill that partitions large projects into focused, quasi-independent workspaces with their own project docs, architecture context, and build plans. The skill runs automated analysis of the parent project, conducts a brief targeted interview, generates fresh project docs scoped to the sub-project, symlinks shared config, and produces a build-plan.md ready for `/meta-execute`. Three phases, 12 work units, ~1,260 LOC across SKILL.md + references + agents + scripts.

## Phases

### Phase 1: Core Skill — Analyze & Scaffold
- **Goal**: Skill can analyze a parent project, interview the user, and create a sub-project directory with generated docs
- **Milestone**: Running `/sub-project` on the skill suite itself produces a valid sub-project folder with architecture.md, features.md, CLAUDE.md, and symlinked shared config
- **Dependencies**: None — greenfield

### Phase 2: Context Distillation & Build Plan
- **Goal**: Skill generates a distilled architecture.md from parent context and produces a sub-project-specific build-plan.md
- **Milestone**: The generated architecture.md contains all 10 research-specified sections, and the build-plan.md has work units sized for `/meta-execute`
- **Dependencies**: Phase 1 complete

### Phase 3: Lifecycle & Integration
- **Goal**: Skill handles merge-back, cleanup, and integrates with existing meta-skills
- **Milestone**: A sub-project can be created, worked on independently, merged back, and cleaned up with no orphaned artifacts
- **Dependencies**: Phase 2 complete

## Technical Approach

### Skill Architecture

Standard suite pattern:
- **SKILL.md**: Main instructions (~400 lines, 5 phases)
- **references/**: Architecture template, doc partition matrix, merge-back protocol
- **agents/**: Subagent prompts for analysis, distillation, plan generation, scaffold, and merge-back
- **scripts/**: Shell helper for scaffolding + symlinks

### Context-Window Strategy

**Maximize subagent delegation.** Only Phase 2 (3-question interview) stays inline — it requires user interaction. All other phases dispatch to subagents:

```
Delegation key:
  [S] = subagent   — runs out of main context
  [I] = inline     — requires user interaction

  Phase 1: Analyze        [S]  — Sonnet subagent runs 5-step automated analysis
  Phase 2: Interview      [I]  — 3 targeted questions (show analysis findings first)
  Phase 3: Scaffold+Gen   [S]  — Sonnet subagent creates dirs, symlinks, generates docs
  Phase 4: Build Plan     [S]  — Sonnet subagent generates build-plan.md
  Phase 5: Merge-Back     [S]  — Sonnet subagent runs merge protocol (user confirms before destructive steps)
```

Each subagent reads its own prompt from `agents/`. Main thread passes parameters, reviews output, and handles user interaction only.

### Worktree Support (opt-in)

When `--worktree` is passed:
- Phase 3 creates a git worktree branch (`sub/<name>`) instead of a plain directory
- Sub-project lives at the worktree path, not under `sub-projects/`
- Phase 5 merge-back uses `git merge` instead of file copy
- Cleanup removes the worktree via `git worktree remove`

Default (no flag) uses the plain `sub-projects/<name>/` directory approach.

### Document Partitioning Strategy

**Generate Fresh** (scoped to sub-project):
| Doc | Why Fresh |
|-----|-----------|
| `architecture.md` | 10-section template distilled from parent — the core value of this skill |
| `build-plan.md` | Sub-project work units only |
| `features.md` | Sub-project features only |
| `project-context.md` | Scoped context |
| `todo.md` | Sub-project tasks only |
| `CLAUDE.md` | Sub-project rules + `@import` parent rules |
| `cnotes.md` | Fresh collaboration log |

**Symlink to Parent** (shared config):
| Doc | Why Symlink |
|-----|-------------|
| `coterie.md` | Multi-agent rules must stay in sync |
| Lint/format configs | Convention enforcement must match parent |
| `artifacts/db.sh` | Shared DB helper |

**Selective Copy** (curated transfer):
| Doc | Why Copy |
|-----|----------|
| Research findings | Only items relevant to sub-project scope |

### Sub-Project Directory Structure

```
<project-root>/
  sub-projects/
    <name>/
      architecture.md        ← generated (10-section distilled)
      build-plan.md          ← generated
      features.md            ← generated
      project-context.md     ← generated
      todo.md                ← generated
      CLAUDE.md              ← generated (@imports parent)
      cnotes.md              ← fresh
      coterie.md             ← symlink → ../../coterie.md
      artifacts/
        research/summary/
        reviews/
        db.sh                ← symlink → ../../../artifacts/db.sh
      src/                   ← sub-project source (or symlinks to parent dirs)
```

### Automated Analysis Pipeline (Phase 1 of skill)

Sonnet subagent runs before any user interaction:
1. **Dependency graph**: Grep imports/requires from target scope → map parent module needs
2. **Type extraction**: Find shared interfaces/types referenced by target files
3. **Build command detection**: Identify relevant build/test/lint commands
4. **Convention sampling**: Read code style from target area (indentation, naming, patterns)
5. **Test fixture inventory**: Identify test helpers/fixtures the sub-project needs

Output: structured markdown summary for user review + distillation input.

### Interview Protocol (Phase 2 of skill)

Show automated findings, then 3 targeted questions:
1. **What is the primary deliverable and merge-back timeline?**
2. **What parent components must NOT be modified?**
3. **What can this sub-project safely ignore from the parent?**

Skip with `--no-interview` or inline answers.

### Architecture.md Generation (Phase 3 of skill — the hard part)

10-section template from 008D research:
1. **Project Overview**: 1-paragraph scope
2. **Tech Stack**: Languages, frameworks, versions (from parent)
3. **Architecture**: Components relevant to sub-project + relationships
4. **Directory Structure**: Annotated sub-project tree
5. **API Surface**: Interfaces/types/contracts consumed from parent
6. **Cross-Cutting Concerns**: Auth, logging, DB schema, design tokens
7. **Coding Conventions**: Style rules with parent codebase examples
8. **Commands**: Build/test/lint for this scope
9. **Known Constraints**: Performance, security, gotchas
10. **Parent Dependencies**: Explicit import list with version constraints

Generated by Sonnet subagent reading parent docs + analysis output.

### Merge-Back Protocol (Phase 5 of skill)

1. Run integration tests against parent
2. Lint sub-project code with parent rules
3. Move/copy source files to final parent locations
4. Update parent features.md, todo.md with completed items
5. Archive sub-project artifacts to parent artifacts/
6. Remove sub-project directory (or keep if permanent)
7. Log to cnotes.md

## Work Unit Decomposition

| ID | Unit | Phase | Parallel? | LOC Est | Key Files | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|---------|-----------|--------------|---------------------|
| WU-1-01 | Skill directory scaffold | 1 | yes | ~50 | `skills/sub-project/SKILL.md` (skeleton), `skills/sub-project/references/`, `skills/sub-project/agents/`, `skills/sub-project/scripts/` | none | Directory tree exists; SKILL.md has valid frontmatter with name and ≤150 char description |
| WU-1-02 | Doc partition matrix | 1 | yes | ~80 | `skills/sub-project/references/doc-partition-matrix.md` | none | Covers all standard project docs; each has strategy (symlink/generate/copy), rationale, and path mapping; includes worktree variant paths |
| WU-1-03 | Architecture template | 1 | yes | ~120 | `skills/sub-project/references/architecture-template.md` | none | 10-section template with `{{PLACEHOLDER}}` markers, per-section instructions, and a filled example |
| WU-1-04 | Analysis agent prompt | 1 | yes | ~100 | `skills/sub-project/agents/analyze.md` | none | Sonnet subagent prompt; runs 5-step pipeline (deps, types, build cmds, conventions, test fixtures); outputs structured markdown to `/tmp/sub-project-analysis.md`; includes [SCOPE_PATH], [PROJECT_ROOT], [SUB_PROJECT_NAME] placeholders |
| WU-1-05 | Scaffold agent prompt | 1 | yes | ~100 | `skills/sub-project/agents/scaffold.md` | WU-1-02 | Sonnet subagent prompt; creates sub-project tree per partition matrix; creates symlinks for shared config; creates fresh doc skeletons; handles both directory and worktree modes; references scaffold.sh for execution |
| WU-1-06 | Scaffold script | 1 | no | ~80 | `skills/sub-project/scripts/scaffold.sh` | WU-1-01, WU-1-02 | Creates sub-project tree per partition matrix; handles `--worktree` flag (git worktree add vs mkdir); creates symlinks; `bash -n` passes; `shellcheck` clean |
| WU-1-07 | SKILL.md Phases 1-2 | 1 | no | ~200 | `skills/sub-project/SKILL.md` | WU-1-01 thru WU-1-06 | Phase 1 dispatches analysis subagent [S], presents findings inline. Phase 2 is inline [I] 3-question interview. Follows skill-forge checklist |
| WU-2-01 | Distillation agent prompt | 2 | yes | ~120 | `skills/sub-project/agents/distill.md` | WU-1-07 | Sonnet subagent prompt; reads parent project docs + analysis output + interview answers; generates architecture.md (10-section), features.md, project-context.md, CLAUDE.md/rules; writes all to sub-project dir |
| WU-2-02 | Plan generation agent prompt | 2 | yes | ~100 | `skills/sub-project/agents/plan.md` | WU-1-07 | Sonnet subagent prompt; reads generated architecture.md + features.md; generates build-plan.md with WU-format units (50-200 LOC each); output consumable by `/meta-execute` |
| WU-2-03 | SKILL.md Phases 3-4 | 2 | no | ~150 | `skills/sub-project/SKILL.md` | WU-2-01, WU-2-02 | Phase 3 dispatches scaffold subagent [S] then distill subagent [S]. Phase 4 dispatches plan subagent [S]. Main thread reviews outputs and presents to user for confirmation |
| WU-3-01 | Merge-back protocol + agent | 3 | yes | ~120 | `skills/sub-project/references/merge-back-protocol.md`, `skills/sub-project/agents/merge-back.md` | WU-2-03 | 7-step checklist + Sonnet subagent prompt; handles directory mode (file copy) and worktree mode (git merge); covers integration test, convention check, parent doc updates, artifact archival, cleanup |
| WU-3-02 | SKILL.md Phase 5 | 3 | no | ~100 | `skills/sub-project/SKILL.md` | WU-3-01 | Phase 5 dispatches merge-back subagent [S]; main thread confirms destructive steps with user before proceeding; handles both disposable and permanent sub-projects |
| WU-3-03 | Validation & registration | 3 | no | ~50 | `skills/sub-project/SKILL.md` (final) | WU-3-02 | Passes skill-forge validation checklist; description ≤150 chars; no bare `timeout`; no hardcoded secrets; cross-cutting rules referenced; cnotes entry written |

## Dependency Graph

```
Wave 1:  WU-1-01  WU-1-02  WU-1-03  WU-1-04  WU-1-05  (5 parallel)
Wave 2:  WU-1-06                                         (needs 1-01, 1-02)
Wave 3:  WU-1-07                                         (needs all Phase 1)
Wave 4:  WU-2-01  WU-2-02                                (2 parallel)
Wave 5:  WU-2-03                                         (needs 2-01, 2-02)
Wave 6:  WU-3-01                                         (needs 2-03)
Wave 7:  WU-3-02                                         (needs 3-01)
Wave 8:  WU-3-03                                         (needs 3-02)
```

**Critical path**: 8 waves. Wave 1 runs 5 units in parallel. Wave 4 runs 2 in parallel.

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Architecture.md distillation loses critical parent context | High | Medium | 10-section template forces explicit coverage; "Parent Dependencies" section catches imports; interview question #3 catches what to ignore |
| CLAUDE.md `@import` doesn't work for sub-project paths | Medium | Low | Test during WU-2-03; fallback: copy relevant parent rules into sub-project CLAUDE.md directly |
| Symlinks confuse user's IDE or git status | Low | Low | Symlinks are for shared config only (coterie, lint); generate-fresh is default for all project docs |
| Merge-back creates conflicts with parallel parent changes | High | Medium | Merge-back protocol includes parent rebase step; short-lived sub-projects recommended |
| Automated analysis misses implicit dependencies | Medium | Medium | Interview catches gaps; architecture.md "Parent Dependencies" section is manually reviewable |
| Sub-project artifacts/project.db conflicts with parent DB | Medium | Low | Sub-project gets own DB; merge-back protocol transfers relevant findings |

## Counter-Analysis: Alternatives Evaluated

Three alternatives were evaluated against the full skill process:

### A: "CLAUDE.md Scope Only" (lighter)

Just create a directory with a CLAUDE.md containing distilled context. Let Claude Code's native on-demand loading handle the rest.
**Rejected**: Too thin. Doesn't deliver architecture.md (10 sections), features.md, build-plan.md, or merge-back. Insufficient for the use case.

### B: "Meta-Init Variant" (reuse existing)

Extend meta-init with `--sub-project` flag, reuse project-scaffold, project-questions, build-plan.
**Rejected**: Needs differ fundamentally — shorter interview (3 vs aggressive probe), context from parent distillation (not user brain), architecture.md is THE deliverable (meta-init doesn't generate it), merge-back has no analog. Would bloat meta-init with conditional branches.

### C: "Git Worktrees" (heavier isolation)

Use `git worktree add` for true git-level isolation per sub-project.
**Partially adopted**: Worktree overhead is real (10+ min for node_modules), but git isolation is valuable for some cases. Added as `--worktree` opt-in flag. Default remains directory-based.

**Verdict**: Current plan is the right approach. One improvement adopted (worktree opt-in). The skill is different enough from meta-init to warrant its own skill, and substantial enough that CLAUDE.md-only is insufficient.

### Additional Finding: Rules Directory

This project uses `rules/general.md` instead of CLAUDE.md. The sub-project should generate a `rules/` directory with a sub-project-specific rules file that references the parent's rules. Update WU-2-03 to handle both CLAUDE.md and rules/ patterns.

## Resolved Decisions

1. **Sub-project naming**: User-provided. The user names it or tells Claude the name. No auto-suggestion.
2. **Rules inheritance**: Detect parent pattern (CLAUDE.md vs `rules/`). Sub-project mirrors it — symlink shared rules, add sub-project-specific rules file.
3. **`--worktree` flag**: Included in v1 as opt-in. Default is directory-based under `sub-projects/`.
4. **`artifacts/project.db`**: Sub-project gets own DB (isolation). Merge-back transfers relevant findings.
5. **Subagent delegation**: All non-interactive phases delegated to Sonnet subagents. Only interview (Phase 2) stays inline.

## Open Items

1. **Skill description draft**: `"Partitions large projects into focused sub-project workspaces with distilled context. Invoke explicitly with /sub-project."`  (134 chars) — confirm during WU-3-03.
2. **Integration with meta-execute**: Sub-project's build-plan.md must be directly consumable by `/meta-execute`. Verify format compatibility in WU-2-02.

## Changelog
<!-- Append-only -->
- 2026-03-20: Initial plan from 008D research + contested deep dive
