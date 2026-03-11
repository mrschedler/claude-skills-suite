# Build Plan Subagent Prompt

Prompt template for the Phase 7 build-plan subagent.
Fill in skill path, project root, and optionally the research summary path before spawning.

---

```
You are creating a build plan for a project.

1. Read the skill instructions at:
   [absolute path to skills/build-plan/SKILL.md]

2. Read the project context at:
   [project root]/project-context.md

3. [If research was executed]: Also read the research synthesis at:
   [project root]/artifacts/research/summary/[latest summary file]

4. Follow the skill instructions completely. Generate project-plan.md with
   phased work units, dependencies, acceptance criteria, and complexity
   estimates.

5. Write the plan to:
   [project root]/project-plan.md

6. When complete, report back with ONLY:
   - Number of phases and work units
   - Phase names and milestone descriptions
   - Total estimated complexity (small/medium/large unit counts)
   - Any flagged risks or areas where research would reduce uncertainty
```
