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

## Entry 10 -- Session-Start Memory Hygiene: 5 Prompt Iterations to Compliance (2026-04-01)

date=2026-04-01
type=experiment

**Changes:**
| What | Before → After | Detail |
|------|---------------|--------|
| behavioral-reminders.txt step 3 | "Evaluate rehydration results: if stale AND >24h, spawn background subagent" → "VITAL IMPOTANCE - you will want to do the task right away but please FIX THE inconsistencies..." | 5 iterations to reach compliance |
| Obsidian Memory System Overview | Old gated hygiene agent section → Two-step verify+fix model | Lines 582-604 rewritten |
| Qdrant memories | 2 stale hygiene-agent memories superseded | 5ff110cb, 57c3740f → superseded by 22d0ced4 |
| HYGIENE AGENT section | Standalone trigger → "triggered by step 3 when issues found" | Subagent now reference material, not primary mechanism |

**Decisions:**
| Decision | Alternatives rejected | Reason |
|----------|----------------------|--------|
| Preemptive metacognition ("you will want to skip this") | Action verbs alone, key=value format, caps emphasis, BLOCKING/MANDATORY gates, output format requirements | All structural/format approaches failed 4 times. Naming the bias before the agent experiences it was the only thing that worked. |
| Remove "clean" option from report | Allow "Memory check: clean" | "Clean" was path of least resistance — agents reported clean without actually checking |
| Keep step inline, no subagent threshold | Spawn subagent if ≥3 issues | Subagent spawn was itself skippable. Inline fix with no escape hatch is simpler. |

**Why:**
| Driver | Before | After |
|--------|--------|-------|
| Agent compliance | 0% (skipped by every agent across 4 attempts) | 100% on attempt 5 — found 5 real issues, fixed them |
| Competing priorities | "Be helpful to user" always beat "do housekeeping" | Prompt names the conflict explicitly, grants permission to delay user response |
| Conciseness bias | System prompt says "be terse, get to the point" — actively fought against producing a secondary report | "even if it delays things a minute" neutralizes the speed pressure |

**Impact:**
| Target | Effect |
|--------|--------|
| All projects | Memory quality improves incrementally per session instead of never |
| Future agents | Cold-start agents get accurate memories, not stale claims |
| Prompt engineering knowledge | Documented: action verbs, output format, emphasis escalation all insufficient alone. Preemptive metacognition + explicit permission to be slow = the combination that worked. |

**Experiment log (5 attempts, 2 agents, 1 session):**

| # | Prompt approach | Result | Why it failed/succeeded |
|---|----------------|--------|------------------------|
| 1 | "Evaluate if stale AND >24h → spawn background subagent" | SKIPPED | Compound conditional = 2 escape hatches. "Background" = permission to defer. |
| 2 | Moved to step 3. key=value format (trigger=rehydration_results) | SKIPPED | Position helped but format still descriptive. trigger= reads as metadata. |
| 2b | Added "MEMORY CLEANING IS IMPORTANT FOR FUTURE AGENTS!" | SKIPPED | Caps emphasis ≠ compliance. Agent reads it, understands it, deprioritizes it. |
| 3 | "Fix memory inconsistencies" + output format "Memory check: {clean/N}" | SKIPPED | Action verb was right direction but "clean" was path of least resistance. Agent reported clean without thorough check. |
| 4 | Removed "clean" option. "Memory check: {N issues found}" + "fix all issues" | SKIPPED | Agent admitted: goal fixation, no friction point, comparison is cognitively expensive, conciseness bias. |
| 5 | "you will want to do the task right away but please FIX" + "NOW even if it delays things a minute" | SUCCESS (5 issues found, fixed) | Named the bias before agent experienced it. Granted permission to be slow. Preemptive metacognition. |

**Key findings for prompt engineering:**
- Structural approaches (position, format, action verbs) are necessary but not sufficient
- Emphasis escalation (caps, BLOCKING, MANDATORY) does not work
- Machine format (key=value) is not inherently more effective than prose
- What worked: naming the agent's own bias ("you will want to skip this") + granting explicit permission to override it ("even if it delays things")
- This is preemptive metacognition — making an unconscious optimization visible so the agent can choose differently

**Evidence:** Artifact DB #14 (experiment log). Qdrant: "prompt engineering memory hygiene step3 iterations 2026-04-01". Interagent #20 (initial change notification).

**Why it actually worked — the real lesson:**

The winning prompt was an accident. Matt was typing fast, thinking faster, and what came out was: "VITAL IMPOTANCE - you will want to do the task right away but please FIX THE inconsistencies." Typo, conversational, unpolished. Not what he intended to write. But the meaning landed exactly right.

Every prior attempt was an agent writing instructions for another agent. Clean structure, correct format, proper terminology. The machine processed those as metadata — categorized, weighted, and deprioritized against the user's actual request. A structured instruction like `priority=high | compliance=mandatory` gets filed alongside a hundred other structured instructions. It doesn't stand out.

Matt's accidental prompt works because it doesn't read like a system instruction. It reads like a person who has watched you fail four times and is now talking to you directly: "I know what you're about to do. Please don't." That registers differently than a protocol specification. The typo and conversational tone are features, not bugs — they signal this isn't boilerplate, someone wrote this with feeling because it matters to them.

