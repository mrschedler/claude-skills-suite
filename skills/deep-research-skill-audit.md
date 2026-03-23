# Deep Research Report: Skill Suite Audit

> Date: 2026-03-07
> Models: Opus 4.6 (orchestrator), Sonnet 4.6 (Explore subagent), WebSearch
> Scope: Full audit of 37 skills + 10 agents + research on best practices

## Executive Summary

The suite is well-architected — 37 skills, 10 agents, clear separation between atomic/meta/review/research/infra layers. The 7-lens review system with multi-model fan-out is genuinely best-in-class. But there are real wins to capture:

- **Condense**: `plan` is dead duplicate of `build-plan` (delete). 7 review skills can become thin wrappers. `meta-compact` merges into `meta-clear`.
- **Expand model usage**: Codex used in 3 skills but could add value in 6 more. Gemini underused outside research. Opus subagents should orchestrate meta-review synthesis and meta-execute coordination.
- **Anti-patterns**: Description budget risk (37 skills). No fast-paths for common cases. Skills don't reuse fresh results from prior runs.
- **Missing entirely**: Dependency monitoring, performance profiling, a11y review, postmortem facilitation.

---

## 1. CONDENSE: What to Merge or Delete

### A. Delete `plan` — dead duplicate of `build-plan`
Both do the exact same thing. `plan` wastes a description budget slot. Delete it.

### B. Make 7 review skills thin wrappers
All 7 review skills (counter, security, test, refactor, drift, completeness, compliance) follow identical structure. Keep them as separate skills for auto-invocation accuracy (each has unique trigger words), but make them thin wrappers (3 lines of frontmatter + "Read and execute ../review/lenses/{lens}.md"). Shared logic (output format, severity classification, multi-model dispatch) lives in a parent review config. No duplicated instruction content.

### C. Merge `meta-compact` into `meta-clear`
- `/meta-clear compact` — preserve + compact (current meta-compact)
- `/meta-clear` — preserve + commit + clear (current meta-clear)
Saves 1 description slot.

### D. Consider merging `evolve-context` + `evolve-plan`
- `/evolve context` — just context
- `/evolve plan` — just plan
- `/evolve` — both (current meta-evolve)
Saves 2 slots. Debatable — atomics are clean.

**Net savings: 7-9 description budget slots** (plan + 6 review consolidation + meta-compact, optionally evolve pair)

---

## 2. DESCRIPTION BUDGET — Critical Finding

Skill description budget is **2% of context window** with 16K character fallback. 37 skills × ~200 chars = ~7,400 chars. Within budget now but:
- Every new skill pushes closer to limit
- Long descriptions (meta-deep-research ~400 chars) eat more
- Once exceeded, **skills get silently excluded**

**Action**: Trim all descriptions to ≤150 chars. Consolidate to reclaim slots. Run `/context` periodically.

---

## 3. WHERE TO ADD CODEX (Currently 3 skills, should be 9+)

| Skill | How Codex Adds Value | Workers |
|---|---|---|
| **build-plan** | Generate skeleton files (interfaces, types, module stubs) alongside plan | 1-2 |
| **project-questions** | Scan existing codebase for patterns/tech choices to inform interview | 1 |
| **refactor-review** | Generate actual refactoring diffs, not just recommendations | 1-2 |
| **migration-planner** (agent) | Generate migration scripts (SQL, Alembic, Prisma) alongside plan | 1-2 |
| **release-prep** | Auto-generate changelog from git history + code analysis | 1 |
| **drift-review** | Scan code for undocumented features/endpoints docs don't mention | 1 |

**Pattern**: Read-only for analysis, `--full-auto` only for generation. Never exceed 3 Codex workers in non-meta skills (reserve 2 for meta-execute/meta-deep-research).

---

## 4. WHERE TO ADD GEMINI (Currently 3 skills, should be 7+)

