# Deep Research Summary — 002D: Meta-Execute Quality Optimization

**Research Question**: How should a Claude Code skill that orchestrates parallel AI coding workers (Codex + Sonnet subagents + Gemini) be designed to maximize output code quality — specifically: completeness (no truncation/stubs), correctness (no logic gaps), appropriate complexity (no over-engineering), and reliable integration across parallel work units?

**Date**: 2026-03-11
**Protocol**: Multi-model deep research with adversarial debate (2-model: Claude + Gemini; Codex workers failed)
**Sources**: 78 queries | 778 scanned | 208 cited | 61 claims scored

---

## Executive Summary

The evidence converges on a clear hierarchy of leverage: **orchestration design > model selection > prompt engineering**. The single highest-impact finding is that identical models with different orchestration topologies yield 12-23% performance differences (AdaptOrch, 2026). The research identifies 10 design principles with strong evidence, 5 contested tradeoffs requiring design judgment, and 2 debunked assumptions to avoid.

The meta-execute skill should implement: (1) dependency-aware work unit sizing at 50-200 LOC, (2) Best-of-N generation with N=2-3 candidates per unit, (3) git worktree isolation limited to 3-4 parallel workers with zero-mutable-file-sharing as the partition criterion, (4) context-engineered worker prompts under 50k tokens each, and (5) a single critical review pass using Agentic Rubrics rather than multiple broad passes.

---

## Part 1: Work Unit Decomposition (SQ-1)

### Verified Findings
- **The goldilocks zone is 50-200 LOC across 2-5 files** — SWE-bench Pro data indicates ~107 LOC as the median for successful autonomous resolution. Below this, agents miss cross-file side effects; above it, "context rot" and hallucinated API calls increase sharply.
- **Multi-commit features are dramatically harder**: FeatureBench (Zhou et al., 2026) shows Claude 4.5 Opus drops from 74.4% on single-issue SWE-bench to 11% on multi-commit feature tasks. SWE-EVO confirms: 65% on single-issue → 21% on multi-file evolution.
- **OpenHands "Leaf-Node" decomposition** identifies components with the fewest internal dependencies and assigns them to parallel workers. This is the leading production strategy.

### Design Recommendation
Size work units by LOC (50-200) as the primary metric. As a secondary check: if a work unit description mentions changes to shared types, configs, or public APIs, flag it for sequential execution or as a dependency for other units. The orchestrator should scan the project plan for shared-resource keywords, not build a full dependency graph.

### Contested
The dissent that "holistic tasks preserve contextual coherence" is valid for tightly coupled features. Resolution: scope each unit as an **independently verifiable mission** — one that produces at least one new/modified export, can be tested with a self-contained test file, and does not require another in-flight unit to compile.

---

## Part 2: Prompt Engineering for Completeness (SQ-2)

### Verified Findings
- **XML tagging** creates hard semantic boundaries that prevent models from losing thread in large files. Adopted by Anthropic and OpenAI as standard practice.
- **"Lost in the middle" effect is real**: Models ignore buried instructions (Paulsen 2025 MECW study). Place critical instructions at the START and END of prompts, not the middle.
- **Combining prompt techniques is not always additive**: CodePromptEval (Khojah et al., 2024) shows diminishing and sometimes negative returns from stacking techniques.

### Design Recommendation
Use three techniques as the baseline combination:
1. **XML tagging** for structural boundaries (`<task>`, `<context>`, `<output-format>`)
2. **Full-file contract** — require complete file output, never partial
3. **Plan-before-code** — agent lists all intended changes before writing any code

Do NOT add additional prompt techniques unless failure analysis identifies a specific gap. Specify the OUTCOME precisely but leave the REASONING PATH to the model — over-specifying process degrades performance.

### Anti-Pattern
"Magic phrases" like "take a deep breath" or "think step by step" have minimal measured impact on coding tasks specifically. Structural engineering (context curation, output format specification) outperforms linguistic tricks.

---

## Part 3: Acceptance Criteria and Review (SQ-3)

### Verified Findings
- **Agentic Rubrics** (Raghavendra et al., 2026) achieve 54.2% SWE-bench Verified by generating context-grounded checklists from the task description, not from generated code. This avoids anchoring bias.
- **No single LLM dominates all review aspects** (CodeFuse-CR-Bench, 2025). Different models catch different error types.
- **Multiple review passes have diminishing returns**: A single critical pass with a focused rubric outperforms three broad passes. AI reviewers suffer from anchoring bias when the same model writes and reviews.

