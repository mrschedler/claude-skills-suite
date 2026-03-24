# PLAN.md — Skills Suite Adoption

**Status**: All phases complete.
**Last updated**: 2026-03-23

## Objective

Adapt the best skills from trevorbyrum/claude-skills-suite into a working, agent-agnostic skill set for Matt's Windows + MCP Gateway environment. Every adopted skill must be self-sufficient (no external CLIs required to function) and integrate with the existing memory/infra stack. Skills describe WHAT to do — the executing agent decides HOW.

## Phases

### Phase 0: Foundation (DONE)
- [x] Fork repo to mrschedler/claude-skills-suite
- [x] Clone to C:\dev\claude-skills-suite
- [x] Create junction: C:\dev\claude-home → ~/.claude
- [x] Write GROUNDING.md
- [x] Write this PLAN.md
- [x] Audit existing skills (feature-dev, ralph-workflow)

**Acceptance**: GROUNDING.md exists, repo cloned, junction works.

### Phase 1: Wire Up + Quick Wins
**Goal**: Get the skills path working and adopt skills that need zero or minimal adaptation.

- [x] Add `C:\dev\claude-skills-suite\skills` to `~/.claude/settings.json` skills path
- [x] Move existing `feature-dev` and `ralph-workflow` from `~/.claude/skills/` into this repo (single source of truth)
- [x] Clean up cross-cutting rules: rewrite `references/cross-cutting-rules.md` — agent-agnostic, no project litter, infrastructure as enhancement not requirement
- [x] Rewrite `rules/general.md` — agent-agnostic task delegation, stripped macOS/Trevor infra, kept good patterns (polling rules, output management, approach selection)
- [x] Adopt `quick-plan` — works as-is, no changes needed
- [x] Adopt `skill-forge` — rewritten agent-agnostic, 300-line limit, no CLI assumptions
- [x] Adopt `project-scaffold` — rewritten: GROUNDING.md instead of coterie/cnotes, removed SQLite/artifacts, cleaned templates

**Acceptance**: All skills invoke correctly. Existing skills still work. No broken references.

### Phase 2: Review Lenses
**Goal**: Adapt the highest-value review skills to be self-sufficient and agent-agnostic.

- [x] Adopt `security-review` — rewritten: P0/P1/P2 kept, OWASP Agentic kept, all multi-model dispatch removed, references GROUNDING.md
- [x] Adopt `completeness-review` — rewritten: agent-agnostic, removed SQLite/artifact DB refs
- [x] Adopt `test-review` — rewritten: agent-agnostic, kept mutation testing + PBT + strategy shapes, removed CLI dispatch
- [x] Adopt `drift-review` — rewritten: references GROUNDING.md, removed Codex dispatch, agent-agnostic
- [x] Create `references/review-lens-framework.md` (our version) — agent-agnostic, MCP optional, no SQLite
- [x] Adopt `review-fix` — rewritten: simplified, agent-agnostic, no Codex/worker pool coupling

**Acceptance**: Each lens runs standalone and produces structured findings. No CLI dependencies.

### Phase 3: Planning + Project Lifecycle
**Goal**: Integrate build planning and project context skills with our GROUNDING.md pattern.

- [x] Adopt `build-plan` — rewritten: kept work unit sizing (50-200 LOC), dependency graphing, integration wiring audit. Removed all CLI calls.
- [x] Adopt `project-context` — rewritten: complements GROUNDING.md, doesn't duplicate it
- [x] Adopt `project-questions` — rewritten: agent-agnostic, removed Gemini/Copilot domain research dispatch
- [ ] Evaluate `meta-join` — onboarding to existing projects (could complement rehydrate)
- [ ] Evaluate `evolve` — sync docs to match current code

**Acceptance**: `/build-plan` produces a usable project-plan.md. All skills work without errors.

### Phase 4: Meta-Skills (Adapted)
**Goal**: Create lightweight orchestration skills that chain the atomic skills. Agent-agnostic — describe the workflow, let the executing agent handle delegation.

- [x] Create `meta-review` — 4-lens orchestration (security, completeness, test, drift), agent-agnostic parallel execution, verdict synthesis (READY/CONDITIONAL/NOT READY)
- [x] Create `meta-init` — chains project-questions → project-scaffold → project-context (optional) → build-plan
- [ ] Evaluate whether `meta-execute` patterns (wave-gated, work unit queue) can be described agent-agnostically

**Acceptance**: `/meta-review` and `/meta-init` work with any capable agent.

### Phase 5: Hooks + Automation
**Goal**: Evaluate Trevor's hooks against our existing hooks and adopt what improves our workflow.

