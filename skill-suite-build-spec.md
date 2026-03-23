# Project Skill Suite — Build Spec v2

> This document defines a complete skill suite for project lifecycle management.
> Build all skills, meta-skills, hooks, templates, and references described below.
> Target location: a shared folder accessible across multiple machines.

## Architecture Overview

- **25 atomic skills** — each does one thing well, has its own SKILL.md
- **4 meta-skill orchestrators** — chain atomic skills, manage parallel fan-out
- **5 Claude Code hooks** — deterministic, guaranteed execution on lifecycle events
- **2 utility skills** (`/gemini`, `/codex`) — encode exact CLI syntax so other skills don't guess
- **Multi-model reviews** — 7 review lenses × 3 model families (Sonnet + Codex + Gemini) = 21 parallel reviews
- **Agent-agnostic skills** — SKILL.md follows the open Agent Skills standard (Claude Code, Cursor, Gemini CLI, Codex CLI, Copilot)
- **Claude Code hooks** — hooks are Claude Code specific
- **Subagent defaults**: Sonnet, high effort. For non-Claude agents, instruct "use highest available reasoning effort"
- **Codex worker pool**: max 5 concurrent `codex exec` sessions at any time
- **Cross-device**: skills live in a shared folder, templates use relative paths

## Skill Writing Rules

Follow these rules when writing every SKILL.md:

1. YAML frontmatter: `name` and `description` are required. Description is the primary trigger — write it in third person, be "pushy" about when to use it, include specific trigger phrases.
2. Keep SKILL.md body under 2,000 words (~500 lines). Use `references/` for overflow. This is progressive disclosure — metadata always loaded, SKILL.md on trigger, references on demand.
3. Explain the "why" behind instructions instead of heavy-handed MUSTs/NEVERs.
4. Use imperative form for instructions.
5. Include 2-4 `<example>` blocks showing different trigger scenarios:
   ```
   <example>
   Context: [Situation]
   user: "[Exact user message]"
   assistant: "[Response before triggering]"
   <commentary>[Why this triggers the skill]</commentary>
   </example>
   ```
6. Every atomic skill must work standalone AND as part of a meta-skill chain.
7. Every skill must include the cross-cutting footer (see Cross-Cutting Rules section).
8. Define clear exit conditions so chains know when to advance.
9. Files are the handoff mechanism between skills — each skill produces .md artifacts the next skill consumes.
10. Skills that use Codex or Gemini must reference the `/codex` or `/gemini` utility skills for exact CLI syntax — never inline the commands. Include a `## Multi-Model Execution` section specifying: task type, prompt template, output file path, and fallback behavior.

## Folder Structure to Create

```
shared-skills-folder/
├── atomic/
│   ├── project-scaffold/
│   │   ├── SKILL.md
│   │   └── templates/
│   │       ├── coterie-template.md
│   │       ├── cnotes-template.md
│   │       ├── todo-template.md
│   │       ├── features-template.md
│   │       ├── codex-instructions-template.md
│   │       ├── gemini-instructions-template.md
│   │       └── gitignore-template
│   ├── repo-create/
│   │   └── SKILL.md
│   ├── project-questions/
│   │   └── SKILL.md
│   ├── project-context/
│   │   ├── SKILL.md
│   │   └── templates/
│   │       └── context-template.md
│   ├── research-plan/
│   │   └── SKILL.md
│   ├── research-execute/
│   │   └── SKILL.md
│   ├── build-plan/
│   │   ├── SKILL.md
│   │   └── templates/
│   │       └── plan-template.md
│   ├── github-sync/
│   │   └── SKILL.md
│   ├── evolve-context/
│   │   └── SKILL.md
│   ├── evolve-plan/
│   │   └── SKILL.md
│   ├── todo-features/
│   │   └── SKILL.md
│   ├── meta-compact/
│   │   └── SKILL.md
│   ├── meta-clear/
│   │   └── SKILL.md
│   ├── counter-review/
│   │   └── SKILL.md
│   ├── security-review/
│   │   └── SKILL.md
│   ├── test-review/
│   │   └── SKILL.md
│   ├── refactor-review/
│   │   └── SKILL.md
│   ├── drift-review/
│   │   └── SKILL.md
│   ├── completeness-review/
│   │   └── SKILL.md
│   ├── compliance-review/
│   │   └── SKILL.md
│   ├── gemini/
│   │   └── SKILL.md
│   ├── codex/
│   │   ├── SKILL.md
│   │   └── schemas/
│   │       └── review-findings-schema.json
│   ├── skill-doctor/
│   │   └── SKILL.md
│   ├── release-prep/
│   │   └── SKILL.md
│   └── browser-review/
│       └── SKILL.md
├── meta/
│   ├── project-init/
│   │   └── SKILL.md
│   ├── project-review/
│   │   └── SKILL.md
│   ├── project-evolve/
│   │   └── SKILL.md
│   └── project-execute/
│       └── SKILL.md
├── hooks/
│   ├── stop-check.sh
│   ├── pre-compact-safety.sh
│   ├── session-start-compact.sh
│   ├── session-start-clear.sh
│   └── session-start-startup.sh
└── references/
    ├── cross-cutting-rules.md
    ├── evolve-context-diff.md
    └── evolve-plan-diff.md
```

## Generated Project Structure

When `project-scaffold` runs, it creates this in the project root:

```
project-root/
├── coterie.md              # Coterie rules for all agents
├── CODEX.md               # Codex CLI project instructions
├── GEMINI.md              # Gemini CLI project instructions
├── cnotes.md              # Running session notes / decision log
├── compact/
│   ├── claude-compact.md  # Claude context preservation (overwritten by meta-compact/meta-clear)
│   └── codex-compact.md   # Codex context preservation (written by Codex before session ends)
├── project-context.md     # Cold-start context doc (written by project-context skill)
├── project-plan.md        # Full project plan (written by build-plan skill)
├── todo.md                # Current action items
├── features.md            # Feature backlog + status
├── .gitignore
├── research/
│   ├── research_plan.md
│   ├── research_synthesis.md
│   ├── topic-[name].md
│   └── runs/
│       ├── 001/
│       │   ├── consensus_findings.md
│       │   ├── scholar-gateway_findings.md
│       │   ├── huggingface_findings.md
│       │   ├── synapse_findings.md
│       │   ├── context7_findings.md
│       │   ├── web-1_findings.md
│       │   ├── web-2_findings.md
│       │   ├── web-3_findings.md
│       │   ├── github-1_findings.md
│       │   ├── github-2_findings.md
│       │   ├── sonnet_counter.md
│       │   ├── gemini_counter.md
│       │   └── codex_counter.md
│       └── 002/ ...
├── docs/
│   ├── counter-review-findings.md       # Standalone run output (Sonnet only)
│   ├── security-review-findings.md
│   ├── test-review-findings.md
│   ├── refactor-review-findings.md
│   ├── drift-review-findings.md
│   ├── completeness-review-findings.md
│   ├── compliance-review-findings.md
│   ├── [lens]-review-sonnet.md          # Per-model intermediate files
│   ├── [lens]-review-codex.md           #   (created during project-review
│   ├── [lens]-review-gemini.md          #    multi-model execution)
│   └── review-synthesis.md              # Unified cross-lens findings
└── src/ ...
```

