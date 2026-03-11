# Dispatch Table — 001D Skill Sprint Optimization

## Sub-Questions (refined from prompt)

| # | Sub-Question | Evidence Type | Track A (Opus) | Track B (Sonnet/MCP) | Track C (Codex) | Track D (Gemini) |
|---|---|---|---|---|---|---|
| SQ-1 | How do Claude Code skills consume context? Token cost of descriptions vs SKILL.md bodies, 2% threshold, silent exclusion behavior, caching | Technical | | Context7, GitHub, MS Learn | Primary | Primary |
| SQ-2 | Best skill architecture patterns: progressive disclosure, lazy loading, parameterized skills, namespace grouping, thin wrappers vs monoliths | Technical + Market | | Context7, GitHub, WebSearch | Primary | Primary |
| SQ-3 | Production skill organization at scale (30+ skills): folder structures, naming conventions, Anthropic official guidance, real examples | Market + Technical | | GitHub, WebSearch, MS Learn | Devil's Advocate | Primary |
| SQ-4 | Multi-model integration patterns in skills: spawn-and-pipe, file-based IPC, MCP bridging, worktree isolation. Failure modes and mitigations | Technical + Reasoning | Deep Reasoning | GitHub, Context7 | Primary | Primary |
| SQ-5 | End-to-end sprint state machine: spec->plan->implement->test->debug->review->deploy. Gate conditions, adversarial debates, human checkpoints | Reasoning + Market | Deep Reasoning | WebSearch, Scholar Gateway | Primary | Primary |
| SQ-6 | Sandboxed execution options: Codex sandbox modes, Docker, git worktrees, nsjail, ephemeral VMs. Isolation needs per sprint stage | Technical | | GitHub, Context7, MS Learn | Primary | Primary |
| SQ-7 | Automated rollback and recovery patterns: git revert, container rollback, feature flags, canary deploys for AI-generated code | Technical + Market | | GitHub, WebSearch | Primary | Primary |
| SQ-8 | Context window optimization beyond skills: subagent isolation, file-based state passing, context compaction, smart routing. Measured impact | Reasoning + Technical | Deep Reasoning | Consensus, Scholar Gateway, WebSearch | Devil's Advocate | Primary |
| SQ-9 | Failure modes of automated sprints: agentic drift, error cascading, semantic conflicts, infinite loops, cost blowups. Circuit breakers | Reasoning + Market | | Consensus, Scholar Gateway, WebSearch | Devil's Advocate | Primary (Contradiction) |
| SQ-10 | Real practitioner examples of end-to-end automated sprints with multi-model setups. Tools, success rates, lessons learned | Market | | WebSearch, GitHub | | Primary (Case Studies) |
| SQ-11 | MCP-based tool routing as skill replacement: can MCP servers replace skill files? Dynamic tool registration, routing protocols | Technical | | Context7, GitHub, MS Learn | Primary | |
| SQ-12 | ICML 2025 paper on CLAUDE.md/AGENTS.md length: verify 300-word finding, methodology, applicability to skill descriptions | Academic | | Consensus, Scholar Gateway, HuggingFace | | Primary |

## Worker Allocation

### Track A: Opus Deep Reasoning (2 subagents)
- **Opus-1**: SQ-4 (multi-model integration reasoning) + SQ-5 (sprint state machine design)
- **Opus-2**: SQ-8 (context optimization reasoning)

### Track B: Sonnet Connector Sweep (8 subagents)
- **Context7**: SQ-1 (skill mechanics), SQ-2 (architecture patterns), SQ-4 (MCP bridging), SQ-6 (sandbox), SQ-11 (MCP routing)
- **GitHub**: SQ-2 (skill repos), SQ-3 (production examples), SQ-4 (integration patterns), SQ-6 (worktree tools), SQ-7 (rollback patterns), SQ-11 (MCP servers)
- **WebSearch**: SQ-3 (Anthropic guidance), SQ-5 (sprint workflows), SQ-7 (rollback patterns), SQ-9 (failure modes), SQ-10 (practitioner examples)
- **Scholar Gateway**: SQ-8 (context optimization papers), SQ-9 (multi-agent failure modes)
- **Consensus**: SQ-8 (context optimization research), SQ-9 (multi-agent failure research)
- **MS Learn**: SQ-1 (skill patterns), SQ-6 (sandbox/isolation), SQ-11 (MCP patterns)
- **HuggingFace**: SQ-12 (ICML paper search)
- **WebSearch-2**: SQ-10 (practitioner stories), SQ-12 (ICML paper verification)

### Track C: Codex Technical Validation (5 workers)
- **Codex-1**: SQ-1 (skill context mechanics — verify actual behavior)
- **Codex-2**: SQ-4 (multi-model integration — test actual CLI patterns)
- **Codex-3**: SQ-5 (sprint state machine — validate gate conditions) + SQ-6 (sandbox options — verify)
- **Codex-4 (Devil's Advocate)**: SQ-2 + SQ-3 (challenge skill consolidation assumptions)
- **Codex-5 (Devil's Advocate)**: SQ-8 + SQ-9 (challenge context optimization claims)

### Track D: Gemini Web Grounding (3 instances)
- **Gemini-1 (Primary)**: SQ-1, SQ-2, SQ-3, SQ-4, SQ-6, SQ-7, SQ-11
- **Gemini-2 (Contradiction Hunter)**: SQ-8, SQ-9 (find evidence against conventional wisdom on context optimization and multi-agent safety)
- **Gemini-3 (Case Studies)**: SQ-5, SQ-10, SQ-12 (real sprint implementations, practitioner stories, ICML paper)
