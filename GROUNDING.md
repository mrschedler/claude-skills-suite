# GROUNDING.md -- Claude Skills Suite

> Read this before touching anything. It explains why this project exists,
> what matters, and what will hurt if you get it wrong.

## Why This Exists

Matt Schedler runs 10+ active projects spanning embedded C++ (USB proxy, patent work), Node/Express web apps, FastAPI services, PHP legacy systems, and hardware firmware. Every AI coding session starts cold. The agent does not know what Matt wants, how he works, what the project boundaries are, or what decisions were already made.

This project solves the cold-start problem at the **skill layer**. Skills are reusable instruction files (SKILL.md) that Claude Code loads as slash commands. When an agent opens any project, the skills encode the right planning discipline, review rigor, and execution patterns. No re-explaining expectations every session.

**Origin:** Forked from `trevorbyrum/claude-skills-suite` on 2026-03-11. Trevor Byrum's framework is architecturally sound -- progressive disclosure, review lenses, build planning discipline, multi-model orchestration. Matt imported it and adapted it for his environment (Windows 11, Git Bash, MCP Gateway infrastructure) starting 2026-03-23. This is no longer Trevor's suite, but Trevor's research behind the original skills is valuable and must be understood before any skill is deprecated or reclassified.

**Shared across all projects:** This repo is the single source of truth for all agent skills. It is referenced by Claude Code's settings.json skills path (`C:\dev\claude-skills-suite\skills`). A symlink from `~/.claude/skills` to this repo is planned but not yet configured (requires elevated PowerShell with Claude Code closed).

## What Matters

1. **Skills are how Matt's agents do repeatable work.** Quality of skill instructions directly affects agent output quality. A bad skill produces bad work across every project that uses it.

2. **Cold-start context is the #1 problem.** Every skill that touches a project must look for GROUNDING.md first. An agent with no context is an agent that guesses, and guessing wastes time.

3. **Agent autonomy with guardrails.** Matt wants to hand work to agents and trust the output. Skills encode enough structure that any agent makes sound decisions without constant check-ins, but never so much ceremony that simple tasks become bureaucratic.

4. **Agent-agnostic execution.** Skills describe WHAT to do, not which model to use. The executing agent decides HOW. Model-specific dispatch is an optional enhancement, never a requirement.

5. **Windows + Git Bash environment.** All shell commands must work on Windows 11 with Git Bash. No macOS paths, no Homebrew, no `gtimeout`, no `zsh`.

## Key Decisions

| Decision | Alternatives Considered | Why This One |
|----------|------------------------|--------------|
| Fork Trevor's suite, cherry-pick skills | Build from scratch; wholesale adopt | Sound architecture worth preserving, but many skills too coupled to Trevor's 5-CLI multi-model setup |
| GROUNDING.md as primary project doc | coterie.md, cnotes.md, project-context.md | Single authoritative file that any agent can read in 2 minutes; other files were framework litter |
| Qdrant search hints in docs, not UUIDs | Raw Qdrant UUIDs | UUIDs break on migration; search hints are stable across reindex |
| MCP Gateway as enhancement, not requirement | MCP required for all skills | Agents without MCP must still function; infrastructure enriches but never blocks |
| 300-line skill limit with overflow to references/ | No limit | Context window discipline; shorter skills are better skills |
| /project-organize replaces scaffold + clean-project | Keep both separate | One skill for all project organization; simpler mental model |
| Engineering notebooks as journey docs | Inline comments in GROUNDING.md | GROUNDING.md captures current state; notebook captures how we got here |

## Tech Stack

| Component | Details |
|-----------|---------|
| **Runtime** | Claude Code CLI on Windows 11 Pro, Git Bash shell |
| **Skill format** | YAML frontmatter (name, description, optional flags) + Markdown body |
| **MCP Gateway** | `mcp__gateway__*` -- 34 modules, 300+ tools on Unraid (192.168.0.129:3500) |
| **Memory stores** | Qdrant (vector/semantic), Neo4j (graph/relationships), MongoDB (reference docs) |
| **Project pipeline** | `project_call` via MCP Gateway |
| **Config shortcut** | `C:\dev\claude-home` junction to `~/.claude` |
| **GitHub** | mrschedler/claude-skills-suite |

## Current Architecture

```
skills/                      # 55 active skill directories (each has SKILL.md)
  archive/                   # 2 deprecated skills (project-scaffold, clean-project)
  project-organize/          # Newest skill -- replaces scaffold + clean-project
  feature-dev/               # Daily driver development skill
  ralph-workflow/            # Autonomous iterative coding
  meta-*/                    # Orchestration skills (init, review, execute, etc.)
  *-review/                  # Review lenses (security, test, drift, etc.)
  codex/ gemini/ vibe/ ...   # Driver skills for external CLIs
  notebook-init/             # Engineering notebook creation
  ...
references/                  # Shared reference material (cross-cutting-rules.md, etc.)
rules/                       # Global rules (general.md)
```

**Skill frontmatter fields:**
- `name` (required): Slash command name
- `description` (required): When to use this skill
- `disable-model-invocation: true` (optional): Internal skill, not user-invocable