---

## Cross-Cutting Rules

Create `references/cross-cutting-rules.md` with the following content. Every atomic SKILL.md must include a footer that says: "Before completing, read and follow `../references/cross-cutting-rules.md`."

The cross-cutting rules are:

1. Follow coterie.md — check and respect coterie rules in the project root. coterie.md uses a structured note schema with author delimiters, note IDs (`CN-YYYYMMDD-HHMMSS-AUTHOR`), and 13 required fields. See the coterie-template.md for the full schema.
2. Log to cnotes.md — notable decisions, context changes, and rationale. (Also enforced by Stop hook, but skills should do this proactively.)
3. Update todo.md — any new action items discovered during execution.
4. Update features.md — any feature changes or discoveries.

---

## Atomic Skills — Specifications

### 1. project-scaffold

- **Phase**: Initialization
- **Purpose**: Create folder structure and standard files from bundled templates. Sets up coterie.md, cnotes.md, todo.md, features.md, compact/ (with empty claude-compact.md and codex-compact.md), /research/, /docs/, /src/.
- **Inputs**: Project name, shared folder templates (bundled in templates/)
- **Outputs**: All standard files and folders in project root
- **Exit condition**: All files and folders exist
- **Subagent**: No
- **Templates to bundle**: coterie-template.md, cnotes-template.md, todo-template.md, features-template.md, codex-instructions-template.md, gemini-instructions-template.md, gitignore-template
- **Notes**: The coterie-template.md must include the structured note schema with author delimiters (CODEX, CLAUDE, GEMINI, COPILOT), note ID format (`CN-YYYYMMDD-HHMMSS-AUTHOR`), and all 13 required fields (note_id, timestamp_utc, author, activity_type, work_scope, files_touched, files_reviewed, summary, details, validation, risks_or_gaps, handoff_to, next_actions). Include rules about: communication style, code standards, commit message format, when to ask vs when to act, and a pointer to cross-cutting-rules.md. The cnotes-template.md should start with a header and date format convention but otherwise be empty. The todo and features templates should have column headers / structure but no content.

### 2. repo-create

- **Phase**: Initialization
- **Purpose**: Prompt user about GitHub repo. "Do you already have a repo? Want me to create one? What should it be named?" Ask about visibility (public/private) each time. Create the repo, connect it, push initial commit.
- **Inputs**: User preferences (name, visibility), existing project folder
- **Outputs**: Initialized git repo, .gitignore, remote origin set
- **Exit condition**: Repo exists on GitHub, local connected, initial commit pushed
- **Subagent**: No
- **Notes**: Use standard git CLI, not agent-specific integrations. Must be conditional — if user already has a repo, just connect to it. Never assume.

### 3. project-questions

- **Phase**: Initialization
- **Purpose**: Interactive deep-dive interview. Ask probing questions about the project. Poke holes in assumptions. Challenge gaps. Keep going until the model is satisfied it understands the project thoroughly — not just the surface but the why, constraints, edge cases, and context.
- **Inputs**: User's initial project description
- **Outputs**: Raw context dump (stays in conversation, consumed by project-context skill)
- **Exit condition**: Model is satisfied — no more fundamental gaps in understanding
- **Subagent**: No
- **Gemini integration**: Before starting questions, call `/gemini` (task type: research) to web-ground the user's domain. This gives the interviewer better context for probing questions. Write findings to a temp file, read it, then begin the interview.
- **Notes**: This skill should be aggressive about finding gaps. Ask about target users, constraints, non-goals, tech preferences, timeline, prior art, and anything the user hasn't mentioned. Explicitly poke holes: "What happens if X? Have you considered Y? What's your fallback for Z?" This is the "clarifying questions phase" — DO NOT SKIP. Ambiguity caught here saves rework later.

### 4. project-context

- **Phase**: Initialization
- **Purpose**: Write the comprehensive project context doc that any agent can cold-start from. This is the single most important handoff artifact in the entire suite. It also serves as the onboarding doc for new contributors and agents.
- **Inputs**: Context gathered from project-questions phase
- **Outputs**: project-context.md in project root
- **Exit condition**: project-context.md written and user approves
- **Subagent**: No
- **Template to bundle** (`context-template.md`):

```markdown
# [Project Name] — Project Context

> Last updated: [date]
> Status: [planning | active development | maintenance | paused]

## What Is This?
[1-2 sentences. What the project is and does.]

## Problem Statement
[What problem does this solve? Why does it need to exist?]

## Target Users
[Who uses this? What are their needs?]

## Non-Goals
[What this project explicitly does NOT try to do.]

## Tech Stack
[Languages, frameworks, services, infrastructure]

## Architecture Overview
[High-level component relationships. Brief — link to detailed docs if needed.]

## Project Structure
[Key folders and their purpose]

## Key Decisions
[Decision, rationale, date. Most recent first.]
| Decision | Rationale | Date |
|----------|-----------|------|

## Current State
- **Done**: [completed milestones]
- **In Progress**: [active work]
- **Blocked**: [what's stuck and why]
- **Next Up**: [planned next steps]

## Constraints
[Budget, timeline, regulatory, technical limitations]

## Open Questions
[Unresolved decisions that need input]

## Glossary
[Project-specific terms]
```

- **Notes**: The context doc must include the "why" behind decisions, not just the "what." Decisions without rationale get second-guessed by agents. Keep it under ~200 lines — if longer, use progressive disclosure (summary at top, details linked). This is a living document — the evolve-context skill updates it over time.

### 5. research-plan