- [x] Adopt `stop-check.sh` two-gate pattern → `stop-quality-gate.sh` — blocks first stop, forces over-engineering self-review + GROUNDING.md check
- [x] Adopt `pre-commit-codex-lint.sh` deterministic portion → `pre-commit-lint.sh` — gitleaks + ruff + biome/oxlint on git commit (tools optional, graceful skip)
- [x] Adopt `post-edit-complexity.sh` → adapted for Windows — ruff C901 for Python, eslint sonarjs for JS/TS (tools optional)
- [x] Adopt `pre-compact-safety.sh` concept → `pre-compact-capture.sh` — saves git state + recent files snapshot before compaction
- [x] Skip `session-start.sh` — our session-prewarm.sh is significantly more capable (gateway integration, coordination, Obsidian notes)

**Acceptance**: All hooks syntax-valid, wired in settings.json, tools gracefully skipped if not installed.

## Skills Evaluation Matrix

### Adopt (high value, low/medium adaptation)

| Skill | Value | Adaptation | Notes |
|-------|-------|------------|-------|
| `quick-plan` | High | None | Works as-is |
| `skill-forge` | High | Low | Update paths, remove CLI refs |
| `security-review` | High | Medium | Strip multi-model, keep structure |
| `completeness-review` | High | Low | Catches stubs/TODOs |
| `test-review` | High | Low | Testing framework |
| `build-plan` | High | Medium | Strip CLI calls, keep planning logic |
| `project-scaffold` | Medium | Medium | Adapt to GROUNDING.md pattern |
| `project-context` | Medium | Low | Complement GROUNDING.md |
| `project-questions` | Medium | Low | Interview skill |
| `drift-review` | Medium | Low | Code vs docs drift |
| `review-fix` | Medium | Medium | Implement fixes from review findings |

### Evaluate (potentially useful, needs more assessment)

| Skill | Question |
|-------|----------|
| `meta-join` | Does this add value over our rehydrate workflow? |
| `evolve` | Useful for keeping GROUNDING.md current? |
| `breaking-change-review` | Relevant for our API projects? |
| `release-prep` | Changelog + version bump — do we need this? |
| `clean-project` | Project cleanup — overlaps with what? |
| `log-gen` / `log-review` | Logging instrumentation — useful for support portal? |

### Skip (low value or too coupled to Trevor's setup)

| Skill | Reason |
|-------|--------|
| `codex`, `gemini`, `vibe`, `cursor`, `copilot` | Driver skills for CLIs we don't have |
| `meta-execute` (as-is) | 500 lines, deeply coupled to 5-CLI orchestration |
| `deploy-gateway` | Trevor's infrastructure |
| `infra-health` | Trevor's infrastructure |
| `github-sync` / `github-pull` | Simple git operations, don't need a skill |
| `repo-create` | One-time operation |
| `init-db` | SQLite artifact store — we use Qdrant/MongoDB |
| `sync-skills` | Suite maintenance for his setup |
| `sub-project` / `sub-project-merge` | Monorepo patterns we don't use |
| `todo-features` | His tracking pattern |
| `meta-context-save` | His compaction workflow |
| `meta-deep-research` / `meta-deep-research-execute` | Massive research pipeline, overkill |
| `meta-production` | 12-dimension readiness — we're not at that scale |
| `ui-design` / `ui-review` / `browser-review` | UI-specific, evaluate later if needed |
| `compliance-review` / `counter-review` | Enterprise patterns, not needed now |

## Files to Clean Up in This Repo

These are Trevor's project-specific files that should be removed or replaced:

- [x] `coterie.md` — DELETED
- [x] `cnotes.md` — DELETED
- [x] `project-context.md` — DELETED (replaced by GROUNDING.md)
- [x] `project-plan.md` — DELETED (replaced by PLAN.md)
- [x] `todo.md` — DELETED
- [x] `features.md` — DELETED
- [x] `references/gateway-dev.md` — DELETED
- [x] `rules/general.md` — REWRITTEN (agent-agnostic)
- [x] `references/cross-cutting-rules.md` — REWRITTEN (agent-agnostic)
- [ ] `research-synthesis.md` — KEEP as reference for how research output looks
- [ ] `skill-suite-build-spec.md` — KEEP as architecture reference
- [ ] `Multi-agent-cli-orchastration-init.md` — KEEP as reference, not operational
- [ ] `references/design-*.md` — EVALUATE (his design system, may be useful templates)

## Open Questions

1. **Skills path structure**: Should adopted skills live in this repo's `skills/` directory and be referenced via settings.json, or should they be copied to `~/.claude/skills/`? (Recommendation: this repo, pointed to by settings.json — single source of truth, git-tracked.)

2. **Artifact persistence**: Trevor uses SQLite+FTS5 per-project. We have Qdrant/MongoDB. Should review findings go to Qdrant, or is local SQLite actually better for ephemeral per-project findings? (Lean: Qdrant for cross-project memory, skip SQLite.)

3. **Existing skills migration**: Move `feature-dev` and `ralph-workflow` into this repo, or keep them separate in `~/.claude/skills/`? (Recommendation: move them here for single source of truth.)
