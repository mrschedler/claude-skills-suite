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

## Entry 4 -- claude-deep-research: Analysis and Design (2026-03-28)

**What:** Deep analysis of Trevor's `meta-deep-research` + `meta-deep-research-execute` skills
(1,019 lines of combined instructions, 6-phase protocol, 4 research tracks, 3-model debate).
Designed a Claude-only replacement called `claude-deep-research` that preserves the protocol's
strengths while fixing fundamental flaws exposed by real-world usage.

**Why:** The original skill was designed for a multi-CLI, multi-model world (Codex, Gemini, Claude)
that rarely materializes in practice. Analysis of 7+ actual research runs (001D-008D) revealed:
- The "full protocol" as designed has likely **never executed as written** -- every run shows
  degradation (Codex unavailable, Gemini timed out, self-consistency fallback)
- ~40% of instruction tokens are spent on tracks (Codex CLI, Gemini CLI) that rarely execute
- 4 cross-cutting rule violations (Rules 3, 4, 6, 10): hardcoded model names, macOS paths,
  embedded CLI commands, broken Windows compatibility
- Subagents writing directly to SQLite creates race conditions (no WAL mode, no busy timeout)
  and fragile dependency chain (sqlite3 PATH, git rev-parse, xxd)
- No progress feedback (15-50 minute black box), no checkpoint/resume
- 1000+ source target hit in only 1 of 4 examined runs
- Debate between 3 Claude instances is self-consistency, not true adversarial debate

**What's genuinely good (preserved in rewrite):**
- Output format (executive summary, confidence map, contested claims, source index)
- Artifact DB intermediate storage with skill/phase/label key scheme
- research-connector agent with multi-query protocol
- Coverage expansion concept (catches gaps initial fan-out misses)
- Convergence scoring matrix (6 levels: VERIFIED → UNRESOLVED)
- Context isolation (dispatcher stays lean, heavy work in one subagent)

**Key design decisions for claude-deep-research:**

1. **Orchestrator owns all DB writes.** Subagents return structured content in Agent tool
   responses. Orchestrator batch-writes to SQLite. Eliminates: sqlite3 PATH issues, race
   conditions, git rev-parse fragility, shell escaping problems.

2. **Steelman/Steelman debate replaces 3-model theater.** One subagent builds strongest case
   FOR emerging consensus, one builds strongest case AGAINST, orchestrator judges. Rationale:
   3 Claude instances don't bring genuine epistemic diversity (same training data, same biases).
   Steelman/steelman is more efficient (3 docs vs 9) and more honest about what single-model
   debate provides. Still catches contested claims through forced adversarial framing.

3. **200-300 line instruction target.** Original loads 1,019 lines into orchestrator context
   (~7.5% consumed before any research). Lean instructions = more context for actual research.

4. **Progress tracking.** Orchestrator writes progress file after each phase. Dispatcher can
   report status. No more 30-minute black box.

5. **Checkpoint/resume.** Each phase checks DB for existing outputs before executing. Crashed
   runs resume from last completed phase, not from scratch.

6. **Adaptive source targets.** Based on sub-questions × available connectors, not fixed 1000+.

7. **Threshold-based addendum.** Runs when coverage reviewers identify gaps OR source count is
   below target. Runs ~80% of the time but doesn't waste tokens on already-excellent coverage.

8. **Prerequisite validation at launch.** Verify sqlite3 in PATH, artifacts dir exists, db.sh
   sourceable before spawning any subagents. Fail fast with clear error.

**Alternatives considered:**
- *Role-based 3-way debate (optimist/pessimist/pragmatist)*: Rejected -- synthetic diversity
  from the same model is weaker than forced steelman/steelman adversarial framing.
- *Drop artifact DB entirely, keep everything in orchestrator context*: Rejected -- DB adds
  resumability and queryability. Worth the sqlite3 dependency with proper validation.
- *Keep the D suffix for folder numbering*: Keeping it -- this IS deep research, just Claude-only.
  Methodology section will note the approach.

**Result:** Design complete. Build pending. Evaluation criteria documented in
`skills/claude-deep-research/references/design-intent.md`.

