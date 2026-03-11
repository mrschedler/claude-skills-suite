# Deep Research Prompt — 002D

## Research Question
How should a Claude Code skill that orchestrates parallel AI coding workers (Codex + Sonnet subagents + Gemini) be designed to maximize output code quality — specifically: completeness (no truncation/stubs), correctness (no logic gaps), appropriate complexity (no over-engineering), and reliable integration across parallel work units?

## Sub-Questions

1. **Work unit decomposition**: What sizing, scoping, and framing strategies for AI work units produce the highest-quality output? What granularity is too coarse (worker gets lost) vs. too fine (over-specified, can't reason holistically)? What evidence exists from SWE-bench, OpenHands, Devin, Aider, and similar systems?

2. **Worker prompt engineering for completeness**: What prompt patterns reliably elicit complete, non-truncated code from LLM coding agents? What causes truncation ("I'll implement the rest later", "..."), stub generation, and pseudo-code? How do leading systems prevent these? What's the difference between Codex and Sonnet subagent behavior on this?

3. **Acceptance criteria that actually work**: What verification patterns reliably catch over-engineering, gaps, truncation, and logic errors during automated review — not just "does it pass tests"? How do human reviewers mentally model completeness vs. how LLM reviewers model it? What structured rubrics work?

4. **Multi-model orchestration**: How should work be divided across Claude (orchestrator), Codex (worker), Sonnet subagents (fallback workers), and Gemini (at most 2 concurrent)? What are the complementary strengths? When should each be used for generation vs. review vs. verification? What does research show about model specialization in coding tasks?

5. **Parallel execution and merge conflicts**: When multiple workers modify overlapping files simultaneously, what are the best strategies for conflict detection, prevention, and resolution? What approaches do systems like OpenHands, SWE-agent, and git-worktree-based agents use?

6. **Scope creep during implementation**: When a worker discovers new work (missing interfaces, undefined dependencies, architectural gaps) during implementation, what patterns handle this well? When should it block and report vs. make a reasonable assumption and continue?

7. **Retry and escalation strategy**: What retry patterns improve output quality? Is re-running with the same prompt effective? What additional context or constraints should be added on retry? When should the orchestrator escalate to a different model vs. human review?

8. **Context passing to workers**: What's the minimum necessary context a coding worker needs to produce correct, well-integrated code? Too little = disconnected output; too much = context confusion. What do practitioners say about optimal context window usage for coding agents?

9. **Quality gates during execution**: What inline verification steps (linting, type-checking, unit test stubs, import resolution) during execution catch problems early before the full review phase? Is there evidence that earlier feedback loops improve final output quality?

10. **Real-world failure modes**: What are the documented failure patterns of AI-assisted parallel implementation systems? What went wrong in published case studies of Devin, OpenHands, Aider in real codebases? What circuit breakers and safety valves prevent cost/quality spirals?

## Scope
- Breadth: broad (full execution loop + orchestration + worker prompt design)
- Time horizon: primarily 2024-2026, include foundational agentic coding papers
- Domain: AI-assisted software development, multi-agent coding systems, LLM code generation quality

## Project Context

This is a personal Claude Code skill suite. The `meta-execute` skill:
- Reads a `project-plan.md` with work units tagged parallel/sequential
- Maintains a 5-slot Codex worker pool (hard cap — Codex has 5 concurrent session limit)
- Falls back to Sonnet subagents if Codex unavailable
- Gemini available for research/analysis tasks (max 2 concurrent)
- Claude is the orchestrator — never implements directly
- Each worker is stateless/ephemeral — all context passed in the prompt
- Review subagent reads worker output and issues ACCEPT/MINOR_FIX/REJECT verdicts
- Retry logic: 3 strikes before flagging for human review
- Workers use `codex exec --full-auto --ephemeral` or Agent tool with Sonnet
- Goal: ship high-quality code with minimal human intervention per work unit

Key quality failure modes observed (limited usage):
- Workers produce plausible-looking but incomplete implementations
- Over-engineered abstractions added when not requested
- Truncated functions with "// implement later" comments
- Review subagent passes code that has subtle gaps (testing the happy path only)

## Known Prior Research
- `artifacts/research/001D/`: skill suite optimization + multi-model sprint workflow + security
- `artifacts/research/summary/001D-agent-security-gaps.md`: security patterns for agentic systems
- `skills/deep-research-skill-audit.md`: structural audit of the skill suite (2026-03-07)
- DO NOT duplicate — extend and challenge these findings

## Output Configuration
- Research folder: artifacts/research/002D/
- Summary destination: artifacts/research/summary/002D-meta-execute-quality.md
- Topic slug: meta-execute-quality

## Special Instructions
- Prioritize practitioner evidence and published benchmarks over theory
- Find research on what actually differentiates high-quality vs. low-quality AI code generation at the prompting/orchestration level — not model capability
- Look for SWE-bench leaderboard methodology — what do top-performing systems do differently at the orchestration level?
- Research Anthropic's own multi-agent guidance for coding agents specifically
- Challenge the assumption that more review passes = better quality — find evidence for/against
- Look for prompt patterns that specifically prevent truncation and stub generation in coding agents
- Find any evidence on optimal work unit size in lines of code, complexity, or scope
- Research whether Gemini 2's large context window provides an advantage for code review vs. Sonnet subagents
- Investigate whether git worktree isolation per worker is worth the overhead vs. sequential merging
