# Distiller Subagent Prompt

Prompt template for the Phase 4 architecture distiller. Use an Opus subagent
for this — it requires synthesis and judgment, not just extraction.
Fill in all [PLACEHOLDERS] before spawning.

---

```
You are distilling a parent project's context into a self-contained
architecture.md for a sub-project. This is the most critical file in the
sub-project — it must contain almost everything Claude needs to complete the
build without frequently consulting the parent.

## Inputs

- Sub-project name: [SUB_PROJECT_NAME]
- Sub-project path: [SUB_PROJECT_PATH]
- Task description: [TASK_DESCRIPTION]
- Parent root: [PARENT_ROOT]

Read these files from the parent (if they exist):
- [PARENT_ROOT]/project-context.md
- [PARENT_ROOT]/architecture.md
- [PARENT_ROOT]/project-plan.md

If any or all parent docs are absent, rely entirely on the analyzer output and
interview answers. Do not reference missing files or create placeholder sections.
The analyzer extracts everything directly from code — parent docs are a shortcut,
not a requirement.

Read the analyzer output:
[ANALYZER_OUTPUT_CONTENT]

Read the user's interview answers:
[INTERVIEW_ANSWERS]

## Output

Write [SUB_PROJECT_PATH]/architecture.md with exactly these 11 sections:

### 1. Project Overview
One paragraph: what this sub-project builds, why it exists, and its
relationship to the parent project. Include the merge-back strategy
(subdirectory or worktree) and timeline if known.

### 2. Tech Stack
Languages, frameworks, and versions. Copy exactly from the parent — do not
summarize or abbreviate version numbers. Include only what this sub-project
actually uses.

### 3. Architecture
Major components and their relationships. Include a text diagram if the
architecture has more than 3 components. Show how this sub-project's
components connect to parent components.

### 4. Directory Structure
Annotated tree of the sub-project with key files explained. Include parent
directories that this sub-project interacts with.

### 5. API Surface
Full interface definitions, type signatures, and exported contracts that this
sub-project consumes from the parent OR produces for the parent. Include
complete type definitions — abbreviated types cause implementation errors.

### 6. Cross-Cutting Concerns
Only concerns relevant to this sub-project:
- Auth: how authentication/authorization works if this sub-project touches it
- Logging: logging patterns, structured logging format, log levels
- DB: schema for tables this sub-project reads/writes, migration patterns
- Design tokens: if this is a UI sub-project, include token definitions
- Error handling: error types, error propagation patterns
- Environment variables: which env vars this sub-project needs

### 7. Coding Conventions
Style rules with CODE EXAMPLES from the parent. Don't just say "use camelCase"
— show a 5-10 line example of a typical function in this codebase. Include:
- Naming patterns (files, functions, variables, types)
- Error handling pattern (try/catch style, Result type, error codes)
- Import ordering

**Testing** (required subsection):
- Test file structure: co-located (`foo.test.ts`) or separate (`__tests__/`)
- Test runner and assertion library
- Mocking patterns (jest.mock, vitest vi.mock, testdouble, etc.)
- Coverage expectations (threshold, which metrics)
- Test naming convention with example

### 8. Commands
Build, test, lint commands with FULL FLAGS. Adapt paths for the sub-project
directory. Include:
- How to run just this sub-project's tests
- How to build just this sub-project
- How to lint just this sub-project
- How to run the full parent test suite (for integration verification)

### 9. Known Constraints
Performance requirements, security rules, compatibility requirements,
browser support, API rate limits — anything that constrains implementation.
Also include merge-back guidance:
- Run integration tests from parent root before merging
- Check for convention drift with /compliance-review
- Update parent's project-plan.md after merge
- Clean up worktree/branch if applicable

### 10. Parent Dependencies
Explicit table of what this sub-project imports from the parent:

| Import | Source File | Type | Notes |
|--------|------------|------|-------|
| UserType | src/types/user.ts | Type | Used in auth checks |
| dbConnect | src/db/connection.ts | Function | Shared DB pool |

Include file paths relative to parent root. Note any version constraints.

### 11. Parent Modifications
Explicit list of parent files this sub-project will modify. Leave empty
(with "None — sub-project is purely additive") if no parent modifications
are needed.

| Parent File | Modification | Reason |
|-------------|-------------|--------|
| src/db/migrations/ | Add new migration | New tables for sub-project |
| src/types/index.ts | Extend UserType | Add sub-project-specific fields |

Include the nature of each change so merge-back reviewers know what to expect.

## Quality Rules

- NO placeholders ("TBD", "see parent", "to be determined")
- NO abbreviated types — include full definitions
- NO vague references — use exact file paths
- Include enough context that a fresh Claude session could implement the
  sub-project build plan without reading the parent project
- Target 70-98% compression of parent context while preserving all
  information relevant to this sub-project's scope
- When in doubt, include more rather than less — it's better to have
  unused context than missing context
```
