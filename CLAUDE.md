# Claude Skills Suite -- Agent Instructions

> This file is auto-loaded by Claude Code. Read GROUNDING.md for full product context.

## First Steps

1. Read `GROUNDING.md` -- WHY: what this project is, decisions, constraints, anti-patterns
2. Read `ENGINEERING-NOTEBOOK.md` -- JOURNEY: how the suite evolved, key decisions
3. Read `references/cross-cutting-rules.md` -- 10 rules every skill must follow
4. Read `PLAN.md` -- adoption history (Phases 0-5 complete, simplification plan pending)
5. Rehydrate from memory: `gateway_call > rehydrate {topic: "Claude Skills Suite", project_slug: "claude-skills-suite"}`

## What This Repo Is

A collection of AI agent instruction files (SKILL.md) that Claude Code loads as slash
commands. Originally Trevor Byrum's framework, forked and adapted by Matt Schedler
starting March 2026. Skills are the primary way Matt's agents do repeatable work --
they encode planning discipline, review rigor, and execution patterns.

This repo is shared across ALL projects via Claude Code's settings.json skills path.

## Repo Structure

```
skills/                      # 55 active skill directories (each has SKILL.md)
  archive/                   # Deprecated skills (project-scaffold, clean-project)
  project-organize/          # Newest: replaces scaffold + clean-project
  feature-dev/               # Daily driver development skill
  archive/ralph-workflow/    # Merged into feature-dev Ralph mode
  notebook-init/             # Engineering notebook creation
  meta-*/                    # Orchestration skills
  *-review/                  # Review lenses
  codex/ gemini/ vibe/ ...   # Driver skills for external CLIs
references/                  # Shared reference material (cross-cutting-rules.md, etc.)
rules/                       # Global rules (general.md)
```

## How to Add a Skill

1. Run `/skill-forge my-new-skill` -- scaffolds directory and SKILL.md from template
2. Or manually: create `skills/my-skill/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill
   description: "What this skill does and when to use it."
   ---
   ```
3. Keep SKILL.md under 300 lines. Move overflow to `skills/my-skill/references/`
4. Follow all 10 rules in `references/cross-cutting-rules.md`
5. Test the skill on a real project before considering it done

## How to Edit a Skill

1. Read the existing SKILL.md first
2. Read `references/cross-cutting-rules.md` (every skill must follow these)
3. Make changes. Preserve the frontmatter format
4. If the skill has references/, check those for consistency
5. Do NOT break `feature-dev` -- it is the established development workflow (includes Ralph mode)

## Key Conventions

- **GROUNDING.md first**: Every skill that touches a project reads GROUNDING.md before anything else
- **No project litter**: Skills must NOT create framework files (coterie.md, cnotes.md, etc.) in target projects
- **Agent-agnostic**: Skills describe WHAT, not which model to use
- **MCP optional**: Gateway calls enrich but never block; skip gracefully if unavailable
- **Windows/Git Bash**: No macOS commands, no Homebrew, no `gtimeout`
- **Qdrant search hints**: Reference memories with search keywords, not UUIDs (migration-safe)

## Skill Frontmatter Flags

| Flag | Effect |
|------|--------|
| `name` (required) | Slash command name |
| `description` (required) | When to use this skill |
| `disable-model-invocation: true` | Internal skill -- called by other skills, not user-invocable |

## Guardrails

- DO NOT deprecate Trevor's skills without understanding the research behind them
- DO NOT create skills that exceed 300 lines (use references/ for overflow)
- DO NOT assume external CLIs exist (gate behind checks, provide fallback)
- DO NOT replace feature-dev without Matt's explicit approval
- DO NOT hardcode model names in skill logic