### Design Recommendation
Implement a **single critical review pass** using the Agentic Rubrics pattern:
1. Generate a rubric FROM the work unit specification (not from the code)
2. Score the generated code against the rubric
3. Use a DIFFERENT context window for review (fresh context, no access to generation reasoning)
4. Verdict: ACCEPT / MINOR_FIX / REJECT based on rubric compliance

Do not implement multiple broad review passes. One deep pass > three shallow passes.

### Anti-Pattern
Having the same model instance that generated code also review it. Context isolation between writer and reviewer is critical — the reviewer must not see the generation reasoning.

---

## Part 4: Multi-Model Orchestration (SQ-4)

### Verified Finding
**"Simple composable patterns > complex frameworks"** — Anthropic's most-cited guidance. Each model handoff introduces latency (1s → 30s for multi-model loops) and token cost compounding.

### Design Recommendation
Minimize model transitions. The role assignment:
- **Claude Opus**: Orchestrator — decomposition, dispatch, final synthesis. Never implements directly.
- **Sonnet subagents**: Primary workers — implementation, test writing, lint fixing. Fast, cheap, parallel.
- **Codex**: Secondary workers — fallback when Sonnet unavailable or for tasks requiring sandbox execution.
- **Gemini**: Research and analysis only — large context window for codebase analysis, log analysis, documentation review. NOT for code generation.

Each model has a **non-overlapping role**. The orchestrator dispatches; workers execute; the reviewer scores. No model does two roles in the same work unit.

### Contested
Whether the synthesis bottleneck (merging outputs from different models) negates small-model cost savings. Resolution: use the SAME model family for all workers in a given work unit to avoid synthesis overhead. Model diversity is for the REVIEW step, not the generation step.

---

## Part 5: Parallel Execution and Merge Strategy (SQ-5)

### Verified Findings
- **CooperBench "curse of coordination"**: Frontier models achieve only 25% success when collaborating (vs 55% solo) — a 30% penalty (Khatua et al., 2026).
- **3-4 active worktrees is the practical ceiling**: Boris Cherny (Anthropic) and practitioner reports converge on this limit. Beyond it, filesystem overhead and cognitive load for the orchestrator increase sharply.
- **Sequential rebase strategy**: Merge the lead agent's work first, then rebase parallel branches. Each subsequent merge has updated repository context.
- **<3 merge conflicts over weeks** with proper partitioning (practitioner reports).

### Design Recommendation
Partition work units using this criterion: **parallel when zero mutable files shared; sequential otherwise**. Read-only imports (type definitions) and additive-only files (append to config lists) are safe to share. If the orchestrator cannot determine dependency certainty, default to sequential.

Implementation:
1. 5-slot Codex/Sonnet worker pool (hard cap from Codex concurrent session limit)
2. 3-4 active git worktrees maximum
3. File-level assignment: each mutable file is "owned" by exactly one worker
4. Sequential rebase merge: merge workers in dependency order, not all-at-once
5. AI Integrator Agent for trivial conflicts (shared list entries, import additions)

### Contested
Whether sequential is faster for complex features (Gemini dissent). Resolution: it depends on dependency certainty. The orchestrator must make this determination per work unit, not adopt a blanket policy.

---

## Part 6: Scope Creep Handling (SQ-6)

### Verified Finding
- **SEMAP protocol-driven messaging reduces failures 69.6%** (Mao et al., 2025) — structured behavioral contracts between agents prevent cascading misunderstandings.

### Design Recommendation
Two-tier response based on blast radius:
- **Low blast radius** (missing utility function, undefined helper): Assume and continue. Add TODO comment with clear interface signature. Report in work unit output.
- **High blast radius** (missing service, schema change, security decision, new external dependency): Block and report. Return to orchestrator for re-planning.

The 85% confidence threshold is a useful heuristic: if the worker's self-assessed confidence drops below this, it should pause and request clarification rather than guess.

---

## Part 7: Retry and Escalation (SQ-7)

### Verified Findings
- **Self-repair is bottlenecked by FEEDBACK quality, not model capability** (Olausson et al., 2023, 72 citations). A more capable model providing feedback to a less capable generator outperforms self-repair.
- **First-attempt quality is often the ceiling for reasoning failures**: Retries fix syntax errors but rarely fix fundamental logic errors.
- **Failure classification** (transient vs permanent) is the consensus pattern.