- **Phase**: Initialization
- **Purpose**: Analyze project context, existing code, and existing research. Build a prioritized research plan. Categorize each topic as academic, code, or both. Map each topic to specific research connectors. Self-counter: after creating the plan, explicitly challenge yourself — "Am I sure nothing is missing?"
- **Inputs**: project-context.md, existing code (if any), existing research (if any)
- **Outputs**: /research/research_plan.md
- **Exit condition**: research_plan.md written with topic-to-connector mapping, self-countered, user approves scope
- **Subagent**: No
- **Notes**: The research plan should categorize each topic and map it to connectors:
  - **Academic lane**: Consensus, Scholar Gateway, Synapse.org, PubMed, Clinical Trials
  - **Code lane**: Context7, GitHub (API), Microsoft Learn
  - **Both**: Hugging Face, Web Search
  - Topics can be tagged with multiple lanes. The mapping determines which subagents research which topics in research-execute.

### 6. research-execute

- **Phase**: Research
- **Purpose**: Execute the research plan by fanning out 10 Sonnet subagents (one per connector), compiling synthesis, then running a triple-counter with 3 model families (Sonnet, Gemini, Codex) to challenge completeness from different perspectives.
- **Inputs**: /research/research_plan.md, project-context.md
- **Outputs**: /research/runs/NNN/[connector]_findings.md, /research/topic-[name].md, /research/research_synthesis.md, counter files
- **Exit condition**: All connectors returned, synthesis compiled, triple-counter complete, user informed of any gaps
- **Subagent**: 10 research (Sonnet) + 1 Sonnet counter + Gemini CLI counter + Codex CLI counter
- **Agent allocation**:

| # | Connector | Lane | Focus |
|---|-----------|------|-------|
| 1 | Consensus | academic | Peer-reviewed papers |
| 2 | Scholar Gateway | academic | Academic literature semantic search |
| 3 | Hugging Face | both | ML papers + models + docs |
| 4 | Synapse.org | academic | Scientific/biomedical data |
| 5 | Context7 | code | Library/framework documentation |
| 6 | Web Search 1 | both | General research (topics batch 1) |
| 7 | Web Search 2 | both | General research (topics batch 2) |
| 8 | Web Search 3 | both | General research (topics batch 3) |
| 9 | GitHub API 1 | code | Code search, repos (batch 1) |
| 10 | GitHub API 2 | code | Code search, repos (batch 2) |

- **Execution flow**:
  1. Fan out Sonnet subagents in parallel — one per connector that has assigned topics in research_plan.md. Skip connectors with zero mapped topics (e.g., PubMed/Clinical Trials for non-biomedical projects). Each subagent gets its assigned topics and connector.
  2. Each subagent writes [connector]_findings.md into research/runs/NNN/. Files are the handoff — not context.
  3. Main agent reads raw files one at a time. Compiles per-topic synthesis (research/topic-[name].md) and master synthesis (research/research_synthesis.md).
  4. **Triple-counter** — fan out 3 counter-reviewers in parallel:
     - **Sonnet subagent**: Fresh eyes, no context bleed. Reads only the synthesis. Challenges completeness, flags gaps. Writes `sonnet_counter.md`.
     - **Gemini CLI** (per `/gemini` skill, task type: counter-review): Different model family. Web-grounded fact check. Challenges claims lacking evidence, missing perspectives, ignored contradictions. Pipe synthesis via stdin. Writes `gemini_counter.md`.
     - **Codex CLI** (per `/codex` skill, task type: read-only review): Code-focused feasibility check. Challenges implementation gaps, unvalidated libraries, missing technical details. Writes `codex_counter.md`.
  5. Main agent reads all 3 counter files. Compares findings across model families. Multi-model agreement on a gap = high confidence it's real. Updates synthesis if gaps are real. Asks user if additional research run (002, 003...) is needed.
- **Run numbering**: Sequential — 001, 002, 003. Each run gets its own folder under research/runs/.
- **Fallback**: If Gemini/Codex unavailable, note "External counter skipped — [CLI] unavailable" and proceed with Sonnet counter only. If subagents are unavailable entirely, execute sequentially — one connector at a time, same file outputs.

### 7. build-plan

- **Phase**: Planning
- **Purpose**: Take project context + research synthesis and generate a full project plan with phases, milestones, technical approach, and implementation order. Decompose into work units suitable for parallel execution.
- **Inputs**: project-context.md, /research/research_synthesis.md (if research-execute was run, otherwise work from context alone)
- **Outputs**: project-plan.md in project root
- **Exit condition**: project-plan.md written and user approves
- **Subagent**: No
- **Gemini integration**: Call `/gemini` (task type: research) for competitive landscape and similar project approaches. Write findings to temp file, incorporate into plan.
- **Codex integration**: Call `/codex` (task type: read-only review) for technical feasibility check on proposed architecture. Write findings to temp file, incorporate into plan.
- **Template to bundle**: plan-template.md with sections for phases, milestones, technical approach, work unit decomposition, dependencies, risks, and timeline. Each work unit should be tagged as parallelizable or sequential.

### 8. github-sync

- **Phase**: Ongoing
- **Purpose**: Push/pull changes to GitHub. Commit with meaningful messages. Handle branches if needed. Standard git CLI.
- **Inputs**: Current working tree, commit context
- **Outputs**: Committed and pushed changes
- **Exit condition**: Changes committed and pushed, working tree clean
- **Subagent**: No
- **Notes**: Also called as the first step of meta-clear before clearing context.

### 9. evolve-context

- **Phase**: Ongoing (manually triggered)
- **Purpose**: Update project-context.md as the project evolves. Edit sections in place to reflect current truth, then append a changelog-as-diff entry that captures exactly what changed and what it replaced. Previous state is never lost.
- **Inputs**: Current project-context.md, new information/decisions
- **Outputs**: Updated project-context.md with changelog-as-diff entry appended
- **Exit condition**: Context doc updated, every changed field has a "was → now" in the changelog
- **Subagent**: No
- **Changelog format**: See `references/evolve-context-diff.md`. Every field changed MUST have a "was → now" entry. New Key Decision rows note row number and content. Changed rows show old and new text. Removed rows record what was removed and why. The changelog is append-only — never edit or delete previous entries.

### 10. evolve-plan

- **Phase**: Ongoing (manually triggered)
- **Purpose**: Update project-plan.md as project evolves. Edit sections in place to reflect current state, then append a changelog-as-diff entry that captures exactly what changed and what it replaced. Previous state is never lost. Separate from context evolution.
- **Inputs**: Current project-plan.md, new scope/decisions/progress
- **Outputs**: Updated project-plan.md with changelog-as-diff entry appended
- **Exit condition**: Plan doc updated, every status change/addition/removal has previous state recorded
- **Subagent**: No
- **Changelog format**: See `references/evolve-plan-diff.md`. Every status change, addition, or removal MUST show what the previous state was. Completed units note the outcome. Added units note why they were discovered. Changed dependencies show old and new chains. The changelog is append-only — never edit or delete previous entries.

