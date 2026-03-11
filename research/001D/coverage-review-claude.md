# Coverage Review — Claude (Opus)

## Thin Areas Needing Reinforcement

1. **SQ-1 (Skill context mechanics)**: Good data from Context7 and Codex on the 2%/16K budget, but we lack precise token measurements. Nobody has published "skill X costs Y tokens." The SLASH_COMMAND_TOOL_CHAR_BUDGET env var override is mentioned but not well-documented.

2. **SQ-5 (Sprint state machine)**: We have general patterns but no rigorous state machine specification with formal gate conditions. The "Superpowers" case study is the closest but lacks implementation detail on adversarial debates within the sprint.

3. **SQ-12 (ICML paper)**: Gemini found the citation (arXiv:2602.11988, ETH Zurich / LogicStar.ai) but we need the actual paper content to verify the "300 words" claim vs "150-200 instructions" claim — these are different measurements.

## Emergent Topics to Research

1. **Agent Skills Open Standard (agentskills.io)**: Major finding — Skills are now a portable open standard adopted by 26+ platforms including OpenAI Codex, Gemini CLI, VS Code Copilot. This changes the skill architecture question fundamentally. Skills aren't just a Claude feature anymore.

2. **Context Cascade / Nested Plugin Architecture**: The DNYoussef/context-cascade plugin claims 90%+ context savings with a 4-level hierarchy (Playbooks->Skills->Agents->Commands). This is a concrete alternative to flat skill organization.

3. **WarpGrep / Search Subagents**: RL-trained search subagents that reduce context rot by 70% — a specific, measured alternative to manual context management that's directly relevant to SQ-8.

4. **Contextune (95% fewer tokens)**: Specific tool for Claude Code context optimization with measured 81% cost reduction. Directly relevant to SQ-8.

5. **MCP Tool Search Auto-Deferral**: MCP tools auto-defer when descriptions exceed 10% of context. This is a different mechanism than the 2% skill budget and creates an interesting interaction.

6. **Claude Code's Hidden TeammateTool**: A fully-implemented multi-agent system hiding in Claude Code's binary (found by paddo.dev). Directly relevant to SQ-4 and SQ-5.

## Missed Options/Approaches

1. **Temporal/Durable Execution for Sprint Pipelines**: No research on using workflow engines (Temporal, Inngest, Restate) as the state machine backbone for sprint automation. These handle exactly the retry/rollback/checkpoint patterns needed.

2. **Agent Skills Evals/A/B Testing**: Anthropic shipped evals and A/B testing for skills. No coverage of how to use these for quality assurance of a 37-skill suite.

3. **Plugin Marketplace Distribution**: 9,000+ plugins available as of Feb 2026. How does marketplace distribution affect skill architecture decisions?

## Underperforming Connectors

- **Academic connectors (Consensus, Scholar Gateway, HuggingFace, PubMed)**: All denied permission. Zero academic paper search. The ICML paper claim is unverified.
- **MS Learn**: Denied permission. Lost coverage on Azure agent patterns and sandbox documentation.

## Source Count Gap

Current: ~572 scanned | Target: 1000+
Gap: ~430 sources. WebSearch can contribute ~100 more with targeted addendum queries. Gemini can contribute ~100 more. The academic connector denial means we can't close the gap through those channels — compensate with more WebSearch and WebFetch.
