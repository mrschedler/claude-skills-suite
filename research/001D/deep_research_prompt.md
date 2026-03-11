# Deep Research Prompt — 001D

## Research Question
How to optimize a Claude Code skill suite (37+ skills) for context window efficiency, and design an end-to-end automated sprint workflow with multi-model orchestration (Claude Code + Codex CLI + Gemini CLI).

## Sub-Questions

1. **Skill context mechanics**: How exactly do Claude Code skills consume context window? What is the measured token cost of skill descriptions (system prompt) vs SKILL.md bodies (loaded on invocation)? What happens when the description budget is exceeded — silent exclusion? truncation? What is the actual 2% threshold in tokens?

2. **Skill architecture patterns**: What are the best techniques for progressive disclosure, lazy loading, parameterized skills (one skill with subcommands), and skill grouping to minimize always-loaded context while maintaining discoverability? Compare: thin wrappers with shared logic files, skill inheritance/composition, conditional imports, namespace grouping.

3. **Production skill organization**: How do teams with 30+ skills organize them? What folder structures, naming conventions, and description strategies work at scale? What does Anthropic recommend officially? Are there documented examples of large skill suites in the wild?

4. **Multi-model integration in skills**: What are the proven patterns for embedding Gemini CLI and Codex CLI calls within Claude Code skills? Compare spawn-and-pipe, file-based IPC, slash command routing, MCP bridging, and worktree isolation. What are the failure modes (hangs, zombie processes, output corruption, context blowup) and mitigations for each?

5. **End-to-end sprint state machine**: Can we design a daisy-chained workflow: spec → plan → implement → test → debug → review → deploy? What does the state machine look like? What are the gate conditions between stages? Where do adversarial debates fit? Where do human approval checkpoints go?

6. **Sandboxed execution**: What are the options for running generated code in sandboxed environments during the sprint? Compare: Codex sandbox (read-only vs full-auto), Docker containers, git worktrees, nsjail, ephemeral VMs. What level of isolation is needed at each sprint stage?

7. **Automated rollback and recovery**: When a sprint stage fails (tests fail, review rejects, deploy breaks), what are the best patterns for automated rollback? Git-based (revert commits), container-based (previous image), feature flags, canary deploys?

8. **Context window optimization beyond skills**: What other techniques reduce context consumption — subagent isolation patterns, file-based state passing, context compaction strategies, smart routing to avoid loading unnecessary context? What is the measured impact of each?

9. **Failure modes of automated sprints**: What goes wrong when you chain AI agents end-to-end? Agentic drift, error cascading, semantic conflicts, infinite loops, cost blowups. What are the circuit breakers and safety valves?

10. **Real practitioner examples**: Who is actually running end-to-end automated sprints with multi-model setups? What tools do they use? What's their success rate? What did they learn?

## Scope
- Breadth: exhaustive
- Time horizon: primarily 2025-2026, include foundational patterns from earlier
- Domain: AI-assisted software development, specifically CLI-based coding agents

## Project Context
This is a personal developer productivity suite built as Claude Code skills/agents/hooks. 37 skills, 10 agents, organized in layers (atomic, meta, review, research, infra, config). Uses Claude Code as orchestrator with Gemini CLI (free, 1M context) and Codex CLI (included in ChatGPT Plus) as worker models. Runs on macOS with Tower (Unraid) as infrastructure backend.

Key constraints:
- Skills are loaded as descriptions in system prompt (~2% of context budget)
- SKILL.md body only loaded when invoked
- Subagents get their own context windows
- Gemini must run in read-only mode (safety)
- Codex has 5 concurrent session limit
- Cost optimization is important (Opus for orchestration, Sonnet for execution, Haiku for lookups)

## Known Prior Research
- `deep-research-skill-audit.md`: Full audit of 37 skills, description budget analysis, Codex/Gemini expansion opportunities, anti-patterns, proposed v2 structure (37→28 skills)
- `Multi-agent-cli-orchastration-init.md`: 5 orchestration patterns, benchmark data, cost analysis, failure modes, practitioner reports

DO NOT duplicate findings from these documents. Extend, challenge, or find new evidence that builds on them.

## Output Configuration
- Research folder: research/001D/
- Summary destination: research/summary/001D-skill-sprint-optimization.md
- Topic slug: skill-sprint-optimization

## Special Instructions
- Prioritize practitioner evidence over theory — real people doing this, not hypotheticals
- Challenge the assumption that more skills = better — find evidence for/against skill consolidation
- Look for examples of end-to-end automated sprints that actually worked (or failed spectacularly)
- Find any Anthropic official guidance on skill suite design at scale
- Research whether MCP-based tool routing could replace some skills entirely
- Investigate Claude Code's actual skill loading mechanism — is it truly lazy? What's cached?
- Look for the ICML 2025 paper about CLAUDE.md/AGENTS.md length — verify the 300-word finding
- Find alternatives to the current skill architecture (e.g., plugin systems, dynamic loading, skill registries)