### 11. todo-features

- **Phase**: Ongoing
- **Purpose**: Maintain running todo list and feature tracker. Created during init, updated throughout.
- **Inputs**: project-context.md, project-plan.md
- **Outputs**: Updated todo.md, updated features.md
- **Exit condition**: Documents created or updated
- **Subagent**: No
- **Notes**: Three different lenses exist — project-plan.md (how we're building), todo.md (what needs doing now), features.md (what the thing does/will do). These are intentionally separate documents serving different audiences and purposes.

### 12. meta-compact

- **Phase**: Context Management
- **Purpose**: Intelligent context preservation before compaction. Claude writes compact/claude-compact.md capturing: current task being worked on, what step it's on, what's been done so far, what's left, pending decisions, files actively being worked on, any errors being debugged. Subagent reviews for gaps. Claude corrects, then executes /compact.
- **Inputs**: Current conversation context, active task state
- **Outputs**: compact/claude-compact.md (overwritten)
- **Exit condition**: compact/claude-compact.md written, subagent-reviewed, corrected, then /compact executed
- **Subagent**: 1 reviewer (Sonnet, high effort)
- **Notes**: compact/claude-compact.md is overwritten each time — only the latest matters. The SessionStart(compact) hook reads this file after compaction and outputs it as context with "continue task" framing. This skill is triggered by the Stop hook when context reaches >=80% and the current task is complete.

### 13. meta-clear

- **Phase**: Context Management
- **Purpose**: Safe session transition. First runs github-sync (commit and push all changes). Then Claude writes compact/claude-compact.md capturing: what was accomplished this session, key decisions made, files created/modified, next task context if one was assigned. Subagent reviews. Claude corrects, then executes /clear.
- **Inputs**: Current conversation context, session history
- **Outputs**: compact/claude-compact.md (overwritten), git push
- **Exit condition**: Code pushed, compact/claude-compact.md written, reviewed, corrected, /clear executed
- **Subagent**: 1 reviewer (Sonnet, high effort)
- **Chain**: github-sync -> write compact/claude-compact.md -> subagent review -> correct -> /clear
- **Notes**: The SessionStart(clear) hook reads compact/claude-compact.md after clear and outputs it with "transition" framing: "Last session accomplished [X]. Next task: [Y] or ask user what to work on."

### 14. counter-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Red team the entire project. Poke holes in architecture, completeness, over-engineering, truncated code, gaps. Always reviews codebase against project-context.md and features.md to flag drift.
- **Inputs**: project-context.md, features.md, project-plan.md, codebase
- **Outputs**: /docs/counter-review-findings.md (unified), plus per-model files during multi-model execution
- **Exit condition**: Findings documented with severity and recommendations. Context + features drift flagged.
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini` with the same review prompt. See Multi-Model Review Architecture section.

### 15. security-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Focused security audit. Dependencies, auth patterns, secrets exposure, input validation, network boundaries. IEC 62443 considerations where relevant to OT/ICS projects.
- **Inputs**: Codebase, project-context.md, dependency manifest
- **Outputs**: /docs/security-review-findings.md
- **Exit condition**: Security findings documented with severity, risk, and remediation recommendations
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini`.

### 16. test-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Evaluate test coverage and gaps. What's tested, what's not, what's fragile. Catches LLM tendency to skip or stub tests. Reviews test strategy against features.md to identify untested features.
- **Inputs**: Codebase, features.md, existing tests
- **Outputs**: /docs/test-review-findings.md
- **Exit condition**: Coverage gaps documented, fragile tests flagged, recommendations provided
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini`.

### 17. refactor-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Efficiency pass. Catches common LLM tendencies: over-engineering, truncated/incomplete code, unnecessary abstractions, redundancy. Always checks codebase against project-context.md and features.md for drift.
- **Inputs**: Codebase, project-context.md, features.md
- **Outputs**: /docs/refactor-review-findings.md
- **Exit condition**: Findings documented with specific refactor recommendations. Context + features drift flagged.
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini`.

### 18. drift-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Dedicated spec compliance check. Does the codebase match what project-context.md says it should be? Does features.md reflect what's actually built? Are there undocumented features or missing documented ones?
- **Inputs**: Codebase, project-context.md, features.md, project-plan.md
- **Outputs**: /docs/drift-review-findings.md
- **Exit condition**: Drift documented: what docs say vs what code does, with specific file references
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini`.
- **Notes**: This is the "does reality match the plan?" lens. Separate from counter-review (which challenges whether the plan is good) and refactor-review (which challenges how code is written). Drift-review challenges whether code matches what we said we'd build.

### 19. completeness-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Verify implementation is actually finished. Catches the #1 LLM failure mode: stubs, TODOs, placeholder values, empty catch blocks, hardcoded test data, commented-out code left behind, functions that return dummy values.
- **Inputs**: Codebase, project-plan.md, features.md
- **Outputs**: /docs/completeness-review-findings.md
- **Exit condition**: All placeholders, stubs, and incomplete implementations documented with file:line references
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini`.
- **Notes**: Pattern scan targets: `TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER`, `console.log`, `debugger`, `print(`, empty function bodies, hardcoded `localhost`, test-only values in production code, `// removed`, `// temporary`.

### 20. compliance-review

- **Phase**: On-Demand (also called by project-review meta-skill)
- **Purpose**: Check implementation against documented rules, patterns, and constraints. Loads coterie.md, cross-cutting-rules.md, CLAUDE.md (if exists), and any project-specific rule files. Extracts rules and cross-references changed files.
- **Inputs**: Codebase, coterie.md, cross-cutting-rules.md, CLAUDE.md, project-context.md
- **Outputs**: /docs/compliance-review-findings.md
- **Exit condition**: Rule violations documented with source rule quoted, severity, and fix recommendation
- **Subagent**: Sonnet (primary reviewer)
- **Multi-model execution**: When called by project-review, also runs via `/codex` and `/gemini`.
- **Notes**: For each finding, the reviewer must cite the specific rule being violated (quote it, don't paraphrase). If the rule isn't explicitly documented, it's not a compliance violation — it's a suggestion. This prevents pedantic false positives.

### 21. gemini

- **Phase**: Utility (referenced by other skills)
- **Purpose**: Encode exact Gemini CLI syntax, flags, gotchas, and task-type command templates so other skills reference this instead of guessing. This is a driver skill, not a standalone task.
- **Inputs**: Task type, prompt, output file path
- **Outputs**: Gemini CLI output written to specified file
- **Exit condition**: Output file written, or fallback noted
- **Subagent**: No (this IS the external call)
- **Availability check**: `which gemini >/dev/null 2>&1`
- **Task-type templates**:

  **Research / Analysis (no tools needed — safest):**
  *Use this pattern to avoid shell quoting issues with inline prompts.*
  ```bash
  # 1. Write prompt to temp file (prevents quoting errors)
  cat <<'EOF' > /tmp/gemini_prompt.md
  PROMPT
  EOF
  # 2. Run with env cleanup and error capture
  unset DEBUG GOOGLE_CLOUD_PROJECT CI
  cat /tmp/gemini_prompt.md | timeout 120 gemini 2>/tmp/gemini_error.log > OUTPUT_FILE || cat /tmp/gemini_error.log >> OUTPUT_FILE
  ```

  **With file context (@ syntax reads files client-side):**
  ```bash
  timeout 120 gemini -p "Review @path/to/file.ts for CONCERN" 2>/dev/null > OUTPUT_FILE
  ```

  **Long prompt via stdin (exceeds shell ARG_MAX):**
  ```bash
  cat /path/to/prompt.md | timeout 120 gemini 2>/dev/null > OUTPUT_FILE
  ```

  **JSON output (when parseable response needed):**
  ```bash
  timeout 120 gemini -p "PROMPT" --output-format json 2>/dev/null | jq -r '.response' > OUTPUT_FILE
  ```

  **Model selection:**
  ```bash
  timeout 120 gemini -m gemini-2.5-pro -p "PROMPT" 2>/dev/null > OUTPUT_FILE
  ```

- **Critical gotchas**:
  - ALWAYS wrap with `timeout` — CLI hangs indefinitely if a tool call is denied in `-p` mode
  - `unset DEBUG` before calling — `DEBUG` env var causes CLI to hang trying to connect a debugger
  - `CI_*` env vars force non-interactive detection — unset if present and not needed
  - `GOOGLE_CLOUD_PROJECT` env var triggers org subscription check — unset for personal use
  - There is NO `-o` short flag — use `--output-format text|json|stream-json`
  - There is NO `-y` short flag — use `--yolo` (but only when tools are needed, which is rare for research)
  - `--allowed-tools` is broken in non-interactive mode (known regression) — use `--yolo` if tools needed
  - `--output-format json` has regressions in some versions — test before relying on it
  - Rate limits: officially 60 RPM / 1,000 RPD free tier, but actual may be lower
  - Exit codes: 0=success, 41=auth fail, 42=input error, 130=cancelled
- **Strengths**: Web research with Google Search grounding, devil's advocate (different model family), large context (1M tokens), math-heavy reasoning
- **Weaknesses**: Tool-mediated tasks in headless mode (hangs), reliability (known hang issues), rate limit uncertainty
- **Fallback**: If unavailable or timeout, fall back to Claude WebSearch for web research tasks, or skip and note "Gemini unavailable" for review tasks.
- **Environment safety**:
  ```bash
  unset DEBUG 2>/dev/null
  # If GOOGLE_CLOUD_PROJECT is set and causing issues, unset it
  ```

### 22. codex

- **Phase**: Utility (referenced by other skills)
- **Purpose**: Encode exact Codex CLI syntax, flags, gotchas, and task-type command templates so other skills reference this instead of guessing. This is a driver skill, not a standalone task. Max 5 concurrent `codex exec` sessions.
- **Inputs**: Task type, prompt, output file path, working directory
- **Outputs**: Codex CLI output written to specified file
- **Exit condition**: Output file written, or fallback noted
- **Subagent**: No (this IS the external call)
- **Availability check**: Resolve dynamically via `whence -p` in zsh or `type -P` in bash, then Homebrew, then an NVM filesystem search that allows symlinks. Prepend the resolved bin dir to `PATH` only when needed for NVM-backed installs:
  `if command -v whence >/dev/null 2>&1; then CODEX=$(whence -p codex 2>/dev/null); elif type -P codex >/dev/null 2>&1; then CODEX=$(type -P codex 2>/dev/null); else CODEX=$(command -v codex 2>/dev/null); fi; test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"; if [ ! -x "$CODEX" ] && [ -d "$HOME/.nvm/versions/node" ]; then CODEX=$(find "$HOME/.nvm/versions/node" -path '*/bin/codex' \( -type f -o -type l \) 2>/dev/null | sort -V | tail -1); fi; test -x "$CODEX" && export PATH="$(dirname "$CODEX"):$PATH"; test -x "$CODEX"`
- **Concurrency limit**: 5 simultaneous `codex exec` processes. The orchestrating agent must track active slots and queue excess work. Track via `/tmp/codex-slots.pid` — before launching, count active PIDs in the file (`ps -p` to verify still running, prune dead entries). If 5 active, queue and retry after the next slot frees. This is best-effort — the file is a coordination hint, not a hard lock.
- **Task-type templates**:

  **Code review (read-only, safest):**
  ```bash
  RESULT=$($GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check \
    -c 'mcp_servers.homelab-gateway.enabled=false' \
    -c 'mcp_servers.ssh-tower.enabled=false' \
    -c 'mcp_servers.github.enabled=false' \
    --sandbox read-only -C <project-root> \
    "PROMPT" 2>/dev/null)
  echo "$RESULT" > OUTPUT_FILE
  ```

  **Code review with high reasoning:**
  ```bash
  RESULT=$($GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check \
    -c 'mcp_servers.homelab-gateway.enabled=false' \
    -c 'mcp_servers.ssh-tower.enabled=false' \
    -c 'mcp_servers.github.enabled=false' \
    --sandbox read-only -C <project-root> \
    -c model_reasoning_effort="high" \
    "PROMPT" 2>/dev/null)
  echo "$RESULT" > OUTPUT_FILE
  ```

  **Code generation / file writes (implementation work):**
  ```bash
  $GTIMEOUT 180 "$CODEX" exec --ephemeral --skip-git-repo-check \
    -c 'mcp_servers.homelab-gateway.enabled=false' \
    -c 'mcp_servers.ssh-tower.enabled=false' \
    -c 'mcp_servers.github.enabled=false' \
    --sandbox workspace-write -C /path/to/project \
    "PROMPT" 2>/dev/null
  ```

  **Structured output (for downstream parsing):**
  ```bash
  $GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check \
    --output-schema /path/to/schema.json \
    -o OUTPUT_FILE \
    "PROMPT" 2>/dev/null
  ```

  **Write final message to file:**
  ```bash
  $GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check -o OUTPUT_FILE \
    "PROMPT" 2>/dev/null
  ```

  **Long prompt via stdin:**
  ```bash
  $GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check - < /path/to/prompt.md 2>/dev/null
  ```

  **With additional read-only directories:**
  ```bash
  $GTIMEOUT 120 "$CODEX" exec --ephemeral --skip-git-repo-check -C /project --add-dir /shared/libs \
    "PROMPT" 2>/dev/null
  ```

- **Critical gotchas**:
  - ALWAYS wrap with `$GTIMEOUT` — hangs indefinitely if out of credits or the network stalls
  - Prefer `whence -p codex` in zsh shells or `type -P codex` in bash; `command -v codex` can return alias text instead of an executable path. If that misses, fall back to `/opt/homebrew/bin/codex`, then search NVM and allow symlinked `bin/codex`
  - `-p` is `--profile`, NOT prompt. The prompt is a positional final argument.
  - Do not rely on the default sandbox. Pass `--sandbox read-only` for review tasks and `--sandbox workspace-write` for file writes
  - Network is blocked by default in `workspace-write` sandbox
  - Use `--skip-git-repo-check` on all headless invocations. It is harmless in repos and required outside them.
  - `--ephemeral` for one-shot tasks (don't persist session state)
  - For lightweight local tasks, disable MCP servers with `-c 'mcp_servers.<name>.enabled=false'` to avoid startup latency
  - `codex exec fork` doesn't exist — use `codex exec resume --last` instead
  - Flag placement matters: global flags go AFTER `exec`, and the prompt goes LAST
  - Auto-cancels all elicitation requests in exec mode
  - Long prompts: prefer `codex exec - < file.md` over inline quoting
  - `-C` is valid shorthand for `--cd <DIR>`
  - `--json` outputs JSONL event stream, not a single JSON object — avoid for simple output capture
  - Model comes from `~/.codex/config.toml` (currently `gpt-5.4` on this machine), reasoning effort: `minimal|low|medium|high`
  - For headless: use `OPENAI_API_KEY` env var, not ChatGPT subscription OAuth
- **Strengths**: Code review and quality analysis, test generation, structured output via `--output-schema`, fast code generation, code pattern detection
- **Weaknesses**: Network blocked by default, non-code tasks, can hang on credit exhaustion, auto-cancels interactive prompts
- **Fallback**: If unavailable or timeout, skip and note "Codex unavailable". No direct substitute.
- **Environment safety**:
  ```bash
  export OPENAI_API_KEY="$OPENAI_API_KEY"
  ```

### 23. skill-doctor

- **Phase**: Utility (on-demand)
- **Purpose**: Self-diagnostic for the skill suite. Checks if everything is properly installed, hooks configured, templates accessible, CLIs available, and paths resolve correctly. Run after install or when things break.
- **Inputs**: Shared skills folder path
- **Outputs**: Diagnostic report to stdout
- **Exit condition**: All checks pass, or failures reported with fix instructions
- **Subagent**: No
- **Checks**:
  1. All 25 atomic SKILL.md files exist
  2. All 4 meta SKILL.md files exist
  3. All 5 hook scripts exist and are executable
  4. All templates exist
  5. references/cross-cutting-rules.md exists
  6. `which gemini` — available or not
  7. Resolve Codex dynamically (`whence -p` in zsh or `type -P` in bash, then `/opt/homebrew/bin/codex`, then NVM filesystem search with symlink support) — available or not
  8. Hook configuration in settings.json points to correct paths
  9. Gemini CLI responds to `gemini --version`
  10. Resolved Codex CLI responds to `"$CODEX" --version`
  11. `which jq` — required by hook scripts for JSON parsing

### 24. release-prep

- **Phase**: Ongoing (on-demand)
- **Purpose**: Automate release preparation. Generate changelog from git history and cnotes.md, bump version, create release notes, tag the release.
- **Inputs**: Current version, git log since last tag, cnotes.md
- **Outputs**: CHANGELOG.md updated, version bumped, release notes drafted
- **Exit condition**: Changelog updated, version tagged (pending user approval to push)
- **Subagent**: No
- **Notes**: Reads cnotes.md for decision context that git log alone doesn't capture. Groups changes by type (features, fixes, breaking changes). User approves before tag is created.

### 25. browser-review

- **Phase**: On-Demand (utility)
- **Purpose**: Visual QA via browser MCP tools. Triggers when any browser control MCP is active (Playwright, browser-use). Takes screenshots between actions, thoroughly reviews each screenshot for UI regressions, design compliance, layout issues, accessibility problems, and visual bugs. Not tied to any specific framework — works with any web UI.
- **Inputs**: Target URL or active browser session, design specs (if available)
- **Outputs**: Visual QA findings with annotated screenshot references
- **Exit condition**: All visible screens/states reviewed, findings documented with screenshot evidence
- **Subagent**: No (runs in main context to access browser MCP tools)
- **Trigger**: Activates when browser MCP tools are available (Playwright `browser_snapshot`, `browser_take_screenshot`, `browser_navigate`, or browser-use `browse`, `browse_screenshot`). Also triggered by user requests like "check the UI", "visual review", "does this look right", "QA the frontend".
- **Behavior**:
  1. Navigate to target or use current browser state
  2. Take screenshot before any action
  3. Review screenshot thoroughly — don't rush. Check: layout alignment, spacing consistency, color correctness, text readability, responsive behavior, interactive element states, empty states, error states, loading states
  4. Between every navigation or interaction, take another screenshot and review the delta
  5. Compare against design specs if provided (Figma URL, design tokens, style guide)
  6. Document findings with: what's wrong, where (screenshot + element reference), expected vs actual, severity (visual-only / functional / accessibility)
- **Design review checklist**:
  - Typography: hierarchy, font sizes, weights, line heights, truncation
  - Spacing: padding, margins, gaps between elements, alignment to grid
  - Color: contrast ratios (WCAG AA minimum), consistent use of design tokens, hover/focus states
  - Layout: overflow handling, responsive breakpoints, scroll behavior
  - Components: button states (default/hover/active/disabled), form validation, empty states
  - Accessibility: alt text on images, focus indicators, keyboard navigation, screen reader landmarks
- **Notes**: The key discipline is ALWAYS reviewing the screenshot between actions. Most agents skip this and just fire browser commands blindly. This skill forces a pause-and-look pattern. If the screenshot shows something unexpected, stop and investigate before continuing.

---

## Multi-Model Review Architecture

When `project-review` runs, every review lens executes across 3 model families in parallel. This section defines the shared architecture all 7 review skills use.

### Execution Pattern

For each of the 7 review lenses:

1. **Sonnet subagent** (primary): Full codebase access via Claude tools. Writes findings to `docs/[lens]-review-sonnet.md`.
2. **Codex CLI** (per `/codex` skill): Task type `read-only review`, `--ephemeral --sandbox read-only -c model_reasoning_effort="high"`. Receives the same review prompt adapted for single-shot execution. Writes to `docs/[lens]-review-codex.md`. Subject to 5-slot concurrency limit — queue if full.
3. **Gemini CLI** (per `/gemini` skill): Task type `research/analysis`. Receives the same review prompt adapted for single-shot execution. Writes to `docs/[lens]-review-gemini.md`. **Input assembly**: Claude assembles a single prompt file containing the review instructions + relevant code (key files, not the entire codebase). Use Gemini's `@path/to/file.ts` syntax for up to ~10 key files, or concatenate code into the prompt file and pipe via stdin for larger scopes. Gemini cannot browse the filesystem with MCP tools in headless mode — all code context must be passed explicitly.

### Confidence Scoring via Multi-Model Agreement

Instead of arbitrary 0-100 scores, confidence comes from model agreement:

- **3/3 models find the same issue** = HIGH confidence (report it)
- **2/3 models find the same issue** = MEDIUM confidence (report it, note which model missed it)
- **1/3 models find the issue** = LOW confidence (report only if severity is critical/high, otherwise suppress)
- **Disagreements** = flag explicitly for human review

### Synthesis

After all 21 reviews complete, Claude:
1. Reads all per-model findings files (7 lenses x 3 models)
2. Deduplicates — same issue found by multiple models/lenses gets merged
3. Scores by agreement (see above)
4. Checks for cross-lens patterns (e.g., security issue + compliance violation + drift = systemic problem)
5. Writes unified `docs/review-synthesis.md` with severity ranking

### Concurrency Management

- 7 Sonnet subagents: all launch in parallel (no limit)
- 7 Gemini calls: all launch in parallel (Gemini rate limit is the ceiling)
- 7 Codex calls: queue in 5-slot worker pool (5 run, 2 queue, total 7)
- Total: up to 19 concurrent external calls (7 Sonnet + 7 Gemini + 5 Codex) + 2 queued Codex

---

## Meta-Skills — Specifications

Meta-skills chain atomic skills. They define the order and transition conditions but do NOT duplicate atomic skill instructions. Each phase says: "Read and execute `../atomic-skill/SKILL.md`. When exit condition is met, proceed to next phase."

### project-init

- **Purpose**: Full project initialization from zero to plan
- **Chain**: scaffold -> repo-create -> questions -> context -> research-plan -> [optional: research-execute] -> build-plan
- **Notes**: After research-plan, ask the user if they want to run research-execute before proceeding to build-plan. If research was run, build-plan uses the synthesis. If skipped, build-plan works from project-context.md alone. After the full chain completes, ask the user if they want to start building (project-execute) or run a review (project-review).

### project-review

- **Purpose**: Comprehensive project review across all 7 lenses x 3 model families
- **Execution**: All 7 review lenses run in parallel across 3 model families (see Multi-Model Review Architecture). This is NOT sequential — it's a parallel fan-out with synthesis.
- **Lenses**: counter-review, security-review, test-review, refactor-review, drift-review, completeness-review, compliance-review
- **Output**: Individual per-lens findings + unified `docs/review-synthesis.md`
- **Notes**: Each review skill is also callable standalone (runs as Sonnet subagent only, no multi-model). The meta-skill runs all 7 across all 3 models for maximum coverage.

### project-evolve

- **Purpose**: Update living documents when project state changes
- **Chain**: evolve-context -> evolve-plan
- **Notes**: Manually triggered. Each is also callable standalone.

### project-execute

- **Purpose**: Parallel implementation from build plan using Codex worker pool
- **Inputs**: project-plan.md (with work unit decomposition), codebase
- **Execution**:
  1. Claude (Opus) reads project-plan.md and decomposes into independent work units
  2. Tags each unit: parallelizable or sequential, estimated complexity
  3. Assigns parallelizable units to 5 Codex exec slots (worker pool pattern)
  4. Each Codex exec gets: `--full-auto --ephemeral --cd <project-root>`, the work unit prompt, relevant file context via `--add-dir`
  5. As slots free up, next queued unit is assigned
  6. Claude reviews each completed unit before assigning the next
  7. Sequential units run in order after their dependencies complete
  8. If a unit fails or times out, Claude can: retry, reassign to a Sonnet subagent as fallback, or flag for human review
- **Output**: Implemented code, per-unit completion notes
- **Exit condition**: All work units implemented and reviewed, or remaining units flagged as blocked
- **Notes**: Claude is the orchestrator, not an implementer. Codex does the coding. Claude reviews, manages the queue, and handles failures. If Codex is unavailable, fall back to Sonnet subagents in worktree isolation.

---

## Hooks — Specifications

All hooks are Claude Code specific. They go in the hooks/ folder and are configured in .claude/settings.json.

### 1. stop-check (Stop hook)

- **Event**: Stop (no matcher support — fires on every stop)
- **Type**: command
- **Purpose**: After every Claude response, prompt Claude to (1) check if living docs need updating and (2) check context usage via `/context`. Uses the Ralph-loop pattern: block the first stop with a reason, allow the second stop. Combines doc check and context check into a single hook to avoid ordering conflicts.
- **Script behavior**:
  1. Read JSON from stdin. Extract `stop_hook_active` field.
  2. If `stop_hook_active` is `true` — Claude is already continuing from a previous stop hook. Exit 0 (let Claude stop normally).
  3. If `stop_hook_active` is `false` — this is the first stop. Output JSON to stdout:
     ```json
     {
       "decision": "block",
       "reason": "Before stopping: 1) Check if cnotes.md, todo.md, or features.md need updating based on what you just did. If there were notable decisions, context changes, action items, or feature changes — update them. 2) Run /context to check context usage. If usage is at or above 80%, run the meta-compact skill to preserve context before starting any new work. If nothing notable to update and context is fine, you may stop."
     }
     ```
  4. Claude receives the reason, checks docs (updates if needed), runs `/context`, runs meta-compact if needed, then stops again.
  5. On the second stop, `stop_hook_active` is `true`, so the script exits 0 and Claude stops.
- **Notes**: Claude decides what's worth logging. No overhead on trivial responses — Claude reads the reason, decides nothing needs updating, checks context is fine, and stops immediately on the second pass. The `/context` command is a built-in Claude Code command that shows current context window usage — no bash-level token counting needed.

### 2. pre-compact-safety (PreCompact hook)

- **Event**: PreCompact (fires on all compaction events — both auto and manual /compact)
- **Type**: command
- **Purpose**: Safety net. If auto-compaction fires before Claude ran meta-compact, write a minimal compact/claude-compact.md with whatever state we can extract. This ensures SessionStart(compact) has something to work with even on unexpected compaction.
- **Script behavior**:
  1. Read JSON from stdin. Extract `transcript_path` and `cwd`.
  2. Check if compact/claude-compact.md already exists and was modified within the last 5 minutes — if so, meta-compact already ran. Exit 0.
  3. If compact/claude-compact.md is stale or missing, extract the last 5 assistant messages from transcript JSONL.
  4. Write a minimal compact/claude-compact.md: "AUTO-SAVED CONTEXT (meta-compact did not run). Last 5 messages:" followed by the extracted messages.
  5. Exit 0. (PreCompact cannot block compaction.)
- **Notes**: This is a fallback — the primary path is meta-compact triggered by stop-context-check. pre-compact-safety catches the case where context hit 100% before Claude could act on the 80% warning.

### 3. session-start-compact (SessionStart hook)

- **Event**: SessionStart
- **Matcher**: compact
- **Type**: command
- **Purpose**: After compaction, read compact/claude-compact.md and output it as context. Frame it as continuation.
- **Script**: Read compact/claude-compact.md. Prepend: "You were working on the following task. Continue from where you left off. Here is your preserved context:" Output to stdout. Exit 0.

### 4. session-start-clear (SessionStart hook)

- **Event**: SessionStart
- **Matcher**: clear
- **Type**: command
- **Purpose**: After /clear, read compact/claude-compact.md and output it as context. Frame it as transition.
- **Script**: Read compact/claude-compact.md. Prepend: "The previous session accomplished the following. If a next task was specified below, begin working on it. If not, ask the user what they'd like to work on next." Output to stdout. Exit 0.

### 5. session-start-startup (SessionStart hook)

- **Event**: SessionStart
- **Matcher**: startup
- **Type**: command
- **Purpose**: On fresh session start, load project-context.md, coterie.md, and todo.md into context so Claude starts with full project awareness.
- **Script**: Cat project-context.md, coterie.md, and todo.md (if they exist). Output to stdout. Exit 0.

### Note: --resume / --continue

Sessions restored via `--resume` or `--continue` do not trigger any SessionStart hook (no matcher matches). This is intentional — resumed sessions restore their own conversation context from the session file. No custom injection is needed.

### Hook Configuration (settings.json)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/shared-skills-folder/hooks/stop-check.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/shared-skills-folder/hooks/pre-compact-safety.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/shared-skills-folder/hooks/session-start-compact.sh"
          }
        ]
      },
      {
        "matcher": "clear",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/shared-skills-folder/hooks/session-start-clear.sh"
          }
        ]
      },
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/shared-skills-folder/hooks/session-start-startup.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Non-Claude Agent Skills

