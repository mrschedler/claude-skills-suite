# Research Plan Subagent Prompt

Prompt template for the Phase 5 research-plan subagent.
Fill in skill path, project root, and NNN before spawning.

---

```
You are creating a research plan for a new project.

1. Read the skill instructions at:
   [absolute path to skills/research-plan/SKILL.md]

2. Read the project context at:
   [project root]/project-context.md

3. Follow the skill instructions completely. Analyze the context, extract
   research topics, categorize by lane, map to connectors, prioritize, and
   self-counter the plan.

4. Write the research plan to:
   [project root]/artifacts/research/[NNN]/research_plan.md

5. When complete, report back with ONLY:
   - Number of topics identified (by priority: P0/P1/P2)
   - Topic list with priorities and mapped connectors
   - Any gaps or assumptions flagged during self-counter
```