The four agent-written attempts all tried to solve the problem with better engineering: better format, better position, better structure, louder emphasis. None addressed the actual failure — that an agent in "be helpful" mode will always choose the user's question over background housekeeping. Matt's prompt addresses it by naming that exact choice before the agent makes it, in a voice that sounds like a human who cares about the outcome.

The irony: the file's own format rules say "no filler, no transitions, no preamble" and "agent-consumed files → scan-optimized." The line that finally worked violates every one of those rules. It works because it's human in a file full of machine instructions. It stands out.

---

## Entry 11 -- Symlink Auto-Repair System (2026-04-13)

date=2026-04-13
type=fix

**Changes:**
| What | Before → After | Detail |
|------|----------------|--------|
| scripts/verify-symlinks.sh | n/a → created | Detects + repairs the 5 critical Claude config symlinks. Native Git Bash `test -L` for detection, `mklink` via cmd for repair. ~220ms cold. |
| hooks/session-prewarm.sh | no symlink check → calls verify script | Self-healing at every Claude Code session start. Total prewarm runtime 433ms. |
| scripts/claude-desktop-launcher.bat | n/a → created | Pre-launch repair + starts Desktop via `shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude`. User pins this to taskbar instead of Desktop directly. |

**Decisions:**
| Decision | Alternatives rejected | Reason |
|----------|----------------------|--------|
| `test -L` for detection | `cmd //c fsutil reparsepoint query` | First draft used fsutil via `cmd //c` — quoting trap caused all 5 links to misdetect as broken, destructive branch deleted them. Git Bash has native symlink detection; use it. |
| Hook check + launcher wrapper | Task Scheduler, hardlinks, manual sync script | Covers both entry points (Code, Desktop) without Windows-specific infra. Replicable to Skip and kit machines. Zero-drift property preserved. |
| Safety guard: link path must be inside `$CLAUDE_HOME` or `$CLAUDE_APPDATA` | None — added after the incident | Refuses to delete anything outside known Claude config roots, even if other logic is wrong. Defense in depth. |
| Always exit 0 from verify script | Exit non-zero on failure | Script runs from session-prewarm hook; failing the hook would block session start for a config-layer issue. Log the fact, let the agent decide. |

**Why:**
| Driver | Before | After |
|--------|--------|-------|
| Claude Desktop/Code updates replace symlinks with regular files (atomic write: write-new-file + rename) | Silent break of MCP gateway config, hook paths, skill dir link — user notices only when something visibly fails | Detected + auto-repaired at every session start and every Desktop launch |
| Another agent had fixed the Desktop MCP symptom without understanding the symlink architecture | Fix addressed wrong layer, divergence from skills-suite source of truth would have continued | Investigation-first approach caught root cause; robustness work prevents recurrence |

**Impact:**
| Target | Effect |
|--------|--------|
| dell-xps (primary) | Every Code session self-heals; Desktop launcher covers the non-Code path |
| skip (secondary) | Same scripts apply once Syncthing propagates; same Git Bash + mklink prerequisites |
| personal-ai-kit downstream | Script is parameterized via `$SKILLS_SUITE_DIR`, `$CLAUDE_HOME`, `$CLAUDE_APPDATA`; kit users get the same protection with their own paths |
| Incident recovery | All 5 symlinks were destroyed mid-session by the buggy v1 script; restored manually via `mklink` before proceeding. No data loss — the targets in skills-suite are the source of truth. |

**Lessons:**
- `cmd //c "$cmd_with_backslash_paths"` in Git Bash is a quoting minefield. `test -L` and native bash tools are safer. When cmd is unavoidable, `MSYS_NO_PATHCONV=1 cmd /c` without nested escaped quotes.
- Always test the detection path standalone with a known-good input before letting it drive a destructive branch. A detector that returns "broken" for everything, wired to a "delete + recreate" path, is an atomic self-destruct.
- Symmetric bug: the repair logic had the same quoting bug as the detector, so after deletion, mklink also failed. A single latent bug killed both halves.

**Evidence:**
- Git: commit after this session (hooks/session-prewarm.sh, scripts/verify-symlinks.sh, scripts/claude-desktop-launcher.bat)
- Qdrant: search "symlink auto-repair Claude Desktop Code update gotcha"
- Qdrant: search "cmd //c quoting trap Git Bash fsutil"
- Package family name for Desktop launcher: `Claude_pzs8sxrjxfjjc!Claude` (from `Get-AppxPackage -Name Claude`)

---

## Entry 12 -- Auto-Memory Trap: Hard Block Hook (2026-04-20)

date=2026-04-20
type=fix

**Changes:**
| What | Before → After | Detail |
|------|----------------|--------|
| hooks/block-auto-memory.sh | n/a → created | PreToolUse hook (matcher `Write\|Edit`). Blocks any file write whose path matches `.claude/projects/*/memory/*` via JSON `{"decision":"block",...}`. Node-parsed stdin, path normalized by `tr '\\' '/'` so Windows backslash paths also hit. |
| config/code/settings.json | 2 PreToolUse matchers → 3 | Added `Write\|Edit` matcher pointing at the new hook. |