### Design Recommendation
1. **Transient errors** (syntax, import, type errors): Retry with error output appended to context. Max 3 retries.
2. **Permanent errors** (logic gaps, architectural misunderstanding): Do NOT retry. Escalate to a more capable model (Sonnet → Opus) or to human review.
3. **Best-of-N for initial generation**: Generate 2-3 candidates per work unit, select best via quick verification (lint + type-check). This is SUPERIOR to sequential retry for catching logic errors.
4. **Feedback from stronger model**: Opus reviews Sonnet code. Never have the same model instance provide its own feedback.

### Anti-Pattern
Retry loops that spend 5-10x more tokens trying to fix a fundamentally flawed approach. If the first attempt fails on LOGIC (not syntax), generate a fresh attempt with a different approach rather than iterating on the broken one.

---

## Part 8: Context Passing to Workers (SQ-8)

### Verified Findings
- **Context files can REDUCE success** (AGENTS.md study, Gloaguen et al., 2026) — the most counterintuitive verified finding in this research. Adding more context is not always better; irrelevant context actively degrades output.
- **23-54% token reduction possible with minimal performance impact** (SWE-Pruner, Wang et al., 2026) — task-aware adaptive pruning.
- **Chain of Agents**: Short contexts per worker outperform full-context approaches by up to 10% (Zhang et al., 2024, 131 citations).

### Design Recommendation
Each worker receives a **curated context package** of 10k-50k tokens containing:
1. The work unit specification (what to build, acceptance criteria)
2. File contents for ONLY the files being modified (not the entire codebase)
3. Interface signatures for directly imported modules (not their implementations)
4. Relevant type definitions and constants
5. Project conventions (from CLAUDE.md / coding standards — keep under 2k tokens)

Do NOT include: full codebase dumps, all project documentation, change history, or other workers' specifications.

### Anti-Pattern
"Context stuffing" — giving workers the entire repository context on the assumption that more information = better output. This triggers "context rot" and the "lost in the middle" effect.

---

## Part 9: Quality Gates (SQ-9)

### Verified Findings
- **Unified diff format reduces lazy coding 3X** compared to search/replace blocks (Aider data, direct measurement).
- **METR study: AI makes experienced developers 19% slower** but they PERCEIVE being 20% faster — "illusory productivity."
- **DORA 2025**: AI is a "mirror and multiplier" — amplifies existing practices. Quality gates only work if the underlying process is sound.

### Design Recommendation
Implement **tiered inline gates** during execution:
1. **Mandatory fast gates** (< 5 seconds): Lint + type-check after each file write. These catch hallucinated imports, wrong types, and syntax errors.
2. **Mandatory slow gates** (< 60 seconds): Unit test execution for the modified files. Agent cannot report success until tests pass.
3. **Batched integration gates** (post-merge): Full test suite run after all work units merge. This catches cross-unit integration issues.

The TDD pattern is the single most effective gate: agents must write a test, execute it, and get a green result before reporting completion.

### Quantified ROI
SonarSource data (primarily human code): 73% more issues caught pre-merge, 71% production bug reduction. These numbers are directional for AI code; the actual improvement may differ but the direction is consistent.

---

## Part 10: Real-World Failure Modes (SQ-10)

### Verified Findings
- **LinearB: 32.7% AI PR acceptance rate** vs 84.4% for human PRs (2026 production data)
- **Devin: 15% success rate** on 20 real-world tasks (Stanford study, 2025)
- **AI is "mirror and multiplier"** (DORA 2025) — amplifies existing quality, does not create it
- **Illusory productivity**: Developers perceive AI making them 20% faster while actually being 19% slower (METR study, 2025)

### Failure Mode Classification for Meta-Execute

| Failure Mode | Frequency | Detection | Mitigation |
|---|---|---|---|
| **Truncation/stubs** | Common | Grep for `// ...`, `TODO`, `implement later` | Full-file contract + stub detection pass |
| **Over-engineering** | Common | Rubric check: "is every abstraction used by 2+ callers?" | Specify "minimal implementation" in work unit |
| **Logic drift** | Subtle | Tests pass but architectural flaws accumulate | Agentic Rubrics check against spec, not just tests |
| **Ghost debugging** | Intermittent | Same prompt → different results across runs | Best-of-N generation; verify N candidates |
| **Technical dead-ends** | Expensive | Agent pursues impossible approaches for extended time | 3-strike circuit breaker; budget cap per work unit |
| **Hallucinated APIs** | Common in large codebases | Type-check + import resolution | Provide only real interfaces in context |
| **Cross-unit integration failures** | Post-merge | Build breaks after merging parallel work | Sequential rebase; integration test suite |

