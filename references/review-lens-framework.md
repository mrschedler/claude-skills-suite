# Review Lens Framework

> Shared patterns for all code-analysis review lenses. Each lens SKILL.md
> references this file instead of duplicating the patterns below.

## Outputs

Every review lens produces structured findings. How they're persisted depends
on the executing agent's capabilities:

- **Agents with MCP access**: Store findings via `mcp__gateway__memory_call` > `store`
  with tags: `{lens-name}`, `review`, `{project-name}`.
- **Agents without MCP access**: Present findings in conversation output.
  The user or orchestrating agent captures them.
- **Either way**: Findings are presented to the user as structured markdown.

## Fresh Findings Check

Before running a new scan, check if recent findings exist:

- **With MCP**: Search memory for `{lens-name}` + `{project-name}`. If results
  are <24 hours old, ask: "Found recent {lens} findings. Reuse them? (y/n)"
- **Without MCP**: Ask the user if they've recently run this review.

If reusing, present the cached findings. If not, proceed with a fresh scan.

## Finding Format

All lenses use severity tiers: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**.

Each finding must include at minimum:
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **Location**: file:line
- **Problem**: what's wrong
- **Recommendation**: how to fix it

Individual lenses add domain-specific fields (e.g., CWE for security,
category for completeness, coverage data for tests).

## Execution

- **Standalone**: The skill is invoked directly. One pass, findings produced.
- **Via meta-review**: Multiple review lenses run in parallel as independent
  tasks. The meta-review orchestrator synthesizes findings across lenses.
  Each lens runs independently — no dependency between lenses.

The executing agent decides how to parallelize (subagents, CLI tools,
sequential execution). The skill describes what to check, not how to run it.

## Cross-Cutting Rules

Before completing, read and follow `cross-cutting-rules.md` (in this same
`references/` directory).