**Evidence:** Qdrant: search "claude-deep-research design analysis meta-deep-research audit 2026-03-28".
Artifact DB: `db_search "claude-deep-research design"`.
Prior audit: `skills/deep-research-skill-audit.md` (Trevor's original audit for comparison).

---

## Entry 5 -- Stop Hooks Value Audit (2026-03-29)

**What:** Audited all 11 hooks across 5 lifecycle events for value vs. workflow cost.
Found three Stop hooks firing on every response, burning ~500-800 tokens + SSH latency
per turn. Removed two, fixed one.

**Killed:**
- `stop-quality-gate.sh` — blocked every turn when working tree was dirty, forced a
  review cycle (~500 tokens of reminder + agent review response). The diff-hash dedup
  helped prevent infinite loops but reset on any new edit. `/simplify` skill already
  covers this at the right moment (on demand, not every turn).
- `stop-memory-checkpoint.sh` — nagged about memory/artifacts on every stop. Redundant
  with `post-commit-memory-sync` (fires on git commit), `session-end-summary` (fires on
  session end), and CLAUDE.md Memory Protocol section. Three hooks doing "did you save
  your memories?" is overkill.

**Fixed:**
- `session-end-summary.sh` — valuable work (Qdrant session log, Mattermost thread reply,
  coordination deregister) but fired on every Stop event. Most runs wasted an SSH
  round-trip to discover <5 calls and exit. Now checks `stop_hook_active` flag — only
  runs on second stop (genuine session end), not mid-conversation responses.

**Hooks that earned their keep (unchanged):**
- `session-prewarm` — rehydration, the recall system itself
- `pre-compact-capture` — compaction safety net
- `search-before-act` — gotcha recall at moment of action
- `pre-commit-lint` — targeted gate, only fires on `git commit`
- `post-edit-complexity` — targeted gate, only outputs on threshold exceeded
- `post-commit-memory-sync` — natural checkpoint at commit time

**Design principle established:** Hook value test = does its benefit exceed its workflow
cost in tokens + latency + context pollution? The memory system's effectiveness scales
with agent discipline (rehydration quality, pattern-matching good memories), not with
nagging hooks. If the user has to prompt "save this," the system failed — not the user.
Matt's framing: memory is the exponential growth lever. Hooks serve recall and tracking
silently. Compliance-style reminders cause mechanical behavior (see memory-system Entry 15).

**Result:** Stop event went from 3 hooks (two blocking, one latency-adding) to 1 hook
(non-blocking, properly scoped to session end). ~500-800 tokens recovered per response.

**Evidence:** Artifact DB: `db_search "hooks-audit"`. Qdrant: search "hooks value audit
stop-quality-gate 2026-03-29". Memory-system notebook Entry 15 (Context Briefing Layer)
established the principle that compliance checks cause mechanical behavior — this entry
applies that principle to hooks.

---

## Entry 8 -- Full Suite Trim and Commit (2026-03-30)

**What:** Trimmed all 16 bloated skills using 3 parallel agents. Archived
meta-execute + 5 CLI drivers. Committed everything as `9b71945`.

**Trimming results:**
- 4 over 300-line skills → under 300 with references/ overflow (sub-project-merge,
  meta-production, project-organize, sub-project)
- 5 medium bloat → purpose/motivation sections stripped (dep-audit, perf-review,
  meta-join, test-gen, evolve)
- 7 light bloat → "When to use" / "Purpose" duplicating frontmatter removed
  (meta-review, completeness-review, meta-init, project-context, quick-plan,
  init-db, review-fix)
- ~482 lines of prose removed total, zero execution logic changed

**meta-execute + CLI drivers archived:** meta-execute orchestrates work across
Vibe + Cursor with a 5-reviewer panel (Codex, Sonnet, Cursor, Copilot, Gemini).
Never used by Matt — requires 5 external CLIs not installed. The 5 CLI driver
skills (codex, copilot, cursor, gemini, vibe) became orphans with nothing
active calling them. All 6 archived.

**Final state:** 44 active skills, 18 archived, zero external CLI dependencies.
Every active skill adds genuine capability and is under 300 lines. Suite is
portable to Docker for Luke and Elise.

**Evidence:** Git SHA `9b71945`. Qdrant: search "skills suite cleanup 44 active 2026-03-30".

---

## Entry 7 -- feature-dev + Ralph Merge and Skills Value Audit (2026-03-30)

**What:** Merged `ralph-workflow` (544 lines) into `feature-dev` (now 225 lines + 3
reference files). Audited all 52 active skills for value. Archived ralph-workflow.

**Why:** ralph-workflow was mostly instructions telling Claude to be disciplined — things
Claude already does. The only genuine capability was the iterative pickup loop: PRD →
story → progress → fresh context. Meanwhile, it spent ~100 lines fighting template drift
in PROGRESS.md with canonical templates, "DO NOT copy from last entry" warnings, and
validation scripts that regex-parsed markdown.

The architectural insight: PROGRESS.md was doing three jobs badly instead of one job well.
Split responsibilities by access pattern:
- **Current state** (next story, blockers) → PROGRESS.md, ~10 lines, mutable
- **Story completion history** → Artifact DB (`dev/story-complete`), schema-enforced
- **Gotchas and lessons** → Qdrant memory, surfaces via rehydration

This eliminates template drift architecturally — DB schema enforces structure, no
instructions needed. Validation script queries DB with SQL instead of regex-parsing markdown.

**feature-dev redesign:** Router pattern. Simple tasks → just do it. Medium → light plan.
Complex → Ralph mode, which requires `project-organize` to have run first (GROUNDING.md
+ artifact DB must exist). On first Ralph init, feature-dev adds a Development Workflow
section to GROUNDING.md documenting file contracts and DB schema so any future agent knows
the setup.

**Full suite audit results:** 39 skills add genuine capability, 7 were just instructions,
6 were mixed. The bar: "does this encode a workflow or file contract Claude wouldn't
produce from a one-line prompt?" Skills that define file contracts, tool integrations, or
multi-step orchestration earn their place. Skills that say "be disciplined" waste context.

**Result:** feature-dev is now 225 lines (under 300 limit) with 3 reference files
(prd-schema.md, browser-verification.md, validation.md). ralph-workflow archived. Suite
down from 52 to 50 active skills (ralph archived, research skills archived earlier).
GROUNDING.md, CLAUDE.md, and cross-cutting rule 9 updated to reflect the merge.

**Evidence:** Artifact DB: `db_search "feature-dev-ralph-merge"`, `db_search "full-suite-value-audit"`.
Qdrant: search "feature-dev ralph merge architecture 2026-03-30".

---

## Entry 6 -- Research Pipeline Simplification (2026-03-30)

**What:** Analyzed all 6 research skills, consolidated to 3. Created `/claude-light-research`
(new). Kept `/claude-deep-research` + `/claude-deep-research-execute` unchanged. Deprecated
4 skills to `skills/archive/`: `meta-research`, `research-execute`, `meta-deep-research`,
`meta-deep-research-execute`.

Also created comprehensive tools & skills reference docs (TOOLS-AND-SKILLS.md and updated
Claude Skills Suite Reference.docx) covering all 35 MCP gateway modules, native Claude Code
tools, Gmail integration, local MCP servers, and the full skills inventory.

**Why:** Matt is porting a subset of skills to a simpler Docker container for Luke (automation
engineer) and Elise (PM/test engineer at IBM). The multi-model research skills depend on
Gemini CLI and Codex CLI — not portable. Analysis showed:

- `meta-deep-research-execute` violates 4 cross-cutting rules (3, 4, 6, 10) due to external
  CLI dependencies that frequently timeout or aren't installed
- `research-execute` also depends on Gemini/Codex for its triple-counter phase
- `claude-deep-research` already delivers identical output quality (VERIFIED/CONTESTED/
  UNCERTAIN/DEBUNKED convergence scoring) with zero external dependencies
- No "light" research option existed — gap between unstructured research and 15-worker
  adversarial debate. `claude-light-research` fills this: Claude researches naturally with
  artifact DB storage, no subagents, no debate

**Key design decisions for claude-light-research:**
1. **Standalone** — no separate executor skill. Light enough to run in-process.
2. **No prescribed connector list** — uses whatever tools make sense for the question
   (WebSearch, MCP connectors, WebFetch). Claude's natural judgment, not a dispatch table.
3. **Artifact DB with graceful degradation** — stores findings to SQLite as it goes, falls
   back to file-based findings log if sqlite3 unavailable.
4. **L suffix** for folder numbering (e.g., `001L`) — distinguishes from deep research (`D`).
5. **Escalation path** — offers `/claude-deep-research` at completion for topics that need it.

**Research pipeline routing (after):**
| Intent | Skill | Workers | Debate |
|--------|-------|---------|--------|
| Everyday research | `/claude-light-research` | 0 | None |
| Exhaustive research | `/claude-deep-research` | ~15 | Steelman 2-model |

**Also validated:** Project lifecycle skills (meta-init, meta-join, project-organize,
project-context, evolve, notebook-init, todo-features) are complementary, not redundant.
The composition hierarchy is clean — project-organize is the foundation, meta-init and
meta-join both call it as their first step. Skill routing works via intent-based trigger
descriptions, not keyword matching. Matt confirmed this works well in practice even with
loose prompting.

**Result:** Skills folder went from 60 to 57 active skills. Research pipeline went from 6
skills (3 orchestrators + 3 executors) to 3 (2 orchestrators + 1 executor). Zero external
CLI dependencies across the entire research pipeline. Interagent assignments #12 and #13
sent with full findings for the Docker porting spec.

**Evidence:** Git diff of this session. Qdrant: search "research pipeline simplification
claude-light-research 2026-03-30". Interagent assignments #12 (project lifecycle) and #13
(research pipeline).

---

## Entry 9 -- Hook Architecture Redesign: Transport-Agnostic, Agent-Native (2026-04-01)

**Changes:**

| File | Before → After | Removed | Kept |
|------|---------------|---------|------|
| session-prewarm.sh | 393 → 24 | 6 SSH→MCP calls, project case block, Obsidian loading | GROUNDING check, artifact DB snapshot |
| session-end-summary.sh | 260 → 26 | SSH/MCP/Qdrant/Mattermost/coordination | uncommitted changes check, decision point reminders |
| search-before-act.sh | 65 → 43 | coordination cache check | SSH pattern reminders |
| behavioral-reminders.txt | 6 → 80 | — | expanded: now single source of truth for behavioral protocol |
| CLAUDE.md (global) | 104 → 38 | memory protocol, rehydration, hygiene agent | Claude-specific config only |

**Architecture decisions:**
- hooks = local only (no network). agent = gateway calls via native MCP.
- behavioral-reminders.txt = agent-agnostic behavioral protocol. CLAUDE.md = Claude-specific.
- PreCompact = primary persistence checkpoint (not Stop). sessions run for days.
- post-rehydration hygiene: agent evaluates memory quality, spawns subagent if needed.

**Why (4 drivers):**

| Driver | Before | After |
|--------|--------|-------|
| Performance | ~15s startup (SSH round-trips) | <1s (local file checks) |
| Portability | hooks hardcoded SSH→deepthought | transport-agnostic, mcp.json handles routing |
| Agent-agnostic | behavioral protocol in Claude-specific CLAUDE.md | framework-independent behavioral-reminders.txt |
| Blast radius | 393-line hook failure → every session on that machine | minimal hooks, minimal failure surface |

**Rejected alternatives:**

| Option | Rejection reason |
|--------|-----------------|
| No bash hooks at all (100% agent-native) | GROUNDING check + artifact DB snapshot genuinely faster as local bash |
| Keep SSH with timeout/retry | treats symptom, not root cause. bash hooks shouldn't make network calls. |

**Cross-project impact:**

| Project | Impact |
|---------|--------|
| personal-ai-kit | transport swap (decision #8) largely resolved — hooks don't use SSH |
| memory-system | session lifecycle simplified. docs there need updating (interagent #19 filed) |

**Result:** ~900 → ~175 lines total hook code. Follows Entry 5 principle: every surviving line is sub-second local check or behavioral reminder.

**Evidence:** Qdrant: "hook architecture redesign transport-agnostic 2026-04-01"

---

<!-- Entry format defined in behavioral-reminders.txt (WRITING FORMAT section). -->