---

## Part 11: Anthropic Official Guidance (SQ-11)

### Verified (all from official Anthropic documentation)
1. **Explore → Plan → Code → Validate** is the canonical agent cycle
2. **CLAUDE.md** is "context infrastructure" — a project is not agent-ready without it
3. **Two-agent harness**: Outer agent manages context and orchestration; inner agent executes with clean minimal context
4. **Surgical updates** over large-scale rewrites, verified by new test cases
5. **Bash as universal adapter**: Favored for tool design due to autonomous multi-step workflow capability
6. **Simple composable patterns** over complex frameworks

---

## Part 12: SWE-bench Orchestration Methodology (SQ-12)

### Verified Findings
- **AdaptOrch (Yu, 2026)**: Topology-aware orchestration achieves 12-23% improvement over static baselines with IDENTICAL models
- **ISO-Bench (2026)**: "Scaffolding is as important as the model" — agents with identical models differ substantially based on their environment
- **Live-SWE-agent (2026)**: 75.4% SWE-bench Verified WITHOUT test-time scaling — pure orchestration improvement

### Key Insight
Orchestration and scaffolding are DIFFERENT high-leverage investments that compound:
- **Scaffolding** = tools, environment, file access patterns provided to each agent
- **Orchestration** = how multiple agents are coordinated, dispatched, and merged

Both should be optimized. The meta-execute skill is primarily an orchestration investment; the worker prompt template is a scaffolding investment.

---

## Part 13: Test-Time Scaling (SQ-13)

### Verified Findings
- **SWE-Master TTS@8 = 70.8%** — highest reported SWE-bench Verified score (Song et al., 2026)
- **S* framework**: A 3B verification model outperforms GPT-4o-mini by generating "distinguishing inputs" that break logic ties between candidates
- **ST-BoN (self-truncation)**: Reduces compute by 40% with <1% quality loss by pruning obviously wrong candidates early

### Design Recommendation
For the 5-slot worker pool:
- Generate **2-3 candidates** per work unit (not 8-16; engineering-scale units are too expensive for high N)
- Select best candidate via **quick verification**: lint + type-check + unit test execution
- If all candidates fail verification, generate a **fresh attempt with different approach** (not retry-on-failure)
- The verification step should use **pairwise comparison** (V_1 pattern) when automated tests are not available

This is the single highest-leverage change: spending compute on generation diversity (2-3 candidates) rather than sequential retry (same approach, more attempts).

---

## Part 14: Context Engineering (SQ-14)

### Verified
**Context engineering > prompt engineering** is the 2025-2026 paradigm shift (Fowler, Anthropic, Bhatti).

Context = the full information environment provided to the model:
- System prompt
- Retrieved documents/code
- Tool definitions and results
- Conversation/execution history
- Memory/state from previous interactions

Each component needs **independent optimization**. The Anthropic two-agent harness embodies this: the outer agent curates context; the inner agent consumes it. The meta-execute orchestrator IS the outer agent.

---

## Part 15: Agentless vs Agent Tradeoffs (SQ-15)

### Verified Findings
- **Agentless (Xia et al., 2024, 207 citations)**: 32% SWE-bench Lite at $0.70/issue — 10x cheaper than agent approaches
- **Hybrid approach** (agentless first, agent on failure) is the emerging consensus
- **Kimi-Dev**: Uses agentless traces as training data for agents — "skill prior"

### Design Recommendation
For the meta-execute skill, implement a **two-pass strategy**:
1. **Pass 1 (agentless-style)**: Simple localize → generate fix → verify. Fast, cheap, catches the "easy 30-40%."
2. **Pass 2 (agent-style)**: For work units that fail Pass 1, dispatch a full Codex/Sonnet agent with exploration capabilities.

This mirrors the Kimi-Dev insight: most work units are simpler than they appear and can be resolved without full agent scaffolding.

---

## Debunked Claims (Do NOT Design For These)

1. **"90% improvement from sub-agent forking"** — No verifiable published source. The PRINCIPLE (focused context > full context) is correct; the specific magnitude is marketing.
2. **"Cross-file interfaces touched" as primary sizing metric** — Requires static analysis tooling most projects lack. LOC is the practical primary metric.

---

## Contested Tradeoffs (Design Decisions, Not Research Questions)