`CODEX.md` and `GEMINI.md` in the shared skills folder are skill breakdowns for their respective CLI agents. Each file lists only the skills that agent is equipped with — verbatim descriptions, no inlined rules or instructions. The user copies these to each agent directly.

### CODEX.md Skills

- **Context preservation (compact)**: Write `compact/codex-compact.md` before session ends
- **Completeness self-check**: Scan own output for stubs/TODOs/placeholders
- **Compliance check**: Verify changes against coterie.md, project-context.md, features.md
- **Evolve context**: Update project-context.md when work changes architecture
- **Evolve plan**: Update project-plan.md when milestones complete or new work surfaces

### GEMINI.md Skills

- **Counter-review (devil's advocate)**: Challenge assumptions, fact-check with Google Search grounding, flag gaps
- **Evolve context**: Update project-context.md after research/review
- **Evolve plan**: Update project-plan.md after review reveals scope changes
- **Research**: Web-grounded research with multi-source cross-referencing

---

## Key Design Principles

1. **Hooks for deterministic guarantees. Skills for intelligent work. Rules for guidelines.** If it MUST happen, it's a hook. If it needs reasoning, it's a skill. If it's guidance, it's a rule in coterie.md.

2. **Files are the handoff mechanism.** Skills produce .md artifacts. The next skill in the chain reads those files. Never bloat context by passing everything through conversation.

3. **Progressive disclosure.** Metadata (~100 tokens) is always loaded. SKILL.md body loads when triggered (<2,000 words). Bundled references and examples load on demand.

4. **Descriptions are the trigger.** Write them in third person, be pushy about when to use the skill, include specific trigger phrases and contexts. Include `<example>` blocks.

5. **Explain the why.** Don't write MUST/NEVER in all caps. Explain reasoning so the model understands the intent and can generalize.

6. **Exit conditions matter.** Every atomic skill needs a clear "I'm done when X" so meta-skill chains know when to advance.

7. **Subagents get isolated context.** They do NOT inherit the parent's conversation. Everything must be passed explicitly in the prompt. This is a feature for fresh-eyes reviews, not a limitation.

8. **meta-clear always syncs to GitHub first.** Code is never lost on a clear.

9. **compact/claude-compact.md serves dual purpose.** Same file, different framing. SessionStart(compact) reads it as "continue task." SessionStart(clear) reads it as "what was done, what's next." Codex has its own `compact/codex-compact.md` for context preservation between sessions.

10. **The Stop hook is the backbone.** It uses the Ralph-loop pattern (block first stop, allow second) to enforce living doc updates and context awareness on every response. Claude decides what's worth acting on — the hook guarantees it's always prompted.

11. **Multi-model agreement is the confidence signal.** Don't trust a single model's review findings. 3/3 agreement = real issue. 1/3 = likely false positive. This replaces arbitrary scoring rubrics.

12. **Codex for implementation, Claude for orchestration.** project-execute uses Codex as the implementation engine (5-slot worker pool). Claude manages the queue, reviews output, and handles failures. This optimizes cost (Codex on flat-rate subscription) and leverages each model's strengths.

13. **Every CLI call gets a timeout.** Both Gemini and Codex can hang indefinitely. Never invoke either without `timeout`. The `/gemini` and `/codex` utility skills encode this — other skills reference them, never inline CLI commands.

14. **Graceful degradation.** If Gemini is unavailable, fall back to WebSearch. If Codex is unavailable, fall back to Sonnet subagents. If both are down, the suite still works — just with less multi-model coverage. Note what was skipped.
