# Claude Skills Suite -- Engineering Notebook

Project: Claude Skills Suite (mrschedler/claude-skills-suite)
Started: 2026-03-11
Notebook started: 2026-03-25

This notebook records the evolution of the Claude Skills Suite: what was tried, what
worked, what failed, and why. Entries are dated; git commit history provides
authenticated timestamps. Each entry should capture reasoning, not just outcomes.

---

## Entry 0 -- Origin (2026-03-11)

**What:** Forked Trevor Byrum's `trevorbyrum/claude-skills-suite` and cloned to
`C:\dev\claude-skills-suite`. Initial commit brought in 40+ skills covering project
lifecycle, reviews, research, CLI drivers, multi-model orchestration, and 7 lifecycle
hooks. The suite was designed around progressive disclosure (frontmatter always loaded,
SKILL.md on trigger, references on demand) and multi-model orchestration across 6 AI
CLIs (Claude, Codex, Gemini, Cursor, Copilot, Vibe/Mistral).

**Why:** Matt needed reusable agent instructions that encode planning discipline, review
rigor, and execution patterns. Every AI session was starting cold -- re-explaining
expectations, project boundaries, and quality standards. Trevor's framework was the most
mature open-source skill suite available: review lenses, build planning decomposition,
research pipelines, and a progressive disclosure architecture that respects context windows.

**Result:** Clean import. The architecture was sound but deeply coupled to Trevor's
macOS + 5-CLI multi-model setup. Would need significant adaptation for Matt's Windows +
Git Bash + MCP Gateway environment.

**Evidence:** Git SHA `4c47d87` (initial commit). Trevor's original README describes the
full architecture.

---

## Entry 1 -- Adaptation for Matt's Infrastructure (2026-03-23)

**What:** Full adaptation session. Rewrote cross-cutting rules, global rules, and 15
skills for Matt's environment. Created junction link (`C:\dev\claude-home` to `~/.claude`).
Wrote GROUNDING.md and PLAN.md with 5-phase adoption approach. Cleaned up Trevor's
project-specific files (coterie.md, cnotes.md, project-context.md, project-plan.md,
todo.md, features.md, gateway-dev.md). Moved feature-dev and ralph-workflow into repo
as single source of truth.

**Why:** Trevor's suite assumed macOS, Homebrew, 5 external CLIs (Codex, Gemini, Vibe,
Cursor, Copilot), and a SQLite artifact store. Matt's environment is Windows 11 with
Git Bash, MCP Gateway on Unraid (Qdrant/Neo4j/MongoDB), and Claude Code as primary agent.
The cherry-pick approach was chosen over wholesale adoption -- each skill must earn its
place by being useful in this environment.

**Result:** 15 skills fully adapted across 4 phases (quick wins, review lenses, planning,
meta-skills). 4 hooks deployed. Key architectural decisions established:
- Agent-agnostic: skills describe WHAT, executing agent decides HOW
- GROUNDING.md replaces coterie.md/cnotes.md as primary project context
- MCP Gateway optional, not required
- 300-line skill limit with overflow to references/
- No project litter (framework-specific files in target projects)

**Evidence:** Git SHA `23b30f0` (Adapt skills suite for Schedler environment).
Qdrant: search "Claude Skills Suite adoption phases complete 2026-03-23"

---

## Entry 2 -- Project Organization Conventions (2026-03-25)

**What:** Created `/project-organize` skill to replace both `/project-scaffold` (new
projects) and `/clean-project` (audit/tidy). Established GROUNDING.md and
ENGINEERING-NOTEBOOK.md as first-class project documentation conventions. Updated 4
skills for GROUNDING.md integration (clean-project, doc-audit, sub-project, meta-init).
Deprecated project-scaffold and clean-project, moved them to `skills/archive/`. Updated
6 referencing skills to point to project-organize. Established Qdrant search hints
convention (not UUIDs) for evidence references in durable documents.

**Why:** Matt was using two separate skills for what is conceptually one job: getting a
project organized so a cold-start agent can be productive. The scaffold skill only
handled new projects; clean-project only handled existing ones. A single skill with a
discover-then-act pattern handles both cases. The GROUNDING.md convention was already
working well on G3-Lite -- formalizing it in a skill makes it repeatable across all
projects. UUIDs in notebooks were a maintenance burden because they break on Qdrant
reindexing -- search hints are migration-safe.

**Result:** /project-organize is a 5-phase skill (discover, create, fix stale docs,
audit structure, commit+store) that was immediately battle-tested on G3-Lite and
G3-Enterprise the same day it was created. Both projects got GROUNDING.md, engineering
notebooks, stale doc fixes, and pipeline updates. The project doc hierarchy is now:
- GROUNDING.md (WHY) > CLAUDE.md (QUICKSTART) > ENGINEERING-NOTEBOOK.md (JOURNEY)
- project-context.md (WHAT/HOW), CURRENT-STATE.md (NOW), PLAN-*.md (NEXT)

**Evidence:** Git SHA `e2bef33` (Add /project-organize skill), `1d97c9b` (Move
deprecated skills to archive/). Qdrant: search "project-organize skill created replaces
scaffold"

---

## Entry 3 -- Simplification Plan (2026-03-25)

**What:** Matt assessed the full skill suite and concluded 55 slash commands is
overwhelming. Proposed reducing to ~5 top-level user-facing skills + 3 hooks + sub-skills
for everything else. The top-level skills would be: project-organize, feature-dev,
research, review, ship. Hooks would handle memory assessment (post-session), doc drift
(post-code-change), and notebook prompting (post-decision). All other skills would become
sub-skills with `disable-model-invocation: true`.

**Why:** Matt thinks in higher-level terms ("organize this", "build this feature",
"review this", "ship this") not granular skill names. Having 55 slash commands forces
him to remember which specific skill handles which case. The insight: top-level skills
should map to how he thinks about work, with sub-skills handling the decomposition
internally.

**Result:** Plan approved but NOT yet executed. Critical prerequisite: must catalog
Trevor's original skills and understand the research/intent behind each one before
reclassifying. Trevor's deep-research skill alone orchestrates ~20 workers across 3
model families -- that research pipeline design has value even if the current
implementation is too coupled to his CLI setup. This work is tracked under the
memory-upgrade initiative (not a standalone project).

**Evidence:** Qdrant: search "skill suite simplification plan 2026-03-25"

---

<!-- New entries go above this line. Use the format:

## Entry N -- Title (YYYY-MM-DD)

**What:** What was done or decided.

**Why:** Why this approach was chosen. What alternatives were considered.

**Result:** What happened. Did it work? What was learned?

**Evidence:** Git SHAs, Qdrant search hints (not UUIDs -- IDs break on migration), file refs.

---
-->
