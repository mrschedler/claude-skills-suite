### Research Goal
How Claude Code skills consume context tokens, specifically: description budget, `SKILL.md` lazy loading, overflow behavior, caching, and MCP interaction.

### Findings (Anthropic docs)
1. **Description budget (2% / 16K fallback)**  
Skill metadata (especially descriptions used for model invocation) has a character budget that “scales dynamically at 2% of the context window, with a fallback of 16,000 characters.” If exceeded, some skills are excluded; you can inspect with `/context` and override with `SLASH_COMMAND_TOOL_CHAR_BUDGET`.  
Source: [Extend Claude with skills](https://code.claude.com/docs/en/skills)

2. **`SKILL.md` lazy loading behavior**  
Anthropic docs state skills load in two phases: descriptions at session start, and full skill content only when invoked/selected. `disable-model-invocation: true` makes a skill invisible to model auto-invocation until manual use.  
Sources: [Extend Claude Code](https://code.claude.com/docs/en/features-overview), [Extend Claude with skills](https://code.claude.com/docs/en/skills)

3. **When budget is exceeded (“silent exclusion”)**  
Docs explicitly say excluded skills can happen when description budget is exceeded and tell you to check `/context` for a warning about excluded skills.  
Inference: because the warning is in `/context` (not described as a hard runtime error), this can feel “silent” during normal prompting.  
Source: [Extend Claude with skills](https://code.claude.com/docs/en/skills)

4. **Caching**  
Claude Code docs say it uses prompt caching to reduce repeated-cost content (example given: system prompts). They also note subagent system prompts are shared with parent “for cache efficiency.”  
What is **not** explicitly documented: a dedicated, separate cache policy specifically for skill descriptions vs full `SKILL.md` payloads.  
Sources: [Manage costs effectively](https://code.claude.com/docs/en/costs), [Extend Claude Code](https://code.claude.com/docs/en/features-overview)

5. **MCP tool interaction with skill budget**  
MCP tool definitions can also consume context; tool search auto-defers MCP tools when tool descriptions exceed 10% of context, loading only needed tools on demand.  
Inference: skills and MCP both draw from the same overall context window, but are managed by separate mechanisms (skills description budget vs MCP tool-search threshold).  
Sources: [Extend Claude Code](https://code.claude.com/docs/en/features-overview), [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp)

### Source Tally
- Queries run: **21**
- Official Anthropic docs pages scanned: **8**
- Official Anthropic docs pages cited: **4**