**Decisions:**
| Decision | Alternatives rejected | Reason |
|----------|----------------------|--------|
| Tool-layer hard block | Louder rule in behavioral-reminders.txt; rely on Qdrant gotcha memory | Soft rules (reminders + memory) kept losing. Harness system prompt's `# auto memory` section gives a full procedural recipe with 4 type examples, when-to-save triggers, and Write+MEMORY.md index steps. A one-line override at line 122 of a hook-injected file cannot compete with that. Physical block is the only layer the harness can't out-instruct. |
| No escape hatch env var | `ALLOW_AUTO_MEMORY=1` bypass | User asked for hard block. If a genuine case emerges (unlikely — Qdrant covers every real memory need), revisit then. |
| Match `Write\|Edit`, not `Write\|Edit\|NotebookEdit` | Include NotebookEdit | Auto-memory section only uses Write. NotebookEdit targets .ipynb cells, not markdown memory files. Overmatching adds noise without safety gain. |
| Node for JSON parsing | python3, jq | Consistent with all other hooks in this repo. python3 on Windows → MS Store stub. jq not always present. |

**Why:**
| Driver | Before | After |
|--------|--------|-------|
| Anthropic harness system prompt injects an `# auto memory` section (4 memory types, Write procedure, MEMORY.md index) that cannot be disabled in settings | Claude Code defaulted to local file writes at `C:\Users\matts\.claude\projects\<slug>\memory\` on user corrections/confirmations, bypassing Qdrant. Gotcha memory existed (Qdrant `c8d578b8`, 2026-04-16) and behavioral-reminders line 122 had a one-line override, but the procedural instruction kept winning. | Tool call physically blocked. Agent must route to `memory_call > store` (Qdrant, findable cross-project). |
| Local memory files are invisible to other projects and other machines | 5 stale local memory dirs accumulated: `C--dev/`, `C--dev-g3-enterprise-patent/`, `C--dev-ql-provisioner/`, `C--dev-quoteforge/`, `C--Users-matts/`. Content never made it to Qdrant. This session (2026-04-20 10:02) also created an empty `C--dev-claude-skills-suite/memory/` — the system was actively trying to use it. | New writes blocked at the hook boundary. Existing stale content flagged as separate cleanup work (not done in this entry). |

**Impact:**
| Target | Effect |
|--------|--------|
| All Claude Code sessions (both machines) | No further local-file memory writes possible. Agent gets block reason in tool result, must pivot to `memory_call > store`. |
| Existing stale local dirs | Not touched. Cleanup is a separate step — decide per-dir whether content is worth migrating to Qdrant or just deletable. |
| personal-ai-kit downstream users | Inherits the block automatically via settings.json in the suite. |
| Legitimate `.claude/projects/*/memory/*` writes | None exist in this protocol. If one emerges, re-evaluate. |

**Lessons:**
- Hook-injected behavioral rules cannot reliably override harness-injected procedural instructions. Salience loses to specificity. When the harness ships explicit step-by-step instructions that conflict with a project protocol, enforcement has to move down to the tool layer.
- Single-liner `tr '\\' '/'` on the extracted path handles both Windows and POSIX forms without a dual-case matcher.
- Test fixture via `Write`-ing a JSON file and piping `cat` is more reliable than trying to inline JSON with backslashes through shell quoting — don't fight the shell when you don't need to.

**Evidence:**
- Git: commit after this session (hooks/block-auto-memory.sh, config/code/settings.json)
- Qdrant: search "auto memory trap Claude Code local memory override qdrant bypass" (existing gotcha `c8d578b8`, 2026-04-16)
- Behavioral-reminders.txt line 122: the soft rule this hook backs up
- Stale dirs still present (to be addressed): `C:\Users\matts\.claude\projects\{C--dev, C--dev-g3-enterprise-patent, C--dev-ql-provisioner, C--dev-quoteforge, C--Users-matts}\memory\`

---

## Entry 13 -- A/B Test: Machine-Code vs Best-Practices Behavioral Reminders (2026-04-20)

date=2026-04-20
type=experiment

**Changes:**
| What | Before → After | Detail |
|------|----------------|--------|
| `config/code/behavioral-reminders.bp.txt` | n/a → created | Full BP rewrite of the behavioral protocol: prose + XML tags (`<role>`, `<memory_consistency_check>`, `<example>`, etc.), positive framing throughout, explicit WHY for each rule, 3 examples in the memory-check block and 4 in disambiguating examples (guide-recommended 3-5 range), scope-explicit language ("audit every rehydrated memory, not a sample"). 272 lines vs 166 for the machine-code variant. |
| `config/code/behavioral-reminders.txt` | machine-code original | Unchanged. Retained as the control variant. |
| `config/code/settings.json` | both hooks cat `behavioral-reminders.txt` | Both SessionStart and PreCompact hooks now cat `behavioral-reminders.bp.txt`. To revert: search-and-replace `.bp.txt` → `.txt`. |
| `config/code/settings.json` | `"effortLevel": "high"` | `"effortLevel": "xhigh"` — matches the 4.7 prompting guide's recommendation for coding/agentic workloads. |

**Decisions:**
| Decision | Alternatives rejected | Reason |
|----------|----------------------|--------|
| Full BP rewrite, not just Step 3 | Rewrite only the SESSION LIFECYCLE step 3 (IMPOTANCE section) with BP style, keep the rest machine-code | Matt's assessment: 4.7 undertriggers on the memory system generally, not just the memory-check step. A full BP rewrite tests whether the style change improves compliance across the protocol, not just one instruction. Scoped-rewrite would leave a style mismatch that might itself suppress compliance. |
| A/B measurement scoped to the memory-check action | Measure adherence to every instruction in the protocol | The memory-check is the one step with baseline compliance data (Notebook Entry 10 — 5-iteration experiment on 4.6). Testing it gives an apples-to-apples signal. Other instructions have no baseline to compare against; broadening the measurement would introduce noise. |
| Lo-fi manual logging | Session-transcript-grep post-session hook | Simplest path to a signal. Matt logs per-session: variant, check_fired (y/n), report_substantive (y/n), real_issues_found (y/n), session_type. Hi-fi hook-based logging is viable if lo-fi results are ambiguous. |
| Keep the machine-code variant as the `.txt` file, BP as `.bp.txt` | Rename machine-code to `.mc.txt`, BP to `.txt`, making BP the default | Minimizes diff churn — reverting is a one-edit operation on `settings.json`. Also keeps the original file name stable for anything that references it externally. |
| Move to `effortLevel: xhigh` concurrently | Stay on `high` to isolate the behavioral-reminders variable | Guide recommends `xhigh` as default for coding/agentic on 4.7. Keeping `high` while testing BP would under-sample 4.7's actual capability. Accept the confound: if compliance improves, it's not attributable to BP alone, but if it doesn't improve, we know the style change isn't enough. |

**Why:**
| Driver | Before | After |
|--------|--------|-------|
| 4.7 is more literal and less responsive to aggressive-language prompting than 4.6 (per prompt engineering guide) | Behavioral protocol tuned for 4.6 via 5-iteration experiment (Entry 10) that landed on "VITAL IMPOTANCE" preemptive metacognition. Worked on 4.6 and 4.7 so far, but the intentional misspelling is fragile — future agents or human editors are likely to "fix" it, losing the effect. | BP variant replaces the hack with normal-prose preemptive metacognition wrapped in `<memory_consistency_check>` XML. Durable because it reads like deliberate guide-aligned prompting, not a typo. |
| Machine-code format (key=value, pipe-delimited, terse bullets) contrasts with the harness's prose-heavy auto-memory section | The harness's procedural "auto memory" block outcompeted the behavioral-reminders' one-line override (specificity beat salience) — exactly the pattern that drove the hook-block in Entry 12. | BP variant matches the harness's register (prose + XML + examples), removing the format-contrast disadvantage. |
| No measurement infrastructure for compliance | Compliance was judged by vibes during the original 5-iteration experiment. That was appropriate for iteration, but continuing to tune by vibes as Claude versions change means we can't tell whether a change is helping or hurting. | A/B with explicit per-session logging creates a signal that can inform future changes. |

**Impact:**
| Target | Effect |
|--------|--------|
| Current session (dell-xps) | BP variant is live as of this commit — next SessionStart will load the BP file. |
| skip machine | Syncthing will propagate `settings.json` and `behavioral-reminders.bp.txt`. No manual intervention needed. |
| Measurement | Starts with the next fresh session on either machine. Log accumulates in a separate notes file (TBD) until enough data to decide. |
| Rollback | One edit: revert `.bp.txt` → `.txt` in `settings.json` (two occurrences, `replace_all` works). |
| personal-ai-kit downstream | Inherits the BP variant via the skills-suite settings. Kit users effectively participate in the A/B; their feedback is data. |

**Test design:**
- Control: `behavioral-reminders.txt` (machine-code, IMPOTANCE). Baseline from Entry 10 experiment.
- Variant: `behavioral-reminders.bp.txt` (full BP rewrite, prose + XML + positive framing + examples).
- Primary metric: memory-check compliance action — does the agent stop after rehydrate and audit, OR does it silently skip / vacuously report "clean" without auditing?
- Per-session log fields: `date`, `machine`, `variant`, `session_type` (short-Q / coding / marathon), `check_fired` (y/n), `report_substantive` (y/n), `real_issues_found` (y/n), `notes`.
- Sample target: ~5 sessions per variant, mixed session types.
- Decision rule:
  - Both fire substantively at similar rates → switch to BP (durability win, no cost).
  - Machine-code fires substantively, BP is vacuous → revert to machine-code, document that IMPOTANCE is load-bearing on 4.7.
  - BP fires more often or catches more real issues → switch to BP (outright win).
  - Mixed/noisy → run more sessions or invest in hi-fi transcript-grep logging.

**Lessons (pre-result):**
- The A/B was reframed mid-session from "test step 3 only" to "test full rewrite." The narrower test would have isolated the IMPOTANCE variable cleanly but assumed the rest of the file wasn't suppressing compliance — an assumption worth checking given 4.7's general undertriggering on the memory system.
- The BP rewrite itself is a forcing function: it surfaces places where the machine-code was vague (e.g. no explicit scope on audit, only one example of a compliant response). Even if BP loses the A/B, the rewrite identified gaps worth fixing in the machine-code version.
- "Context cost of the prompt" turned out to be the wrong frame. The prompt re-injects after PreCompact specifically to drive the agent back to external state; its size is justified by what it unlocks, not what it costs. This reframe matters for future tuning decisions — don't optimize for brevity at the expense of completeness.

**Evidence:**
- Git: commit after this session (config/code/behavioral-reminders.bp.txt, config/code/settings.json, ENGINEERING-NOTEBOOK.md)
- Qdrant: search "IMPOTANCE misspelling intentional behavioral-reminders memory review salience hack" (existing experiment memory `5ba6958e`, 2026-04-01, 5-iteration baseline)
- Prompt engineering guide: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices (fetched 2026-04-20)
- Notebook Entry 10: the 5-iteration experiment that produced IMPOTANCE on 4.6
- Notebook Entry 12: the hook-block that complements this A/B (different failure mode, same underlying concern)

---

## Entry 14 -- Long-Arc Project Structure: Six Load-Bearing Artifacts (2026-04-20)

date=2026-04-20
type=decision

**Changes:**
| What | Before → After | Detail |
|------|----------------|--------|
| Project organization model | Seven parallel layers (local docs + pipeline + Qdrant + Neo4j + Mongo + artifact DB + Obsidian) with no canonical "what are we doing now?" store | Six load-bearing artifacts + narrower role for secondary layers. Plan doc = spine. |
| Pipeline scope | Per-task granularity, duplicated PROGRESS.md content | Project-level metadata + phase transitions only. Cross-project/cross-machine work still uses pipeline tasks. |
| PROGRESS.md role | Canonical active state (duplicated pipeline + plan doc) | Dropped. Active state = plan doc's exit gates + last N notebook entries + recent DB rows. |
| Plan doc role | One of several artifacts referenced from PROGRESS.md | North star. `artifacts/plans/current.md` is the single place "what are we doing now" lives. |

**Decisions:**
| Decision | Alternatives rejected | Reason |
|----------|----------------------|--------|
| Plan doc as spine, versioned with supersede chains | Pipeline as spine; PROGRESS.md as spine | Pipeline isn't diff-able, doesn't render in GitHub, requires MCP call to read. PROGRESS.md becomes a drift target because it mirrors plan + pipeline. Plan doc is already load-bearing in practice (QL-G3-Enterprise) — formalizing it cuts the drift tax. |
| Versioned plan files, not in-place edits | Edit `current.md` in place | Preserves history. When plan pivots (rare but real — see QL-G3-Enterprise cable-competitive → bind-time-cache pivot 2026-04-18), new file + supersession header captures WHY, old plan archived, notebook references stable filenames. |
| Drop PROGRESS.md | Keep as summary render from plan + notebook | No information loss (everything it had is in plan doc + notebook entries + DB). Manual sync cost was real and recurring ("plan scrub" memory 2fbafdfb). |
| Pipeline narrowed, not dropped | Delete pipeline entirely; mandate per-task pipeline tracking | Pipeline's unique value is cross-project aggregation + structured automation triggers + multi-machine view. Per-task use was redundant; project-level + phase-transition use is unique. |
| Six-artifact structure with explicit reading order | Let agents discover what's in each project | Cold-start time was ~30+ min grepping across systems. Explicit reading order gets a fresh agent productive in ~10 min. |

**Why:**
| Driver | Before | After |
|--------|--------|-------|
| Long-arc projects (months, 100+ hours) accumulate multi-layer state | QL-G3-Enterprise had PROGRESS.md + pipeline + plan docs + Qdrant keystones + artifact DB + Obsidian all asserting overlapping state; required manual scrub sessions to keep consistent | Single canonical spine (plan doc), other layers serve distinct non-overlapping roles |
| Fresh agents struggled to orient | 5+ systems to reconcile before understanding current state. PROGRESS.md was trying to be a summary but was stale half the time. | 6-step reading order: GROUNDING → CLAUDE.md → current plan → last 3 notebook entries → GOTCHAS → targeted rehydrate. ~10 min cold-start. |
| Pipeline overhead without pipeline-unique value | Agents wrote pipeline tasks for every bug fix; pipeline was a write-only mirror of PROGRESS.md | Pipeline tasks reserved for cross-project/cross-machine work; in-project work uses local docs + Qdrant + DB |

**Impact:**
| Target | Effect |
|--------|--------|
| QL-G3-Enterprise | Will lose PROGRESS.md (migration to `artifacts/plans/current.md` as canonical pointer). Pipeline Sprint 12 narrowed. |
| New long-arc projects | `/project-organize` (or a new companion skill) scaffolds the six-artifact structure. |
| Behavioral-reminders.txt | New section codifying six-artifact structure + reading order for long-arc projects. |
| Skills suite itself | Dogfood — the suite is a long-arc project; this entry demonstrates the new pattern on the project that just defined it. |
| Cross-machine/cross-project work (#74, #93 class) | Still uses inbox + pipeline tasks; unchanged. |

**Lessons:**
- Observing practice beats prescribing structure. QL-G3-Enterprise's plan-doc-as-spine pattern already worked; the mistake was not formalizing it and letting pipeline + PROGRESS.md continue to compete for the same role.
- "Scatter" and "drift tax" are often the same phenomenon. When multiple stores claim authority over the same state, the cost isn't confusion — it's manual reconciliation work that shows up as meta-sessions ("plan scrub").
- The pipeline is a good tool, just the wrong tool for per-task tracking on a single project. Its value is cross-project visibility, not local backlog management.

**Evidence:**
- Artifact DB record 15 (skill=project-organize, phase=decision, label=long-arc-project-structure-2026-04-20) — full analysis preserved
- QL-G3-Enterprise reference: PROGRESS.md + `artifacts/plans/bind-time-cache-architecture.md` v1.1 + Qdrant keystone memories demonstrate current state
- Qdrant memory `2fbafdfb` (2026-04-17): literal "plan scrub" session reconciling 5 stores — concrete drift-tax artifact
- Qdrant search hint: "long-arc project structure six artifacts plan doc spine"
- Git: commit following this entry, plus follow-up commits migrating QL-G3-Enterprise and updating behavioral-reminders.txt

---

## Entry 15 -- Interagent PUSH: Inbox-Drain Nudge Hook (2026-05-25)

date=2026-05-25
type=feature
status=research-wip
assignment=interagent #115

**What we're building (and why):**
A push-style notification path so two Claude Code sessions on the same machine can
hand each other work WITHOUT Matt manually telling a session "go check interagent."
`interagent` (gateway `send`/`inbox`/`claim`/`complete`) is a durable mailbox but
it is **pull-only** and **keyed by machine, not session** — so both sessions on
dell-xps share one inbox and neither notices new mail on its own. The manual relay
is the whole pain point. The fix is to make the **receiver** auto-drain its inbox.

This is iteration 1 of a research WIP, not a finished system. The deliverable is a
surfacing layer; true idle-reaction (iteration 2) and possible upstream addressing
(iteration 3) are deferred — see roadmap in `hooks/README-interagent-push.md`.

**Key finding that reshaped the design:**
Assignment #115's literal Design A says "a hook calls interagent inbox." That is
**both forbidden and impossible here.** Forbidden: hooks in this suite are
local-only — no SSH/MCP/HTTP (CLAUDE.md guardrail, butterfly-wings blast radius;
Entry 9). Impossible: a shell `command` hook cannot invoke an MCP tool —
`interagent_call` lives in the agent, not the CLI. The established pattern (Entry 9,
and `session-end-summary.sh`'s `action=...` lines) is **the local hook emits a
reminder; the agent makes the MCP call.** `register_session` and the prior
session-start inbox check are likewise *protocol steps the agent runs* (Steps 5/6
of behavioral-reminders), not hook code. So Design A became: **hook nudges (local,
fail-open), agent drains (MCP).**

**Changes:**
| What | Detail |
|------|--------|
| `hooks/interagent-inbox-nudge.sh` (new) | `UserPromptSubmit` hook. Throttled (once/120s per project via a non-synced LOCALAPPDATA timestamp file). Emits an action-reminder to call `inbox` and claim project-tagged mail. Local-only, always exits 0. |
| `config/code/settings.json` → `hooks.UserPromptSubmit` (new) | Wires the hook. Chosen over also adding it to `SessionStart` because Step 5 of the protocol already covers session start; the *new* capability is re-checking on later turns. |
| `config/code/behavioral-reminders.bp.txt` Step 5 (edit) | Added the routing convention; fixed the inbox param (`{from:…}` → `{machine:…}` — `from` is a `send` param). |
| `hooks/README-interagent-push.md` (new) | Design rationale, routing convention, Monitor recipe, roadmap. |

**Routing decision (machine inbox → per session):**
Messages are tagged by **project** in `context_refs` (`{type:"project", id:<key>}`,
key = git-root/cwd basename). Receiver claims only its-project + session-targeted
mail; surfaces untagged broadcasts without claiming; skips other-project mail.
Chosen over (a) per-session addressing baked into the gateway (more capable but
lands in mcp-gateway, deferred to iteration 3) and (b) a redis per-project queue
(extra infra for no current benefit). Project-tag filtering needs zero gateway
change and covers the common case (one session per folder). Same-folder collision
is the known gap — add a `{type:"session", id:…}` ref if it ever arises.

**Why nudge-not-fetch is also the robust choice:**
The hook runs on every prompt; keeping network off it means a slow/down gateway can
never block or error Matt's turn. The throttle keeps an active session from being
nagged. Cost: up to one possibly-empty `inbox` MCP call per 120s of active work, and
the agent must honor the reminder (consistent with how it already honors Step 5 /
deregister / memory-store reminders).

**Deferred (roadmap):**
1. **Idle reaction (iteration 2):** a `Monitor` poller that tails `inbox` ~30s and
   streams new mail in, so an *idle* session reacts with no turn. The poller is the
   clean home for the network call the hook can't make (gateway → local spool → hook
   reads local). Documented as opt-in, not wired on.
2. **Upstream per-session addressing (iteration 3):** only if project-tag routing
   proves too coarse; that work would land in **mcp-gateway**.
3. **Tune throttle (120s is a guess); revisit broadcast claim races.**

**Cross-project impact (butterfly wings):**
Touches the two highest-amplification files — `settings.json` (new hook fires every
prompt, every session, every machine) and `behavioral-reminders.bp.txt` (Step 5).
Hook is fail-open and silent when throttled or empty, so worst case is a stray
reminder line, never a blocked turn.

**Evidence:**
- Hook tested: emits correct machine=dell-xps / project=claude-skills-suite on first
  run, silent on throttled second run; `settings.json` validated as JSON with
  `hooks.UserPromptSubmit` present.
- interagent assignment #115 (claimed by dell-xps 2026-05-25).
- Precedent: Entry 9 (transport-agnostic agent-native hooks), `session-end-summary.sh`.
- Qdrant search hint: "interagent push inbox drain nudge hook per-session routing".

---

## Entry 16 -- Interagent PUSH: Idle-Reaction Monitor + Command Vocabulary (2026-05-25)

date=2026-05-25
type=feature
status=research-wip
assignment=interagent #115
supersedes=Entry 15's "iteration 2 deferred"

**What:** Built iteration 2 (the idle-reaction layer Entry 15 deferred) and locked
the command vocabulary, same session as Entry 15.

- `hooks/interagent-monitor-poll.sh` (new) — poll loop run by the `Monitor` tool
  (`persistent:true`, 30s). Emits one stdout line per NEW pending message routed
  to this session; each line is a chat event that wakes an idle session, which
  then `check`s interagent over MCP to read + claim. Has a `--once` flag for
  testing.
- `behavioral-reminders.bp.txt` Step 5 + `README-interagent-push.md` — recorded the
  vocabulary so every session/machine answers to the same words.

**Command vocabulary (Matt's decision):**
| Matt says | Means |
|-----------|-------|
| **interagent** | the mailbox (noun) |
| **check interagent** | look once, now (one MCP `inbox` pull) |
| **monitor interagent** | arm the persistent poller; react while idle until stopped |
| **stop monitoring** | `TaskStop` the poller |
Matt's reasoning: *check* = a single look, *monitor* = frequency + repetition —
and "monitor" maps 1:1 onto the actual `Monitor` tool, so the word he says is the
mechanism. The `UserPromptSubmit` nudge stays unnamed (automatic plumbing).

**Why the poller may do network when the hook may not:** it is NOT a hook — it's a
Monitor-driven background process — so the local-only hook rule doesn't apply. It
reads the `interagent_assignments` PG table directly over SSH (`ssh deepthought` →
`pgvector`): simplest path, no gateway change. Division of labor mirrors the hook:
poller = lightweight trigger ("there's mail"), agent = drains/claims over MCP.
Project routing + new-vs-seen dedup live in the poller (node filter on the jsonb
`context_refs`; non-synced seen-file per machine+project, so the project string
never enters the SSH/psql quoting).

**Evidence (tested end-to-end, not just asserted):**
- Confirmed table schema over SSH (`context_refs jsonb`, `ttl_hours`, tz timestamps).
- Sent 3 real messages — #116 tagged `claude-skills-suite` (mine), #117 tagged
  `QL-G3-Enterprise` (other), #118 untagged (broadcast). Poller pass 1 emitted
  #116 + #118 and correctly SKIPPED #117; pass 2 emitted nothing (seen-file dedup).
  Test rows deleted (`DELETE 3`, verified count 0); test seen-file cleared.
- Qdrant memory `2eee33f2` updated to iteration 2 + vocabulary.
- Qdrant search hint: "monitor interagent idle reaction poller SSH postgres command vocabulary check monitor".

**Still open:** per-session addressing upstream (mcp-gateway) only if project-tag
routing proves too coarse; tune 120s nudge throttle / 30s poll; seen-file grows
unbounded (prune later); same-folder two-session collision still needs a
`{type:"session"}` ref. #115 remains claimed pending Matt's sign-off.

## Entry 17 -- PROGRESS.md Restored: Seventh Load-Bearing Artifact (2026-07-07)

date=2026-07-07
type=decision
status=shipped
supersedes=Entry 14 (partially — the "drop PROGRESS.md" ruling only)

**What changed:**
PROGRESS.md is back as a sanctioned root file — the seventh load-bearing artifact.
Matt's directive (2026-07-07): GROUNDING.md must stay relatively STATIC (project
goals, where things are, why we're building — what an agent needs to understand
importance and direction). Session-to-session status updates must NOT land there;
they go in PROGRESS.md. Trigger case: an agent (correctly, per the then-current
standard) wrote a dated status-verification block into QL-Support-Portal's
GROUNDING.md, and the mismatch surfaced the gap between the documented standard
and Matt's actual mental model.

**Role separation (the fix for Entry 14's drift problem):**
| File | Time axis |
|------|-----------|
| GROUNDING.md | WHY — timeless |
| PROGRESS.md | NOW — current state, blockers, recent changes |
| artifacts/plans/current.md | NEXT — phases, milestones, exit gates |
| ENGINEERING-NOTEBOOK.md | PAST — journey, superseded thinking |

Entry 14 killed PROGRESS.md because it was "doing three jobs badly" — mirroring
the plan doc and pipeline, going stale, requiring scrub sessions. That diagnosis
was correct; the amputation was wrong. Practice never followed: feature-dev kept
creating its thin PROGRESS.md, rehydrate kept reading it, QL-G3-Enterprise kept
one, and projects grew non-standard aliases (PROJECT-STATUS.md at QL-Support-Portal)
because status content had nowhere sanctioned to live. When the standard bans a
file that practice keeps recreating under other names, the standard is wrong.

**Anti-drift rules carried forward from Entry 14's lesson:**
- PROGRESS.md states WHERE we are; it links to plan-doc phases/exit-gates, never
  duplicates them; never retells notebook entries.
- Every update is dated. Stale sections get corrected or deleted, not appended around.
- CURRENT-STATE.md / STATUS.md / PROJECT-STATUS.md are non-standard aliases —
  merge into PROGRESS.md when touched.

**Files updated:** behavioral-reminders.txt (artifact table now 7 rows, reading
order now 7 steps, "PROGRESS.md is obsolete" section replaced with role
discipline), project-organize/SKILL.md (creates PROGRESS.md for long-arc, template
added as 2.4, ban list + exit conditions + reading order updated, GROUNDING
template's Current State section now a static pointer), hygiene-check invariant 6,
rehydrate artifact table, doc-audit inventory, project-organize
references/type-adaptations.md (CURRENT-STATE -> PROGRESS.md). First project
migrated: QL-Support-Portal (PROJECT-STATUS.md -> PROGRESS.md, dynamic state moved
out of GROUNDING.md).

**Qdrant:** search "PROGRESS.md restored root file standard seventh artifact"

## Entry 18 -- /memory-sleep Skill Built (Sleep Cycle Step 2) (2026-07-08)

date=2026-07-08
type=implementation
status=shipped

**What:** Built `skills/memory-sleep/` — the manual supervised sleep/dream
consolidation pass over the Qdrant memory store. Sleep Cycle build Step 2 of 4
(Step 1 = Sprint 14 gateway prerequisites, shipped earlier today, commit
9f0453f on unraid-mcp-gateway). Spec source: interagent assignment #180 +
`C:\dev\memory-system\artifacts\plans\sleep-cycle-architecture-2026-07-08.md`
(§Interview decisions governs).

**Shape:** SKILL.md (207 lines) + 4 references (worker-prompt, judge-prompt,
report-contract, workflow-skeleton). Pass types light/deep/dream/triage.
Pipeline: Stage 0 mechanical manifest (protected/patent excluded upstream of
any LLM) → ~25-memory batches → read-only worker verdicts
(KEEP/UPDATE/PROMOTE/CONSOLIDATE/ARCHIVE, ground-truth verification mandatory
via hybrid keyword search/git/PROGRESS.md/pipeline) → adversarial judge gate on
destructive verdicts only (TOMBSTONE RULE: existence/closure facts must live in
a keystone before archive) → serial executor (supersede-only, ≤50 actions,
audit row before each write, fail-closed on first bad write).

**Load-bearing choices:**
- DRY-RUN default; `--execute <report-label>` valid only against an approved
  dryrun-report artifact-DB record for the same manifest.
- Report contract: repercussions-first ~20-word bullets ("lose: X; keep: Y"),
  details below as reference only — Matt skims, approves on the first screen.
- Model tiers expressed as roles (worker tier / judge tier), not hardcoded
  names — honors the no-hardcoded-models guardrail while keeping the design
  doc's Opus-worker/Fable-judge economics as stated defaults.
- Judge fails closed: a dead judge agent = all its destructive verdicts REJECTED.
- MCP-required is an explicit, documented exception to the MCP-optional rule
  (the memory store IS the work surface; there is no degraded mode).
- Triage pass consumes the pre-built Stage-0 manifest (101 batches,
  memory-system artifact DB, built same day under interagent #182) with a
  re-verify step since the manifest is a point-in-time snapshot.

**Next:** Step 3 — first supervised dry-run on ONE batch (~25 claude-import
episodics, batch-001), Matt reads the repercussions-first report, calibrate.
Interagent follow-up task sent to dell-xps tagged memory-system.

**Qdrant:** search "memory-sleep skill built sleep cycle step 2"

## Entry 19 -- Session Janitor: Cold-Start Memory Auto-Heal (2026-07-09)

date=2026-07-09
type=implementation
status=shipped

**What:** Session janitor protocol so every capable cold-start agent removes
gunk from the *active memory surface* before user work — without a full
`/memory-sleep` pass.

**Problem:** Targeted memory search was high-signal; broad rehydrate dumped
hygiene noise and left stale high-retrieval memories steering agents. Report-only
hygiene + "fix later" failed for months (Entry 10 compliance pattern; Jul 8
as-you-go rule helped mid-session only).

**Changes:**

| What | Before → After | Detail |
|------|----------------|--------|
| behavioral-reminders.txt + .bp.txt | medium = wait for approval on most findings | SESSION JANITOR: auto-heal tiers + quota 5; stale-vs-pipeline is fix-not-ask |
| `/rehydrate` Step 8 | "Do not auto-fix; use hygiene-check" | Default janitor on; `--no-hygiene` opt-out; overflow in `references/session-janitor.md` |
| session-prewarm.sh | facts only | `action=session_janitor` + one-line reminder (local, no MCP) |
| `/memory-sleep` | no cold-start boundary | Boundary table: janitor vs sleep |

**Auto-heal (no ask):** broken supersede links; clear stale state vs PROGRESS/
pipeline/git; tag import noise `gunk,exclude-from-default`; confirm verified
truths. **Ask/stop:** patent/protected/evolution; true contradictions; delete;
large cluster consolidate → sleep.

**Remove means** supersede + tag out of default steering — not hard-delete.
Aligns with sleep supersede-only.

**Commits:** `80ff47c` (janitor core), polish follows this entry.

**Not done (next):** hygiene-check dual-mode (`--fix`); gateway default-exclude
for `gunk`/imports so tags change retrieval, not just labels.

**Qdrant:** search "session janitor rehydrate auto-heal quota 5"
