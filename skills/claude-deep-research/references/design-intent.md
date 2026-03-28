# claude-deep-research — Design Intent

Created: 2026-03-28
Origin: Analysis of meta-deep-research + meta-deep-research-execute (Trevor Byrum's original)

This document captures the design intent so results can be evaluated against it.
It is NOT instructions for the skill — see SKILL.md for that.

## Problem Statement

The existing `meta-deep-research` skill orchestrates ~20 workers across 3 model families
(Claude, Codex/GPT, Gemini) for adversarial deep research. In practice:
- External CLIs (Codex, Gemini) are frequently unavailable, timed out, or unconfigured
- The "full protocol" has likely never executed as written across 7+ runs
- ~40% of instruction tokens describe tracks that rarely execute
- The skill violates 4 of 10 cross-cutting rules (3, 4, 6, 10)

## Design Goal

Same research rigor, zero external dependencies. All research through Claude subagents
via the Agent tool. Works at 100% capacity on any machine with Claude Code + MCP Gateway.

## Architecture: What Changed and Why

### Orchestrator Owns All DB Writes (was: subagents write directly)

**Why:** Subagents writing to SQLite created a fragile dependency chain:
- sqlite3 must be in PATH (not guaranteed on Windows without explicit export)
- `git rev-parse` must succeed (requires being in a git repo with correct cwd)
- No WAL mode or busy_timeout = race conditions with parallel writers
- Content passed through shell variables risks argument length limits

**New pattern:** Subagents return structured findings in their Agent tool response.
The orchestrator collects all results and batch-writes to the DB. Single writer = no
races, no PATH issues in subagents, no shell escaping.

**Evaluation criterion:** Zero DB write failures across runs. All intermediate
artifacts queryable in artifact DB after completion.

### Steelman/Steelman Debate (was: 3-model debate)

**Why:** Three Claude instances debating share identical training data, knowledge
cutoffs, and systematic biases. The original skill itself calls this "self-consistency"
in its fallback language. The 3-round, 3-participant protocol (9 debate documents) is
expensive for what amounts to checking if Claude agrees with itself.

**New pattern:** Two focused adversarial subagents:
- **Advocate**: Builds the strongest possible case FOR the emerging consensus
- **Challenger**: Builds the strongest possible case AGAINST (with fresh web research)
- **Orchestrator**: Judges each claim as VERIFIED/CONTESTED/UNCERTAIN using the
  same convergence scoring matrix

Source diversity (different MCP connectors finding different evidence) provides more
genuine epistemic diversity than model diversity within Claude.

**Evaluation criteria:**
- Contested claims are identified (non-zero contested count per run)
- Debate produces actionable disagreements, not rubber-stamp agreement
- Total debate cost is <40% of original (3 docs vs 9)

### Lean Instructions (was: 1,019 lines)

**Why:** The orchestrator subagent consumed ~7.5% of its context on instructions
before doing any research. More instruction = less room for actual findings.

**Target:** 200-300 lines total (SKILL.md + protocol reference combined).

**Evaluation criterion:** Orchestrator instruction payload under 5% of context.

### Progress Tracking (was: black box)

**Why:** Users waited 15-50 minutes with zero visibility into what was happening.

**New pattern:** Orchestrator updates `artifacts/research/{NNN}D/progress.md` after
each phase. Dispatcher can poll and report.

**Evaluation criterion:** User can see which phase is running at any point during execution.

### Checkpoint/Resume (was: crash = full restart)

**Why:** If the orchestrator crashed at Phase 3, all Phase 1-2 work in the DB was
wasted. No way to pick up where it left off.

**New pattern:** Each phase checks the artifact DB for existing outputs before
executing. If Phase 2 findings already exist, skip to coverage expansion.

**Evaluation criterion:** A resumed run completes in <50% of the time of a fresh run.

### Adaptive Source Targets (was: fixed 1000+)

**Why:** Only 1 of 4 examined runs hit the 1000+ target. The fixed target creates
pressure to inflate numbers rather than focus on quality.

**New formula:** `sub_questions × available_connectors × 3 queries × 20 results`.
Report actual vs expected rather than actual vs arbitrary threshold.

**Evaluation criterion:** Source target is realistic — hit in >70% of runs.

### Threshold-Based Addendum (was: mandatory always)

**Why:** "ALWAYS runs" burns tokens even when coverage is excellent. No circuit breaker.

**New trigger:** Coverage reviewers identify >2 thin areas OR source count is below
adaptive target OR reviewers identify emergent topics worth pursuing.

**Evaluation criterion:** Addendum runs ~80% of the time but skips cleanly when
coverage is already thorough.

## What's Preserved Unchanged

- **Output format**: Executive summary, confidence map, detailed findings per
  sub-question, contested findings, open questions, debunked claims, source index
- **Artifact DB storage**: skill/phase/label key scheme, FTS5 search, db.sh helper
- **research-connector agent**: Multi-query protocol (3-5 variations), source counting,
  structured output — shared with regular research-execute skill
- **Coverage expansion concept**: Reviewers identify gaps, addendum fills them
- **Convergence scoring matrix**: VERIFIED / HIGH / CONTESTED / UNCERTAIN / DEBUNKED / UNRESOLVED
- **Context isolation**: Dispatcher stays lean, all heavy work in one subagent
- **Descriptive file naming**: `websocket-scaling-limits.md` not `worker-1.md`
- **Folder numbering**: Shares sequence with regular research, uses `D` suffix

## Evaluation Framework

After 3+ runs, evaluate:

| Dimension | Target | How to Measure |
|---|---|---|
| Completion rate | 100% (no crashes) | Did every run produce a summary? |
| Quality vs original | >= meta-deep-research | Side-by-side on same topic |
| Source targets hit | >70% of runs | Actual vs adaptive target |
| Contested claims found | >0 per run | Non-zero contested count |
| DB write failures | 0 | Any sqlite errors in output? |
| Wall clock time | <30 minutes typical | Time from dispatch to summary |
| Instruction overhead | <5% of orchestrator context | Line count × ~1.3 tokens/word |
| User visibility | Phase-level updates | Progress file updated per phase? |
| Resume capability | Works on crash recovery | Manually test by interrupting a run |
| Cross-cutting compliance | 0 violations | Audit against all 10 rules |

## Relationship to Other Skills

- **meta-deep-research**: The original. Coexists — use when external CLIs are available
  and multi-model diversity is desired.
- **meta-research**: Lighter research pipeline (plan then execute). claude-deep-research
  is for "leave no stone unturned" questions.
- **research-execute**: Regular research (single-pass, no debate). Shares the
  research-connector agent.
- **feature-dev / ralph-workflow**: Development skills that may invoke research as a
  sub-step. Either research skill can serve this role.