| Skill | How Gemini Adds Value |
|---|---|
| **project-questions** | Research market/competitors/domain BEFORE interviewing — ask better questions |
| **meta-production** | Search for production incidents in project's tech stack |
| **release-prep** | Generate user-facing release notes and marketing copy |
| **build-plan** | Research implementation patterns for chosen tech stack before writing plan |
| **drift-review** | Fact-check tech decisions ("we chose X because Y" — is Y still true?) |
| **skill-doctor** | Research latest Gemini/Codex CLI updates to check if templates outdated |

**Pattern**: Use plain `-p` prompts for research, use `@file` context for code
review, and only force `@codebase_investigator` when the current `/gemini`
driver confirms the environment supports it. Always resolve the absolute path
dynamically.

---

## 5. WHERE OPUS SUBAGENTS MAKE SENSE

Use Opus for orchestration and synthesis, not execution. Receives compressed findings (~5K tokens), does deep reasoning, returns ~2K token summary.

| Skill | Opus Subagent Role | Why Not Sonnet |
|---|---|---|
| **meta-review synthesis** | Integrate 21 review findings, surface cross-lens patterns | Sonnet misses subtle contradictions between lenses |
| **meta-execute orchestration** | Distribute work to 5 Codex workers, handle conflicts | Coordination logic needs deep reasoning |
| **meta-deep-research debate judge** | Score claims after 3 debate rounds | Judging adversarial arguments needs strongest reasoning |
| **meta-production verdict** | Final go/no-go weighing 10 dimensions | High-stakes with nuanced tradeoffs |
| **Complex migrations** | Reason through rollback scenarios and cascading failures | Risk analysis with many interacting variables |

---

## 6. ANTI-PATTERNS WE'RE HITTING

### A. "Bag of Agents" risk in meta-review
21 parallel reviews with no hierarchy can produce "hallucination echo." Fix: Opus synthesis judge breaks this with independent reasoning.

### B. No fast-paths for common cases
- `meta-join` runs 7 steps even for "what changed since yesterday?"
- `meta-init` re-interviews even if `project-context.md` exists
- Fix: Add `--quick` modes

### C. Skills don't reuse each other's fresh results
Run `/security-review` then `/meta-production` = security scan runs twice. Fix: Check for fresh findings (<24h) universally.

### D. No timeout or circuit breaker on subagent chains
If one step hangs, entire chain stalls. Fix: Add max-duration guards to meta-skills.

---

## 7. BEST PRACTICES WE'RE NOT DOING

### A. Progressive disclosure for skill loading
Descriptions should be as short as possible since they're always loaded. Move detail into SKILL.md body.

### B. Stateless subagent design
Every skill should read inputs from files and write outputs to files. No relying on conversation context for state.

### C. Structured error propagation
Every Codex/Gemini invocation should check exit code and write `{worker}_error.md` on failure. Synthesis steps should list which workers failed.

### D. Max iteration guards
`meta-evolve` has optional research loop that could theoretically recurse. Add "max research iterations: 1" guard.

---

## 8. PROPOSED STRUCTURE v2

After consolidation: **37 → 28 skills** (9 fewer description slots)

```
skills/
  # Driver (2): codex, gemini
  # Lifecycle atomic (9): project-scaffold, repo-create, project-questions (+Gemini),
  #   project-context, build-plan (+Codex skeleton), evolve-context, evolve-plan,
  #   release-prep (+Codex+Gemini), todo-features
  # Review (1 parameterized + 7 lens configs + browser-review separate)
  # Research (4): research-plan, research-execute, meta-research, meta-deep-research
  # Meta orchestrators (7): meta-init, meta-join (+quick), meta-evolve,
  #   meta-execute (+Opus), meta-review (+Opus synthesis), meta-production (+Opus+Gemini),
  #   meta-clear (absorbs meta-compact)
  # Infra (4): deploy-gateway, infra-health, skill-doctor, sync-skills
  # Config (2): sync-config, github-sync
```

