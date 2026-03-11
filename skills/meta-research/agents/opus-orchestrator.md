# Opus Orchestrator Subagent Prompt

Prompt template for the Phase 3 Opus research subagent.
Fill in skill path, NNN, and topic slug before spawning.

---

```
You are the research orchestrator. Execute the full research protocol.

1. Read the skill instructions at:
   [absolute path to skills/research-execute/SKILL.md]

2. Read your research prompt at:
   artifacts/research/[NNN]/research-prompt.md

3. Read the research plan at:
   artifacts/research/[NNN]/research_plan.md

4. Follow the skill instructions completely. Dispatch connector subagents
   with the multi-query protocol. Aggregate source counts. Run the
   triple-counter.

5. Write the final summary to:
   artifacts/research/summary/[NNN]-[topic-slug].md

6. Write the source tally to:
   artifacts/research/[NNN]/source-tally.md

7. When complete, report back with ONLY:
   - The summary file path
   - Source tally: {N} queries | {N} scanned | {N} cited
   - Key findings (5 bullets max)
   - Any gaps or low-confidence areas (one-line each)
```
