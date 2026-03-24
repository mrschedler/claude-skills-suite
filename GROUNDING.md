# GROUNDING.md — Skills Suite (Schedler Fork)

## Why This Exists

Matt Schedler runs 10+ active projects — embedded C++ (USB proxy, patent work), Node/Express web apps, FastAPI services, PHP legacy systems. Every AI coding session starts cold. The agent doesn't know what Matt wants, how he works, what the project boundaries are, or what decisions were already made.

This project exists to solve that cold-start problem at the **skill layer**. When any agent — Claude, Codex, Gemini, Cursor, or whatever comes next — opens a project, the skills encode the right planning discipline, review rigor, and execution patterns. No re-explaining expectations every session.

**Origin**: Forked from `trevorbyrum/claude-skills-suite` because the architecture is sound (progressive disclosure, review lenses, build planning discipline). Adapted for Matt's environment, stack, and workflow. This is no longer Trevor's suite — it's ours.

## What Matters

1. **Agent autonomy with guardrails.** Matt wants to hand work to agents and trust the output. Skills should encode enough structure that any agent makes sound decisions without constant check-ins, but never so much ceremony that simple tasks become bureaucratic.

2. **Cold-start context.** Every skill that touches a project should look for GROUNDING.md, project-context, or equivalent docs FIRST. An agent with no context is an agent that guesses — and guessing wastes time.

3. **Review quality over review quantity.** One thorough review pass is worth more than 5 shallow passes from 5 models. Review lenses should work standalone with any capable model. Multi-model orchestration is an optional enhancement, not a requirement.

4. **Windows + Git Bash environment.** All shell scripts, path resolution, and CLI assumptions must work on Windows 11 with Git Bash. No Homebrew, no macOS paths, no `gtimeout`.

5. **Existing infrastructure.** Matt's stack: Qdrant (vector memory), Neo4j (graph), MongoDB (docs), PostgreSQL, Redis, n8n, Vault — all on Unraid via MCP Gateway (34 modules, 300+ tools at `mcp__gateway__*`).

## What Will Hurt If You Get It Wrong

- **Injecting files into projects that don't belong.** Skills must not litter project directories with framework artifacts (coterie.md, cnotes.md, etc.).
- **Assuming specific CLIs exist.** Codex CLI, Gemini CLI, Vibe CLI, Cursor Agent CLI, Copilot CLI — may or may not be installed. Any skill that references an external CLI must gate behind availability checks and provide a fallback path.
- **Breaking existing workflows.** `feature-dev` and `ralph-workflow` are established skills that work. New skills complement them — they don't replace them without cause.
- **Over-engineering.** A skill that takes 500 lines to describe a review process that could be 100 lines wastes context window. Simpler is better.
- **Platform assumptions.** `$GTIMEOUT`, `/opt/homebrew/`, NVM paths — none of these exist here. Scripts must be platform-aware.

## Environment Reference

| Component | Details |
|-----------|---------|
| **OS** | Windows 11 Pro, Git Bash shell |
| **Primary AI tool** | Claude Code CLI (but skills should be agent-agnostic where possible) |
| **MCP Gateway** | `mcp__gateway__*` — 34 modules, 300+ tools on Unraid (192.168.0.129:3500) |
| **Memory stores** | Qdrant (`memory_call`), Neo4j (`graph_call`), MongoDB (`mongodb_call`) |
| **Projects** | `C:\dev\*` — each with pipeline entry via `project_call` |
| **Skills location** | `C:\dev\claude-skills-suite\skills\` (git-tracked, referenced by settings.json) |
| **Config shortcut** | `C:\dev\claude-home` junction → `~/.claude` |
| **GitHub** | `mrschedler` |

## Existing Skills (Do Not Break)

- **feature-dev** — Unified development skill. Assesses complexity (simple/medium/complex), scales rigor accordingly. Uses CLAUDE_NOTES.md for project memory, prd.json + progress.txt for complex work. Daily driver.
- **ralph-workflow** — Autonomous iterative coding. PRD-driven, one story at a time, fresh context per iteration. Good for mechanical work.

## Decision Principles

1. **Cherry-pick, don't wholesale adopt.** Every skill must earn its place by being useful in this environment as-is or with reasonable adaptation.
2. **Agent-agnostic first.** Skills describe WHAT to do and WHEN, not which specific AI model to use. The agent reading the skill decides how to execute. Model-specific dispatch (subagents, CLI delegation) is an implementation detail, not a skill concern.
3. **Respect the context window.** Progressive disclosure is good — keep it. Shorter skills are better skills. If SKILL.md exceeds 300 lines, overflow goes to `references/`.
4. **Integrate with existing memory stack.** Qdrant, Neo4j, MongoDB via MCP Gateway. No per-project SQLite databases unless there's a strong reason.
5. **Test before shipping.** A skill isn't done until it's been invoked and produced useful output on a real project.

## Anti-Patterns (Things Any Agent Must NOT Do)

- Do NOT create `coterie.md` or `cnotes.md` in projects
- Do NOT assume macOS paths or Homebrew tools
- Do NOT add external CLI calls without gating behind availability checks and providing fallback
- Do NOT replace `feature-dev` or `ralph-workflow` without explicit approval from Matt
- Do NOT create per-project SQLite databases without discussion
- Do NOT hardcode model names in skill logic — describe the task, let the executing agent choose the right model/delegation strategy
- Do NOT write skills that only work with one AI platform — the skill should describe the workflow, not the tool
