# Claude Skills Suite -- Agent Instructions

> This file is auto-loaded by Claude Code. It covers project-specific conventions
> for working in this repo only. Behavioral protocol lives in
> `config/code/behavioral-reminders.txt` (agent-agnostic, hook-injected).

## First Steps

1. Read `GROUNDING.md` -- WHY: what this project is, decisions, constraints, anti-patterns
2. Read `ENGINEERING-NOTEBOOK.md` -- JOURNEY: how the suite evolved, key decisions
3. Read `references/cross-cutting-rules.md` -- 10 rules every skill must follow
4. Rehydrate from memory: `gateway_call > rehydrate {topic: "Claude Skills Suite", project_slug: "claude-skills-suite"}`

## Butterfly Wings

1-line change here → every project, every machine, every kit user. Test before committing.

## File Architecture

| File | Scope | Purpose |
|------|-------|---------|
| `config/code/behavioral-reminders.txt` | all agents | behavioral protocol (session lifecycle, memory, hygiene). agent-agnostic. source of truth. |
| `config/code/CLAUDE.md` (global) | Claude Code | infrastructure, workspace, machine identity. Claude-specific only. |
| `CLAUDE.md` (this file) | this repo | project conventions for editing skills suite. |
| `GROUNDING.md` | this repo | WHY — decisions, constraints, anti-patterns. |
| `ENGINEERING-NOTEBOOK.md` | this repo | journey log — decisions over time. |

behavioral-reminders.txt = HOW (any agent). CLAUDE.md = Claude wiring. GROUNDING.md = WHY.

## Hooks

Transport-agnostic, ~20-30 lines, local checks only. No SSH/MCP/network.
Output: key=value facts + action reminders. Agent acts via native MCP tools.

## What This Repo Is

Reusable AI agent instruction files (SKILL.md) loaded as slash commands.
Origin: forked from trevorbyrum/claude-skills-suite (2026-03-11), adapted for Windows/Git Bash + MCP Gateway.
Shared across ALL projects via settings.json skills path.

## Repo Structure

```
config/code/                 # Claude Code config (settings, behavioral-reminders.txt)
hooks/                       # Transport-agnostic hooks (~20-30 lines each, local only)
skills/                      # Active skill directories (each has SKILL.md)
  archive/                   # Deprecated skills
  project-organize/          # Replaces scaffold + clean-project
  feature-dev/               # Daily driver development skill (includes Ralph mode)
  notebook-init/             # Engineering notebook creation
  meta-*/                    # Orchestration skills
  *-review/                  # Review lenses
references/                  # Shared reference material (cross-cutting-rules.md, etc.)
rules/                       # Global rules (general.md)
scripts/                     # Utility scripts
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
5. Test the skill on a real project before considering it done (butterfly-wings)

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
- **Hooks are local**: Hooks do local filesystem checks and output facts. No network calls. Agent acts on the output.
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
- DO NOT add network calls (SSH, MCP, HTTP) to hooks -- hooks are local-only
- DO NOT put behavioral protocol in CLAUDE.md -- it belongs in behavioral-reminders.txt