**Skill categories (current):**
- **Adopted and adapted** (~15): Rewritten agent-agnostic for Matt's environment
- **Original Trevor skills** (~35): Imported as-is, many still coupled to multi-CLI setup
- **Matt's new skills** (~5): project-organize, notebook-init updates, feature-dev, ralph-workflow

## The Simplification Plan

**Status:** Approved, not yet executed. Tracked under the memory-upgrade initiative.

Matt's assessment: 55 active slash commands is overwhelming. He thinks in higher-level terms ("organize", "build", "review", "ship"), not granular skills.

**Target architecture:**
- **Top-level skills (~5):** project-organize, feature-dev, research, review, ship
- **Hooks (~3):** memory assessment (post-session), doc drift (post-code-change), notebook prompt (post-decision)
- **Sub-skills (everything else):** Called by top-level skills, not directly invocable (`disable-model-invocation: true`)

**Execution plan (next sessions):**
1. Symlink fix: `~/.claude/skills` to this repo (manual, elevated PowerShell)
2. Catalog Trevor's skills -- understand the research and intent behind each before reclassifying
3. Design the ~5 top-level skills
4. Design the 3 hooks
5. Reclassify remaining skills as sub-skills
6. Test simplified system on a real project

**CRITICAL:** Do NOT deprecate Trevor's skills without understanding the research behind them. His deep-research skill alone orchestrates ~20 workers across 3 model families. That research has value even if the current implementation is too coupled to his CLI setup.

Qdrant: search "skill suite simplification plan 2026-03-25"

## Constraints

- All shell commands must work in Git Bash on Windows 11 (no macOS tools)
- Skills must not exceed 300 lines; overflow goes to `references/`
- No per-project SQLite databases (use Qdrant/MongoDB via MCP Gateway)
- No project litter (coterie.md, cnotes.md, todo.md, features.md)
- External CLI calls must be gated behind availability checks with fallback paths
- MCP Gateway is an enhancement, not a requirement

## What Will Hurt If You Get It Wrong

1. **DO NOT deprecate skills without understanding Trevor's research behind them.** His skills encode multi-model orchestration patterns, review lens architectures, and research pipeline designs developed through extensive experimentation. Catalog first, then reclassify.

2. **DO NOT create project litter.** Skills must not create framework-specific files (coterie.md, cnotes.md, todo.md, features.md) in target projects. Cross-cutting rule 2.

3. **DO NOT assume all agents have MCP Gateway.** Skills must work without it. Infrastructure calls are enhancements, not blockers. Cross-cutting rule 5.

4. **DO NOT use macOS commands.** Everything must work in Git Bash on Windows 11. No `gtimeout`, no `/opt/homebrew/`, no Homebrew tools. Cross-cutting rule 6.

5. **DO NOT make skills exceed 300 lines.** Move overflow to `references/`. Cross-cutting rule 7.

6. **DO NOT break feature-dev.** This is the established daily-driver development skill (includes Ralph mode for multi-session iterative work). New skills complement it; they do not replace it without explicit approval. Cross-cutting rule 9.

7. **DO NOT hardcode model names in skill logic.** Skills describe tasks; the executing agent chooses how to delegate.

8. **DO NOT inject files into target projects that are not described in the skill's Outputs section.** If a skill creates a file, it must be documented and confirmed by the user.

## Current State

**Last updated:** 2026-03-25

- 55 active skills in `skills/`, 2 archived in `skills/archive/`
- 15 skills fully adapted for Matt's environment (Phases 1-4 of PLAN.md)
- ~35 skills still in Trevor's original form (functional but may assume multi-CLI setup)
- 4 hooks deployed in `~/.claude` (stop-quality-gate, pre-commit-lint, post-edit-complexity, pre-compact-capture)
- `/project-organize` is the newest and most battle-tested skill (used on G3-Lite and G3-Enterprise on 2026-03-25)
- Simplification plan approved but not yet executed
- Symlink from `~/.claude/skills` to this repo NOT YET configured

## Key Documents

| Document | Purpose |
|----------|---------|
| `GROUNDING.md` (this file) | WHY -- product context, decisions, constraints, anti-patterns |
| `ENGINEERING-NOTEBOOK.md` | JOURNEY -- what was tried, decided, learned over time |
| `CLAUDE.md` | QUICKSTART -- reading order, how to add/edit skills |
| `PLAN.md` | Adoption plan (Phases 0-5, all complete) |
| `references/cross-cutting-rules.md` | 10 rules every skill must follow |
| `rules/general.md` | Global agent behavior rules |
| `README.md` | Trevor's original README (describes multi-model architecture) |
| `skill-suite-build-spec.md` | Architecture specification (Trevor's) |
| `research-synthesis.md` | Reference: how research output looks |

## Related Projects

| Project | Repo/Location | Relationship |
|---------|---------------|-------------|
| All projects in `C:\dev\` | Various | Consume these skills |
| memory-consolidation-engine | Pipeline slug | Broader initiative this feeds into (memory + skills + project org) |
| MCP Gateway | Unraid `/mnt/raid1_pool/appdata/mcp-gateway/repo/` | Infrastructure layer skills can call |
| Trevor's original | `trevorbyrum/claude-skills-suite` | Upstream fork source |
