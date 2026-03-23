# AI Coding Agent Context & Ignore Files — Research Report

**Date**: 2026-03-20
**Scope**: Context files, ignore files, project structure recommendations across all major AI coding agents

---

## Table of Contents

1. [Universal Standard: AGENTS.md](#1-universal-standard-agentsmd)
2. [Cursor: .cursorrules / .cursor/rules/](#2-cursor)
3. [GitHub Copilot: copilot-instructions.md](#3-github-copilot)
4. [Claude Code: CLAUDE.md](#4-claude-code)
5. [Cline / Roo Code: .clinerules / .roo/](#5-cline--roo-code)
6. [Aider: CONVENTIONS.md / .aider.conf.yml](#6-aider)
7. [OpenAI Codex: AGENTS.md](#7-openai-codex)
8. [Windsurf: .windsurfrules / .windsurf/rules/](#8-windsurf)
9. [Google Gemini CLI: GEMINI.md](#9-google-gemini-cli)
10. [Zed Editor](#10-zed-editor)
11. [JetBrains Junie](#11-jetbrains-junie)
12. [Amazon Q Developer](#12-amazon-q-developer)
13. [OpenHands / SWE-Agent](#13-openhands--swe-agent)
14. [Devin](#14-devin)
15. [Ignore File Mechanisms](#15-ignore-file-mechanisms)
16. [Research: Do Context Files Actually Help?](#16-research-do-context-files-actually-help)
17. [Agent-Friendly Project Structure](#17-agent-friendly-project-structure)
18. [Cross-Tool Compatibility Matrix](#18-cross-tool-compatibility-matrix)
19. [Key Takeaways & Recommendations](#19-key-takeaways--recommendations)
20. [Sources](#20-sources)

---

## 1. Universal Standard: AGENTS.md

**Status**: Open standard under Linux Foundation's Agentic AI Foundation (AAIF)
**Adoption**: 60,000+ open-source projects as of March 2026
**Governance**: Donated by OpenAI and Anthropic to Linux Foundation (Dec 2025)

### What It Does

AGENTS.md is a standardized Markdown file providing AI coding agents with project-specific instructions — build commands, code conventions, testing requirements, and boundaries. It functions as a "README for agents."

### Origin and Timeline

- **Aug 2025**: OpenAI originated the spec for Codex CLI
- **Mid 2025**: Collaboration between Sourcegraph, OpenAI, Google, Cursor, Factory, and Amp
- **Dec 2025**: Donated to Linux Foundation AAIF for vendor-neutral governance

### Supported Tools (as of March 2026)

- **IDE-integrated**: GitHub Copilot, Cursor, Windsurf, Zed, Warp, VS Code (extensions), JetBrains Junie
- **Standalone/CLI**: OpenAI Codex, Google Jules, Gemini CLI, Amp, Devin, Aider, goose (Block), Kilo Code, Builder.io, RooCode, Augment Code, OpenHands, Claude Code (fallback)

### Format

- Standard Markdown, no required structure
- Nested files in subdirectories override parent-level files
- Common sections: project overview, build/test commands, code style, security, commit/PR formatting

### Best Practices

- Keep actionable — every line must justify its presence
- Focus on non-inferable information (custom build systems, legacy constraints, team conventions)
- Nest subdirectory AGENTS.md for monorepo module-specific guidance
- Version control the file alongside code

---

## 2. Cursor

### Context Files

| File | Status | Purpose |
|------|--------|---------|
| `.cursorrules` | **Deprecated** | Single project-wide rules file |
| `.cursor/rules/*.mdc` | **Current** | Modular, scoped rule files |
| `.cursorignore` | Active | Exclude files from AI features + indexing |
| `.cursorindexingignore` | Active | Exclude files from indexing only |

### .cursor/rules/ System (Current)

Each rule is a `.mdc` file with frontmatter:

```yaml
---
description: "What this rule does"
globs: ["src/**/*.ts", "*.config.js"]
alwaysApply: false
---
Rule content in Markdown...
```

**Activation Modes**:
- **Always On** (`alwaysApply: true`): Injected into every conversation
- **Auto Attached**: Activated when working with files matching globs
- **Model Decision**: AI decides whether to include based on description
- **Manual**: User explicitly invokes via `@Cursor Rules`

### What Helps

- One concern per `.mdc` file — split big specs into composable units
- Anchor with concrete code samples and explicit globs
- Use conditional activation to minimize token waste
- Write like internal docs: clear do/don't lists

### What Causes Problems

- Overly long `.cursorrules` files (deprecated format) that overload context
- Vague or aspirational rules the agent can't act on
- Duplicating linter/formatter concerns that tools handle better
- `.cursorignore` is best-effort — not a security guarantee; bugs may leak ignored files

### Context Window Impact

- Glob-scoped rules only load when relevant, reducing token usage vs. always-on monolithic files
- The modular system was specifically designed to address context bloat from `.cursorrules`

**Sources**: [Cursor Rules Docs](https://docs.cursor.com/context/rules-for-ai), [Cursor Ignore Files](https://docs.cursor.com/context/ignore-files), [Cursor Forum Best Practices](https://forum.cursor.com/t/best-practices-cursorrules/41775)

---

## 3. GitHub Copilot

### Context Files

| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Repository-wide instructions |
| `.github/instructions/*.instructions.md` | Path-specific scoped instructions |
| `AGENTS.md` (anywhere in repo) | Agent-mode instructions (coding agent) |
| `CLAUDE.md`, `GEMINI.md` (root) | Cross-tool compatibility (agent mode) |

### Repository-Wide Instructions

- Natural language Markdown in `.github/copilot-instructions.md`
- Automatically added to all Copilot requests in the repository context
- Constraint: Instructions must be no longer than 2 pages

### Path-Specific Instructions

YAML frontmatter with glob patterns:

```yaml
---
applyTo: "app/models/**/*.rb"
excludeAgent: "code-review"
---
```

### What to Include

- Repository purpose summary
- Tech stack, languages, frameworks, runtimes
- Build/test command sequences with preconditions and postconditions
- Project layout with major architectural elements
- Configuration file locations, CI/CD workflows
- Known errors and workarounds

### What Causes Problems

- Conflicting instructions across personal, repository, and organization levels
- Task-specific instructions (these should be in prompts, not instruction files)
- Unvalidated build commands — document timing and expected failures

### Context Window Impact

- All relevant instruction sets are provided to Copilot simultaneously
- Path-specific instructions only load when matching files are active
- References visible in Chat view's References list

**Sources**: [GitHub Copilot Custom Instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot), [5 Tips for Custom Instructions](https://github.blog/ai-and-ml/github-copilot/5-tips-for-writing-better-custom-instructions-for-copilot/), [AGENTS.md for Copilot](https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/)

---

## 4. Claude Code: CLAUDE.md

### Context Files

| File | Location | Purpose |
|------|----------|---------|
| `CLAUDE.md` | Project root | Project-specific instructions |
| `CLAUDE.md` | Subdirectories | Directory-scoped instructions |
| `~/.claude/CLAUDE.md` | Home directory | Global personal instructions |
| `.claude/settings.json` | Project | Permission, model settings |

### How It Works

- Read automatically at the start of every conversation
- Three-tier hierarchy: global → project root → subdirectories, merged in order
- Falls back to `AGENTS.md` if no `CLAUDE.md` exists
- Case-sensitive: must be exactly `CLAUDE.md`
- `/init` command generates a starter file based on current project

### What Helps

- **Keep under 300 lines** — consensus is shorter is better
- Include bash commands for build/test/lint/deploy (Claude uses these directly)
- Document domain-specific terms and how they map to code
- **Progressive disclosure**: Tell Claude how to find information, not all the information
- Focus on what Claude can't infer from visible code

### What Causes Problems

- **Code style guidelines**: "Never send an LLM to do a linter's job" — use deterministic tools
- Overly long files: Claude ignores rules buried in noise
- Redundant instructions: If Claude already does something correctly without the instruction, delete it
- Over-specification wastes context window budget

### Context Window Impact

- Every line consumes context tokens, leaving less room for task execution
- Unnecessary instructions and wordy sentences directly degrade performance
- Use hooks for enforcement rather than lengthy rules

**Sources**: [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices), [Writing a Good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md), [CLAUDE.md Best Practices (UX Planet)](https://uxplanet.org/claude-md-best-practices-1ef4f861ce7c), [Builder.io CLAUDE.md Guide](https://www.builder.io/blog/claude-md-guide)

---

## 5. Cline / Roo Code

### Cline Context Files

| File | Purpose |
|------|---------|
| `.clinerules` (file) | Single project-wide rules file |
| `.clinerules/` (directory) | Multiple organized rule files |
| `.clinerules/*.md` | Individual rule files (numeric prefixes for ordering) |

### Roo Code Context Files

| File | Purpose |
|------|---------|
| `.roo/rules/` | General workspace rules |
| `.roo/rules-{modeSlug}/` | Mode-specific rules (e.g., `.roo/rules-code/`) |
| `.roorules` | Fallback single-file format |
| `.roorules-{modeSlug}` | Mode-specific fallback |
| `~/.roo/rules/` | Global rules (all projects) |
| `AGENTS.md` / `AGENT.md` | Cross-tool compatibility |

### Cross-Tool Detection

Cline automatically detects and offers toggleable rules from:
- `.clinerules/` (Cline format)
- `.cursorrules` (Cursor format)
- `.windsurfrules` (Windsurf format)
- `AGENTS.md` (universal format)

### Conditional Rules (Cline)

YAML frontmatter scopes rules to file patterns:

```yaml
---
paths:
  - "src/components/**"
  - "*.config.js"
---
```

Rules activate based on: open tabs, visible files, mentioned paths, edited files, pending operations.

### Cline Memory Bank

A structured system for persistent project context:
- `projectbrief.md` — project foundation
- `activeContext.md` — current work focus (updated most frequently)
- `systemPatterns.md` — architecture decisions
- `techContext.md` — technologies used
- `progress.md` — what works and what's left

### Roo Code Loading Order

1. Global instructions (Prompts Tab)
2. Mode-specific instructions (current mode)
3. Mode-specific rule directories (`~/.roo/rules-{modeSlug}/` + `.roo/rules-{modeSlug}/`)
4. Mode-specific fallback files (`.roorules-{modeSlug}`)
5. General rule directories (`~/.roo/rules/` + `.roo/rules/`)
6. General fallback file (`.roorules`)

### What Helps

- One concern per rule file
- Explain rationale ("why") to help edge-case decisions
- Reference existing codebase patterns rather than describing from scratch
- Conditional rules reduce token waste

### What Causes Problems

- Rules consume context tokens — keep concise, link to external docs when needed
- Outdated constraints that conflict with current tech stack
- Workspace rules override global rules — can cause confusion in multi-project setups

**Sources**: [Cline Rules Docs](https://docs.cline.bot/features/cline-rules), [Roo Code Custom Instructions](https://docs.roocode.com/features/custom-instructions), [Cline Context Window Explained](https://cline.bot/blog/clines-context-window-explained-maximize-performance-minimize-cost)

---

## 6. Aider

### Context Files

| File | Purpose |
|------|---------|
| `CONVENTIONS.md` | Coding conventions (read-only recommended) |
| `.aider.conf.yml` | YAML configuration |
| `.aider/` | (Not a standard directory — config is file-based) |
| `.env` | API keys for non-OpenAI/Anthropic providers |

### Configuration Search Order

1. `~/.aider.conf.yml` (home directory)
2. `.aider.conf.yml` (git repo root)
3. `.aider.conf.yml` (current working directory)
4. Later files override earlier ones

### Conventions Loading

Best practice is read-only loading for caching:

```bash
aider --read CONVENTIONS.md
# or in chat:
/read CONVENTIONS.md
```

Persistent loading via config:

```yaml
# .aider.conf.yml
read: [CONVENTIONS.md, STYLE_GUIDE.md]
```

### What Helps

- Simple bullet-pointed guidelines in CONVENTIONS.md
- Read-only mode enables prompt caching for performance
- Keep conventions short and actionable
- Community templates available at [github.com/Aider-AI/conventions](https://github.com/Aider-AI/conventions)

### What Causes Problems

- Loading conventions as editable chat files (wastes tokens, risks modification)
- Excessively detailed style guides that could be handled by linters
- API keys in YAML config limited to OpenAI and Anthropic (use .env for others)

### Context Window Impact

- Read-only files benefit from prompt caching when enabled
- Conventions loaded via `/read` are cached and not re-sent each turn

**Sources**: [Aider Conventions](https://aider.chat/docs/usage/conventions.html), [Aider YAML Config](https://aider.chat/docs/config/aider_conf.html), [Aider Configuration](https://aider.chat/docs/config.html)

---

## 7. OpenAI Codex

### Context Files

| File | Location | Purpose |
|------|----------|---------|
| `AGENTS.md` | `~/.codex/` | Global instructions |
| `AGENTS.override.md` | `~/.codex/` | Global override (takes precedence) |
| `AGENTS.md` | Repo root → CWD | Per-directory instructions |
| `AGENTS.override.md` | Any directory | Per-directory override |

### Discovery Order

1. **Global**: `~/.codex/AGENTS.override.md` → `~/.codex/AGENTS.md` (first non-empty wins)
2. **Project**: Walk from git root to CWD, one file per directory
3. **Merge**: Files concatenate root-downward, closer directories override

### Configuration

```toml
# ~/.codex/config.toml
project_doc_max_bytes = 32768  # 32 KiB default
project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
```

### Size Limits

- Default 32 KiB combined across all AGENTS.md files
- Empty files are skipped
- Discovery runs once per session (restart to rebuild)

### What Helps

- Global `~/.codex/AGENTS.md` for persistent cross-project conventions
- Nested overrides for monorepo service-specific rules
- `/init` command generates starter AGENTS.md

### What Causes Problems

- Exceeding 32 KiB silently truncates later files
- Override files can accidentally suppress important base instructions
- One file per directory limit means you can't compose multiple concerns

**Sources**: [Codex AGENTS.md Guide](https://developers.openai.com/codex/guides/agents-md), [Codex CLI Features](https://developers.openai.com/codex/cli/features)

---

## 8. Windsurf

### Context Files

| File | Status | Purpose |
|------|--------|---------|
| `.windsurfrules` | Legacy | Single project-wide rules |
| `.windsurf/rules/*.md` | Current | Modular workspace rules |
| Global rules (settings) | Active | Cross-project conventions |

### Rules System

- Workspace rules in `.windsurf/rules/` with glob patterns or natural language descriptions
- Global rules in user settings for cross-project standards
- **Hard limit**: 6,000 characters per rule file, 12,000 characters total (global + local combined)

### Loading Pipeline

Every Cascade interaction:
1. Load global rules
2. Load project `.windsurfrules` / `.windsurf/rules/`
3. Load relevant memories
4. Read open files
5. Run codebase retrieval
6. Read recent actions
7. Assemble final prompt

### What Helps

- Stack details: framework versions, language, major libraries
- Conventions: naming patterns, file organization, import styles
- Anti-patterns: explicit "never do X" statements
- Architecture: project structure with rationale
- Commit `.windsurfrules` to git for team standardization

### What Causes Problems

- Character limits force aggressive brevity (12K total is very tight)
- Stale rules worse than no rules — maintain actively
- Vague or overly long rules confuse Cascade

**Sources**: [Windsurf Docs](https://docs.windsurf.com/), [Windsurf Rules Guide](https://localskills.sh/blog/windsurf-rules-guide), [Windsurf Rules Directory](https://windsurf.com/editor/directory)

---

## 9. Google Gemini CLI: GEMINI.md

### Context Files

| File | Location | Purpose |
|------|----------|---------|
| `GEMINI.md` | `~/.gemini/` | Global instructions |
| `GEMINI.md` | CWD → git root (walk up) | Project instructions |
| `GEMINI.md` | Subdirectories (walk down) | Directory-scoped |

### Key Features

- **Hierarchical loading**: Global → project root → subdirectories, all concatenated
- **Import syntax**: `@./path/file.md` to include other files within GEMINI.md
- **Configurable filenames** via `settings.json`:

```json
{"context": {"fileName": ["AGENTS.md", "CONTEXT.md", "GEMINI.md"]}}
```

- **Memory commands**: `/memory show`, `/memory refresh`, `/memory add`
- Respects `.gitignore` and `.geminiignore` when scanning subdirectories

### What Helps

- Coding style guidelines with concrete examples
- Project-specific context that models can't infer
- Modular imports for large instruction sets

### What Causes Problems

- All discovered files concatenate for every prompt (no conditional loading)
- No documented size limit, but large concatenated contexts degrade performance

**Sources**: [Gemini CLI GEMINI.md Docs](https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html), [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)

---

## 10. Zed Editor

### Context Files

Zed supports multiple compatibility formats:
- `.rules` (native)
- `.cursorrules` (Cursor compatibility)
- `CLAUDE.md` (Claude Code compatibility)
- `AGENTS.md` (universal standard)

All are auto-included in Agent Panel interactions when placed at project root.

### Approach

Zed takes a **minimalist approach**: no automatic codebase indexing. Context is built explicitly through slash commands and file references, giving developers precise control over what enters the context window.

**Sources**: [Zed AI Rules](https://zed.dev/docs/ai/rules), [Zed AI Overview](https://zed.dev/docs/ai/overview)

---

## 11. JetBrains Junie

### Context Files

Discovery order:
1. Custom path (IDE settings)
2. `.junie/AGENTS.md` (preferred)
3. `AGENTS.md` (project root)
4. `.junie/guidelines.md` (legacy)
5. `.junie/guidelines/` (legacy directory)

### Additional Config

- `.junie/mcp/mcp.json` — MCP server configuration at project level
- Guidelines added to every task prompt as persistent context

**Sources**: [Junie Guidelines](https://www.jetbrains.com/help/junie/customize-guidelines.html), [Junie Guidelines and Memory](https://junie.jetbrains.com/docs/guidelines-and-memory.html)

---

## 12. Amazon Q Developer

### Context Files

| File | Purpose |
|------|---------|
| `.amazonq/rules/*.md` | Project rules (auto-loaded in chat) |
| `devfile.yaml` | Build/test environment configuration |
| Agent config files | Resource references with `file://` prefix |

### Rules

- Markdown files in `.amazonq/rules/` folder
- Automatically used as context in all chat sessions within the project
- Agent configuration can reference context files via `file://` URIs

### Devfile

- Must conform to devfile 2.2.0 schema
- Only `install`, `build`, and `test` commands supported
- 5-minute total timeout for all commands

**Sources**: [Amazon Q Project Rules](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/context-project-rules.html), [Amazon Q Context Management](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-context.html)

---

## 13. OpenHands / SWE-Agent

### OpenHands

| File | Purpose |
|------|---------|
| `AGENTS.md` (root) | Always-on repository instructions |
| `.openhands/microagents/repo.md` | Repository-specific microagent (auto-loaded by resolver) |
| `.openhands/microagents/*.md` | Repository-scoped microagents |
| `microagents/` | Public microagents (available to all users) |

**Microagent frontmatter**:

```yaml
---
name: "my-agent"
trigger_type: always | keyword | manual
keywords: ["deploy", "migration"]
---
```

### SWE-Agent

- Governed by a single YAML configuration file
- Custom Agent-Computer Interface (ACI) for browsing repositories
- No specific project-level context file — relies on the YAML config and the repository structure itself

**Sources**: [OpenHands Skills Overview](https://docs.openhands.dev/overview/skills), [OpenHands AGENTS.md](https://github.com/OpenHands/OpenHands/blob/main/AGENTS.md), [SWE-Agent Docs](https://swe-agent.com/latest/)

---

## 14. Devin

### Project Setup

- Reads `.github/PULL_REQUEST_TEMPLATE/devin_pr_template.md` for PR formatting
- Integrates with Slack and GitHub
- Cloud-based isolated VMs for parallel instances
- Supports AGENTS.md natively

### Knowledge Management

- **Permanent knowledge base**: Store essential testing procedures, framework guidance, project architecture
- Codify recurring mistakes and corrections into the agent's knowledge base
- Create custom CLI tools and scripts for reliable workflow execution
- Use MCP connections for external system integration

### Best Practices from Devin

- Align agent's environment exactly with team's (language versions, dependencies, automated checks)
- Pre-install tools like pre-commit hooks
- Use `.envrc` / `.bashrc` for automatic environment setup
- Provide access to CI, tests, types, and linters for self-correction
- Prefer typed languages (TypeScript > JavaScript)

**Sources**: [Devin Agents 101](https://devin.ai/agents101), [Devin Docs](https://docs.devin.ai/)

---

## 15. Ignore File Mechanisms

### By Tool

| Tool | Ignore File | Behavior |
|------|-------------|----------|
| Cursor | `.cursorignore` | Best-effort exclusion from AI features + indexing |
| Cursor | `.cursorindexingignore` | Indexing-only exclusion |
| Gemini CLI | `.geminiignore` | Exclude from subdirectory scanning |
| Windsurf | (uses `.gitignore`) | Respects git ignore patterns |
| Claude Code | (uses `.gitignore`) | Respects git ignore + `.claudeignore` |
| Aider | (uses `.gitignore`) | Respects git ignore for repo map |

### Pattern Syntax

All follow `.gitignore` syntax:
- `dist/` — directory exclusion
- `*.log` — extension exclusion
- `**/node_modules` — recursive directory
- `!important.log` — negation (re-include)

### Security Warning

`.cursorignore` is **best-effort only** — Cursor's documentation explicitly states that bugs may allow ignored files to be sent in certain cases. Do not rely on it as a security boundary for secrets.

### What to Ignore

- `node_modules/`, `vendor/`, `.venv/`
- Build output: `dist/`, `build/`, `.next/`
- Large generated files: lock files, compiled assets
- Sensitive files: `.env`, credentials, certificates
- Binary/media files the agent can't meaningfully process

---

## 16. Research: Do Context Files Actually Help?

### Study 1: AGENTS.md Efficiency (Jan 2026)

**Source**: [arxiv.org/html/2601.20404v1](https://arxiv.org/html/2601.20404v1)
**Method**: 10 repos, 124 PRs, OpenAI Codex (gpt-5.2-codex), paired design
**Findings**:
- Wall-clock time reduced **28.64%** (median)
- Output tokens reduced **16.58%** (median)
- AGENTS.md appeared to reduce exploratory navigation and planning iterations

### Study 2: ETH Zurich Critical Assessment (Feb–Mar 2026)

**Source**: [InfoQ coverage](https://www.infoq.com/news/2026/03/agents-context-file-value-review/)
**Method**: 4 models (Claude 3.5 Sonnet, GPT-5.2, GPT-5.1 mini, Qwen Code), 138 Python tasks
**Findings**:
- LLM-generated context files: **3% performance reduction** vs. no context
- Human-written files: **4% performance improvement**
- Both increased operational steps and costs by **19-20%**
- Agents followed instructions diligently but performed unnecessary tests and exploration

### Study 3: ConInstruct (AAAI 2026)

- Claude 4.5 Sonnet achieved 87.3% F1 in detecting instruction conflicts
- But models almost **never flagged contradictions** to users — they silently chose interpretations

### Study 4: PACIFIC / CodeIF-Bench

- As instruction chains lengthen, performance declines consistently
- Additional repository context actively degraded instruction-following ability across multi-turn sessions

### Emerging Consensus (March 2026)

- **Human-written context files targeting non-inferable details** (custom build systems, legacy constraints) offer measurable value
- **LLM-generated summaries** create counterproductive noise
- **Over-specification** is the most common failure mode
- Rule of thumb: "Treat every line like ad space — it has to justify its rent"
- One developer reduced 80+ aspirational rules to 30 failure-backed instructions with dramatically better results
- Vercel achieved 100% pass rates by compressing documentation into an 8KB index

**Sources**: [Augment Code Blog](https://www.augmentcode.com/blog/your-agents-context-is-a-junk-drawer), [Allstacks AGENTS.md Analysis](https://www.allstacks.com/blog/agents.md-files-the-research-says-youre-probably-doing-them-wrong)

---

## 17. Agent-Friendly Project Structure

### Published Recommendations

#### From Ben Houston (Agentic Coding Best Practices)

1. **Flatten directory structures** — semantic naming over deep nesting
2. **Co-locate related files** — component + test + types + utils together
3. **Consistent naming patterns** — agents predict locations based on convention
4. **Eliminate re-exports and indirection** — no chained index.ts files
5. **Prefer compile-time over runtime validation** — TypeScript discriminated unions > convention-based patterns
6. **Type-driven development** — comprehensive types = built-in documentation
7. **Treat agent mistakes as signals** — unclear structure confuses agents like it confuses new hires

#### From Monorepo.tools / Nx

1. **Minimize package explosion** — 3-5 core units (frontend, backend, shared), not per-feature packages
2. **Consolidate root-level configuration** — one source of truth for lint/format
3. **Avoid configuration inheritance chains** — self-contained configs per package
4. **Use project graph** — tools like Nx provide structured metadata agents can query
5. **Architectural tagging** — domain-level tags for progressive codebase exploration
6. **One canonical set of agent instructions** at monorepo root level

#### From Devin / Autonomous Agents

1. **Typed languages preferred** — TypeScript over JavaScript, typed Python over plain
2. **Pre-configured environments** — `.envrc`, `.bashrc` for automatic setup
3. **CI/test/lint access** — agents need feedback loops to self-correct
4. **Custom scripts** — CLI tools that surface actionable information
5. **Explicit completion criteria** — break complex tasks into well-scoped steps
6. **Enhanced test coverage** in AI-modified areas

### The "Agent-Friendly Monorepo" Pattern

```
project-root/
  AGENTS.md                    # Universal agent instructions
  CLAUDE.md                    # Claude-specific (if needed)
  .cursor/rules/               # Cursor-specific scoped rules
  .github/copilot-instructions.md  # Copilot instructions
  package.json / pyproject.toml
  apps/
    frontend/
      AGENTS.md                # Frontend-specific overrides
      src/
    backend/
      AGENTS.md                # Backend-specific overrides
      src/
  packages/
    shared/
      AGENTS.md                # Shared lib conventions
      src/
```

**Sources**: [Agentic Coding Best Practices](https://benhouston3d.com/blog/agentic-coding-best-practices), [Monorepo.tools AI](https://monorepo.tools/ai), [Nx AI Agent Skills](https://nx.dev/blog/nx-ai-agent-skills), [Context Driven Development](https://medium.com/@pravir.raghu/context-driven-development-how-a-ai-guided-monorepo-goes-from-zero-to-production-hero-in-a-few-e921f75ab977)

---

## 18. Cross-Tool Compatibility Matrix

### Which Files Each Tool Reads

| Tool | Native File | Also Reads |
|------|------------|------------|
| Claude Code | `CLAUDE.md` | `AGENTS.md` (fallback) |
| Codex CLI | `AGENTS.md` | `AGENTS.override.md` |
| Cursor | `.cursor/rules/*.mdc` | `AGENTS.md`, `.cursorrules` (legacy) |
| Windsurf | `.windsurf/rules/*.md` | `.windsurfrules` (legacy) |
| GitHub Copilot | `.github/copilot-instructions.md` | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` |
| Gemini CLI | `GEMINI.md` | Configurable (`AGENTS.md`, `CONTEXT.md`) |
| Cline | `.clinerules/` | `.cursorrules`, `.windsurfrules`, `AGENTS.md` |
| Roo Code | `.roo/rules/` | `AGENTS.md`, `AGENT.md` |
| Aider | `CONVENTIONS.md` | `AGENTS.md` (community support) |
| Zed | `.rules` | `.cursorrules`, `CLAUDE.md`, `AGENTS.md` |
| Junie | `.junie/AGENTS.md` | `AGENTS.md`, `.junie/guidelines.md` |
| Amazon Q | `.amazonq/rules/*.md` | `devfile.yaml` |
| OpenHands | `AGENTS.md` | `.openhands/microagents/` |
| Devin | `AGENTS.md` | `.github/PULL_REQUEST_TEMPLATE/devin_pr_template.md` |

### Minimum Viable Multi-Tool Setup

For teams using multiple AI tools, the recommended strategy:

1. **`AGENTS.md`** at project root — widest cross-tool support
2. Tool-specific supplements only where needed (e.g., Cursor glob-scoped rules, Copilot path-specific instructions)
3. Keep a single source of truth; avoid duplicating content across files

---

## 19. Key Takeaways & Recommendations

### Context File Strategy

1. **Start with AGENTS.md** — it has the widest adoption and is an open standard under Linux Foundation governance
2. **Keep files short** — under 300 lines for CLAUDE.md, under 8KB total for best results
3. **Only include non-inferable information** — custom build commands, legacy constraints, team conventions the agent can't see in code
4. **Delete rules that don't prevent actual mistakes** — aspirational guidelines waste tokens
5. **Use conditional/scoped rules** where available (Cursor, Cline, Copilot) to minimize per-request token load
6. **Never duplicate linter/formatter rules** — use deterministic tools instead
7. **Review and prune regularly** — stale rules are worse than no rules

### Ignore File Strategy

1. Exclude build output, vendor directories, large generated files
2. Don't rely on `.cursorignore` as a security boundary
3. Target files that create noise without helping agents understand the codebase

### Project Structure

1. Flatten directory hierarchies with semantic naming
2. Co-locate related files (component + test + types)
3. Eliminate re-exports and deep import chains
4. Use typed languages for better agent comprehension
5. Self-contained package configs over inheritance chains
6. Ensure agents can run CI/test/lint for self-correction feedback

### The Efficiency Paradox

Research shows context files make agents more thorough (more steps, more tests, more exploration) but not necessarily more successful. The sweet spot is minimal, targeted instructions that save exploration time without triggering unnecessary thoroughness.

---

## 20. Sources

### Official Documentation
- [AGENTS.md Specification](https://agents.md/)
- [Cursor Rules for AI](https://docs.cursor.com/context/rules-for-ai)
- [Cursor Ignore Files](https://docs.cursor.com/context/ignore-files)
- [GitHub Copilot Custom Instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
- [Cline Rules](https://docs.cline.bot/features/cline-rules)
- [Roo Code Custom Instructions](https://docs.roocode.com/features/custom-instructions)
- [Aider Conventions](https://aider.chat/docs/usage/conventions.html)
- [Aider YAML Config](https://aider.chat/docs/config/aider_conf.html)
- [Codex AGENTS.md Guide](https://developers.openai.com/codex/guides/agents-md)
- [Windsurf Docs](https://docs.windsurf.com/)
- [Gemini CLI GEMINI.md](https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html)
- [Zed AI Rules](https://zed.dev/docs/ai/rules)
- [Junie Guidelines](https://www.jetbrains.com/help/junie/customize-guidelines.html)
- [Amazon Q Project Rules](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/context-project-rules.html)
- [OpenHands Skills](https://docs.openhands.dev/overview/skills)
- [Devin Agents 101](https://devin.ai/agents101)

### Research Papers
- [On the Impact of AGENTS.md Files on AI Coding Agent Efficiency (Jan 2026)](https://arxiv.org/html/2601.20404v1)
- [Configuring Agentic AI Coding Tools: An Exploratory Study (Feb 2026)](https://arxiv.org/html/2602.14690)
- [Codified Context: Infrastructure for AI Agents in a Complex Codebase (Feb 2026)](https://arxiv.org/html/2602.20478v1)

### Analysis & Guides
- [AGENTS.md Emerges as Open Standard (InfoQ)](https://www.infoq.com/news/2025/08/agents-md/)
- [New Research Reassesses AGENTS.md Value (InfoQ, Mar 2026)](https://www.infoq.com/news/2026/03/agents-context-file-value-review/)
- [Your Agent's Context Is a Junk Drawer (Augment Code)](https://www.augmentcode.com/blog/your-agents-context-is-a-junk-drawer)
- [AGENTS.md Files: You're Probably Doing Them Wrong (Allstacks)](https://www.allstacks.com/blog/agents.md-files-the-research-says-youre-probably-doing-them-wrong)
- [Agentic Coding Best Practices (Ben Houston)](https://benhouston3d.com/blog/agentic-coding-best-practices)
- [Monorepos & AI](https://monorepo.tools/ai)
- [Nx AI Agent Skills](https://nx.dev/blog/nx-ai-agent-skills)
- [Will AI Turn 2026 into the Year of the Monorepo? (Spectro Cloud)](https://www.spectrocloud.com/blog/will-ai-turn-2026-into-the-year-of-the-monorepo)
- [CLAUDE.md, AGENTS.md, and Every AI Config File Explained (DeployHQ)](https://www.deployhq.com/blog/ai-coding-config-files-guide)
- [Writing a Good CLAUDE.md (HumanLayer)](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [Builder.io CLAUDE.md Guide](https://www.builder.io/blog/claude-md-guide)
- [5 Tips for Copilot Custom Instructions (GitHub Blog)](https://github.blog/ai-and-ml/github-copilot/5-tips-for-writing-better-custom-instructions-for-copilot/)
- [Complete Guide to AI Agent Memory Files (Medium)](https://medium.com/data-science-collective/the-complete-guide-to-ai-agent-memory-files-claude-md-agents-md-and-beyond-49ea0df5c5a9)
