# Deep Research Prompt — 008D

## Research Question
What are the best practices for managing large AI-assisted coding projects that exceed effective context window capacity, and how should a "sub-project" skill be designed to partition work into focused, quasi-independent contexts while maintaining coherence with the parent project?

## Sub-Questions
1. How does Claude Code accuracy degrade as project size grows? What are the measurable thresholds (file count, token count, dependency graph complexity) where accuracy drops?
2. What context management strategies exist for large codebases with LLM coding assistants? (CLAUDE.md scoping, .cursorrules, workspace partitioning, context distillation, etc.)
3. What is the optimal document partitioning strategy for sub-projects — which project docs should be symlinked (shared), which copied, which generated fresh, and why?
4. How should cross-cutting concerns (shared types, APIs, DB schemas, design tokens) be handled across sub-project boundaries without polluting context?
5. What is "context distillation" — how do you summarize a large codebase into minimal but sufficient context for a focused sub-task? What are proven patterns?
6. What granularity works best for sub-projects? Feature-level, service-level, module-level, or sprint-level — and what determines the right choice?
7. What is the optimal sub-project lifecycle? Creation → execution → merge-back → cleanup. What are the pitfalls at each stage?
8. How do monorepo tools (Nx, Turborepo, Bazel) and workspace patterns inform sub-project isolation for AI coding?
9. Are there alternative approaches to sub-projects that solve the same problem? (e.g., smarter context pruning, dynamic context loading, tiered CLAUDE.md files, git worktrees)
10. What are the failure modes and risks of sub-project isolation? (drift, inconsistency, duplication, stale context, merge conflicts, divergent conventions)
11. How should architecture.md be structured for a sub-project so it contains everything needed from the parent project without requiring frequent lookups?
12. What role should an interview/question round play in sub-project setup, and what questions yield the highest-value context?

## Scope
- Breadth: focused but exhaustive within focus area
- Focus: Claude Code context management, sub-project partitioning, AI coding at scale
- Time horizon: primarily recent (2024-2026), include foundational patterns if relevant
- Domain: AI-assisted software development, monorepo management, context window optimization
- Exclude: general project management, non-AI tooling comparisons

## Project Context
This is a Claude Code skill suite — a collection of ~40 skills that orchestrate multi-model AI coding workflows. The suite uses:
- CLAUDE.md / rules/ for project instructions
- coterie.md for multi-agent collaboration rules
- artifacts/ directory for skill outputs (research, reviews, plans)
- project-plan.md, features.md, architecture.md as core project docs
- build-plan.md for implementation planning
- Meta-skills that dispatch subagents (Opus, Sonnet, Codex, Gemini, Copilot, Cursor, Vibe)
- Progressive disclosure (metadata → SKILL.md → bundled resources)

The user has observed accuracy degradation on larger projects and wants a skill that:
1. Points at a subfolder and sets it up as a quasi-independent project
2. Symlinks shared docs (coterie.md, cross-cutting-rules) to avoid duplication
3. Selectively transfers only relevant research/artifacts
4. Optionally interviews the user to gather sub-project context
5. Builds architecture.md with sufficient parent context to work independently
6. Generates sub-project-specific build-plan.md, features.md, etc.
7. Supports flexible granularity (feature, service, module, sprint)
8. Handles merge-back or permanent subfolder residence

## Known Prior Research
- 007D: LLM agent code efficiency (may have relevant context window findings)
- No direct prior research on sub-project partitioning

## Output Configuration
- Research folder: artifacts/research/008D/
- Summary destination: artifacts/research/summary/008D-sub-project-context-management.md
- Topic slug: sub-project-context-management

## Special Instructions
- Prioritize practical, implementable patterns over theoretical frameworks
- Challenge the assumption that sub-projects are the best approach — explore alternatives
- Pay special attention to the symlink vs copy vs generate-fresh decision matrix
- Research how Claude Code's own CLAUDE.md scoping (nested CLAUDE.md files) already handles some of this
- Look for real-world examples of teams managing large AI-assisted codebases
- Consider the "context distillation" problem deeply — this is the hardest part
- Investigate whether git worktrees could serve as a lighter-weight alternative