| # | Tradeoff | Resolution for Meta-Execute |
|---|----------|----------------------------|
| 1 | Over-specification hurts vs helps | Specify OUTCOME precisely, leave REASONING to model |
| 2 | Multi-model synthesis bottleneck | Use same model family for all workers per unit; model diversity for review only |
| 3 | Sequential vs parallel for complex features | Parallel when zero mutable file sharing; sequential when dependencies uncertain |
| 4 | Blocking cost vs wrong-assumption cost | Low blast radius = assume; high blast radius = block |
| 5 | BoN at engineering scale | N=2-3 is practical; N=8+ is not cost-effective for work-unit-sized tasks |

---

## Meta-Execute Design Principles (Ordered by Evidence Strength)

1. **Orchestration topology is the highest-leverage investment** (VERIFIED — AdaptOrch 12-23%, ISO-Bench)
2. **Less context is more** — curate 10k-50k tokens of high-relevance context per worker (VERIFIED — AGENTS.md, SWE-Pruner, Chain of Agents)
3. **Best-of-N generation beats sequential retry** — generate 2-3 candidates, select best (VERIFIED — SWE-Master, S* framework)
4. **Simple composable patterns over complex frameworks** (VERIFIED — Anthropic official)
5. **One critical review pass > three broad passes** — use Agentic Rubrics (VERIFIED — Raghavendra et al.)
6. **Feedback quality > model capability for repair** — Opus feedback on Sonnet code (VERIFIED — Olausson et al.)
7. **Size work units at 50-200 LOC, 2-5 files** (HIGH — SWE-bench Pro, FeatureBench, SWE-EVO)
8. **3-4 active worktrees maximum with sequential rebase** (HIGH — Anthropic, practitioners)
9. **TDD-locked agents: no "done" without green tests** (HIGH — practitioner consensus, SonarSource data)
10. **Failure classification: transient → retry, permanent → escalate** (VERIFIED — multiple sources)

---

## Source Methodology

| Track | Model | Queries | Scanned | Cited |
|---|---|---|---|---|
| A — Deep Reasoning | Opus 4.6 | 12 | 85 | 38 |
| B — Connector Sweep | Sonnet + MCP | 27 | 286 | 73 |
| B+ — Addendum | Sonnet + MCP | 16 | 294 | 45 |
| C — Technical Validation | Codex | 0 | 0 | 0 |
| D — Web Grounding | Gemini (2 instances) | 23 | 113 | 52 |
| **TOTAL** | | **78** | **778** | **208** |

**Track C Failure**: All 4 Codex workers produced 0 output due to `codex exec --sandbox read-only` suppressing stdout without project directory context. Findings redistributed to Tracks A and D.

**Debate**: 2-model (Claude + Gemini), 3 rounds. 7 challenges per direction. Claude conceded 4, Gemini conceded 3. All concessions refined positions rather than reversing them.

**Convergence**: 27 VERIFIED, 22 HIGH, 5 CONTESTED, 5 UNCERTAIN, 2 DEBUNKED, 0 UNRESOLVED (61 total claims scored).

---

## Key References (Most-Cited in This Research)

1. Chen et al. (2023) "Self-Debugging" — 863 citations — self-repair fundamentals
2. Wang et al. (2023) "Survey on LLM Autonomous Agents" — 1904 citations — comprehensive survey
3. Xia et al. (2024) "Agentless" — 207 citations — simple pipeline baseline
4. Zhang et al. (2024) "Chain of Agents" — 131 citations — focused context
5. Hong et al. (2024) "Data Interpreter" — 130 citations — hierarchical decomposition
6. Fourney et al. (2024) "Magentic-One" — 109 citations — orchestrator pattern
7. Olausson et al. (2023) "Demystifying GPT Self-Repair" — 72 citations — feedback quality
8. Song et al. (2026) "SWE-Master" — TTS@8 = 70.8% SWE-bench
9. Yu (2026) "AdaptOrch" — topology-aware orchestration 12-23% improvement
10. Khatua et al. (2026) "CooperBench" — curse of coordination (30% penalty)
11. Zhou et al. (2026) "FeatureBench" — multi-commit feature difficulty gap
12. Gloaguen et al. (2026) "AGENTS.md study" — context files reduce success
13. Raghavendra et al. (2026) "Agentic Rubrics" — 54.2% SWE-bench without tests
14. Wang et al. (2026) "SWE-Pruner" — 23-54% token reduction
15. METR (2025) — AI illusory productivity study
16. DORA (2025) — "mirror and multiplier" stability paradox
17. Mao et al. (2025) "SEMAP" — 69.6% failure reduction via behavioral contracts