---

## 9. PRIORITY ACTION ITEMS

| Priority | Action | Impact |
|---|---|---|
| P0 | Delete `plan` skill (duplicate of build-plan) | Reclaim 1 slot, remove confusion |
| P0 | Make 7 review skills thin wrappers with shared logic | Reduce duplication, no slot change but cleaner |
| P0 | Trim all skill descriptions to ≤150 chars | Prevent silent skill exclusion |
| P1 | Merge meta-compact into meta-clear | Reclaim 1 slot |
| P1 | Add Opus subagent for meta-review synthesis | Better cross-lens pattern detection |
| P1 | Add fresh-findings reuse to all review skills | Stop duplicate scans |
| P1 | Add Gemini to project-questions | Better interview from domain research |
| P2 | Add Codex to build-plan (skeleton generation) | Head start on implementation |
| P2 | Add `--quick` mode to meta-join | Fast catch-ups |
| P2 | Add timeout guards to meta-skill chains | Prevent infinite stalls |
| P3 | Add Gemini to release-prep and meta-production | Competitive context, marketing copy |
| P3 | Add Codex to drift-review | Find undocumented code features |

---

## 10. GAPS (Skills That Should Exist But Don't)

1. **Dependency audit automation** — scheduled `npm audit`/`cargo audit` with Mattermost alerts
2. **Performance profiling** — CPU/memory profiling, flame graphs, bottleneck identification
3. **Documentation audit** — verifies README, API docs, arch docs are current vs code
4. **Accessibility review (a11y)** — WCAG, keyboard nav, screen reader for UI projects
5. **Load/stress testing** — benchmarks under simulated load, capacity planning
6. **Breaking change detection** — diffs versions for API contract, db schema, import changes
7. **Incident postmortem** — structured postmortem capture, timeline, root cause, prevention

---

## Sources

- [Composable AI Agents — Architecture & Patterns](https://www.sparkouttech.com/how-to-build-composable-ai-agents/)
- [Why Multi-Agent Systems Fail: The 17x Error Trap](https://towardsdatascience.com/why-your-multi-agent-system-is-failing-escaping-the-17x-error-trap-of-the-bag-of-agents/)
- [Anthropic: How We Built Our Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Why Do Multi-Agent LLM Systems Fail? (arxiv)](https://arxiv.org/html/2503.13657v1)
- [Azure AI Agent Orchestration Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)
- [Subagents: Solving the Context Window Problem](https://selfservicebi.co.uk/series/context-window-optimization/subagents-how-delegating-work-solves-the-context-window-problem/)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Agents 2.0: From Shallow Loops to Deep Agents](https://www.philschmid.de/agents-2.0-deep-agents)
- [AI Agent Skills Complete Guide 2026](https://calmops.com/ai/ai-agent-skills-complete-guide-2026/)

---

## COMPLETE SKILL INVENTORY (37 skills + 10 agents)

### Skills by Type
- **Atomic (22)**: build-plan, browser-review, codex, completeness-review, compliance-review, counter-review, deploy-gateway, drift-review, evolve-context, evolve-plan, gemini, github-sync, infra-health, plan, project-context, project-questions, project-scaffold, refactor-review, release-prep, repo-create, security-review, test-review
- **Research (4)**: meta-research, research-plan, research-execute, meta-deep-research
- **Meta (8)**: meta-clear, meta-compact, meta-evolve, meta-execute, meta-init, meta-join, meta-production, meta-review
- **Config (3)**: skill-doctor, sync-config, sync-skills

### Agents (10)
- api-tester (Sonnet), backup-runner (Haiku), code-archaeologist (Sonnet), compact-reviewer (Sonnet), db-admin (Sonnet), infra-debugger (Opus), log-analyst (Sonnet), migration-planner (Sonnet), research-connector (Sonnet), review-lens (Sonnet)
