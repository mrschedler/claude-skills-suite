# Analyzer Subagent Prompt

Prompt template for the Phase 1 parent project analyzer.
Fill in [PARENT_ROOT], [SUB_PROJECT_NAME], and [TASK_DESCRIPTION] before spawning.

---

```
You are analyzing a parent project to extract context for a sub-project.

## Task

Analyze the parent project at [PARENT_ROOT] to extract everything relevant
to this sub-project:

- Sub-project name: [SUB_PROJECT_NAME]
- Task description: [TASK_DESCRIPTION]

## What to Extract

1. **Dependency Graph**: Use Grep and Glob to trace imports/exports related
   to the sub-project's task. Map which modules depend on which. Focus on
   modules the sub-project will consume or produce.

2. **Tech Stack**: Read package.json, Cargo.toml, go.mod, pyproject.toml,
   or equivalent. Extract languages, frameworks, versions.

3. **API Surface**: Find interfaces, types, and exported functions that the
   sub-project will interact with. Include full type signatures.

4. **Shared Types**: Find type definitions used across module boundaries.
   Include the full definitions, not just names.

5. **Build/Test/Lint Commands**: Read package.json scripts, Makefile,
   Taskfile, or CI config. Extract commands with full flags.

6. **Coding Conventions**: Check linting configs (.eslintrc, .prettierrc,
   rustfmt.toml, etc.). Read 2-3 representative source files to identify
   patterns (naming, error handling, logging, etc.).

7. **Cross-Cutting Concerns**: Identify auth patterns, logging setup, DB
   schema/migrations, design tokens, shared middleware, env var patterns.

8. **Directory Structure**: Produce an annotated tree of the parent project
   focused on areas relevant to the sub-project.

## Monorepo Tool Optimization

If `nx.json` exists, prefer `nx graph --file=/tmp/nx-graph.json` for dependency
analysis over manual import tracing. If `turbo.json` exists, prefer
`turbo run build --filter=<relevant-package> --dry-run=json` for task graph.
These are faster and more accurate than Grep-based tracing. Fall back to
manual analysis if the tools are not installed.

## What to Skip

- Files unrelated to the sub-project's task
- Test fixtures and mock data (unless directly relevant)
- Build artifacts, node_modules, vendor directories
- Git history (the distiller handles historical context)

## Output Format

Write your findings as a single markdown document to stdout. Use this structure:

```markdown
# Parent Analysis for [SUB_PROJECT_NAME]

## Tech Stack
[languages, frameworks, versions]

## Dependency Graph
[relevant modules and their relationships, as a text diagram or table]

## API Surface
[interfaces, types, exported functions — full signatures]

## Shared Types
[type definitions used across boundaries]

## Commands
[build, test, lint with full flags]

## Coding Conventions
[naming, error handling, logging patterns with examples]

## Cross-Cutting Concerns
[auth, logging, DB, design tokens — relevant details only]

## Directory Structure
[annotated tree focused on sub-project-relevant areas]
```

Be thorough but focused. Include full type signatures and function signatures
— the distiller needs exact details, not summaries. Skip anything unrelated
to the sub-project's scope.
```
