---
name: meta-join
description: "Join an existing project. Supports full onboard (7 steps) or quick catch-up (drift-review + sync only). Triggers on join project, catch up, onboard, quick catch-up."
---

# meta-join

## Purpose

Cold-start or warm-restart into an existing project. Ensures the project has
the standard structure, a repo, all skill suite files, up-to-date docs, and
a current build plan.

**Context-window strategy**: Non-interactive steps are delegated to subagents
to keep the main thread lean. Interactive steps (interviews, user approvals)
stay inline. Each subagent reads its own SKILL.md — never load atomic skill
files into the main context.

## Chain

```
project-scaffold -> repo-create -> meta-review -> sync-skills
    -> project-questions -> project-context -> build-plan

Delegation key:
  [S] = subagent   — runs out of main context
  [I] = inline     — requires user interaction, stays in main thread
  [D] = self-delegating — already dispatches its own subagents

  scaffold[S] -> repo-create[I] -> meta-review[D] -> sync-skills[S]
      -> project-questions[I] -> project-context[I] -> build-plan[S]
```

## Instructions

### Mode Selection

When triggered, ask the user:

> "Full onboard or quick catch-up?
> 1. **Full** — scaffold, review, sync, interview, docs, plan (7 steps)
> 2. **Quick** — review recent changes + sync templates only (2 steps: drift-review + sync-skills)"

- If **quick**: Run only drift-review (to see what changed) and sync-skills (to update templates). Present findings. Done.
- If **full**: Continue with the standard 7-step chain below.
- If the user already specified "quick" in their prompt (e.g., "quick catch-up", "just the basics"), skip the question and run quick mode.

### Step 1: Project Scaffold [Subagent]

Check if the project has the standard directory structure (`artifacts/compact/`,
`artifacts/research/`, `artifacts/research/summary/`, `artifacts/reviews/`, `docs/`, `src/`) and template files (`coterie.md`, `cnotes.md`,
`todo.md`, `features.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`,
`.gitignore`).

- **If all present**: skip. Confirm: "Scaffold already exists — skipping."
- **If partially present or missing**: dispatch a subagent. Do NOT read
  `../project-scaffold/SKILL.md` into the main context.

```
Spawn a general-purpose subagent with this prompt:

"You are filling gaps in an existing project's scaffold.

1. Read the skill instructions at:
   [absolute path to skills/project-scaffold/SKILL.md]

2. Project root: [PATH]

3. Check which directories and template files already exist. Only create
   what is missing. Do NOT overwrite existing files.

4. When complete, report back with ONLY:
   - Files/directories that already existed (skipped)
   - Files/directories that were created
   - Any issues encountered"
```

### Step 2: Repository [Inline]

Check if git is initialized and a remote origin is set. This step is
interactive (asks about repo name, visibility, remote). Read and execute
`../repo-create/SKILL.md` inline only if setup is needed.

- **If repo exists with remote**: skip. Confirm: "Repo already connected."
- **If git initialized but no remote**: ask if the user wants to connect one.
- **If no git at all**: run repo-create for full setup.

### Step 3: Project Review [Self-Delegating]

Run `/meta-review`. This skill already dispatches its own subagents (21
parallel reviews across 3 model families). No additional delegation needed.

If the project is small or the user says they just need a quick catch-up,
run only the `completeness-review` and `drift-review` lenses instead of
the full 7-lens sweep.

### Step 4: Sync Skills [Subagent]

Dispatch a subagent to sync skill templates. Do NOT read
`../sync-skills/SKILL.md` into the main context.

```
Spawn a general-purpose subagent with this prompt:

"You are syncing skill suite templates for an existing project.

1. Read the skill instructions at:
   [absolute path to skills/sync-skills/SKILL.md]

2. Project root: [PATH]

3. Check all project files against skill suite templates. Identify missing
   or stale files. Create/update as needed without overwriting user content.

4. When complete, report back with ONLY:
   - Files that were up-to-date (skipped)
   - Files that were created or updated
   - Any conflicts requiring user decision"
```

### Step 5: Project Questions [Inline]

This step is interactive — it conducts an interview with the user. Read and
execute `../project-questions/SKILL.md` inline only if needed.

- **If `project-context.md` exists and looks complete** (all major sections
  filled): skip. Confirm: "Context doc looks current — skipping interview."
- **If `project-context.md` is missing or sparse**: run the interview to fill
  gaps. Focus questions on what the review in Step 3 revealed as unclear.

### Step 6: Project Context [Inline]

This step is interactive — the user must review and approve the context doc.
Read and execute `../project-context/SKILL.md` inline only if needed.

- **If `project-context.md` doesn't exist**: write it using the interview
  answers and review findings.
- **If it exists but is stale**: use `/evolve-context` to surgically update
  what changed rather than overwriting.

### Step 7: Build Plan [Subagent]

Dispatch a subagent to generate or update the build plan. Do NOT read
`../build-plan/SKILL.md` into the main context.

```
Spawn a general-purpose subagent with this prompt:

"You are creating/updating a build plan for an existing project.

1. Read the skill instructions at:
   [absolute path to skills/build-plan/SKILL.md]

2. Read the project context at:
   [project root]/project-context.md

3. [If project-plan.md exists]: Read the existing plan and update it rather
   than starting from scratch. Focus on what changed since the plan was last
   written.

4. Follow the skill instructions completely. Write project-plan.md.

5. When complete, report back with ONLY:
   - Number of phases and work units
   - Phase names and milestone descriptions
   - What changed (if updating an existing plan)
   - Any flagged risks"
```

Review the subagent's summary. Read `project-plan.md` and present to the
user for approval.

Start from wherever the project currently is — not from zero.

## Adaptive Behavior

- If the project already has all files and up-to-date docs, steps 1-2 and
  4-6 collapse to quick checks and the flow completes fast.
- If the project is brand new with no structure, all 7 steps run fully (at
  that point, suggest `/meta-init` instead since it's designed for greenfield).
- Always ask the user before proceeding to the next step if any step
  produced surprising findings (e.g., major drift, missing critical files).

## Error Handling

### Timeout Guards

- Set a mental time limit of 5 minutes per phase. If a phase has not produced output in 5 minutes, check if the subprocess is still running.
- For Gemini CLI calls: always use `timeout 120` wrapper. If it times out, skip and note "Gemini timed out — skipping."
- For Codex CLI calls: always use `timeout 120` wrapper. Same fallback.
- If a subagent has been running for more than 10 minutes with no output, consider it stalled and move on.
- Report any timeouts in the completion summary so the user knows what was skipped.

## Examples

```
User: I just cloned a repo and need to get oriented.
--> Run meta-join. Steps 1-2 detect existing scaffold/repo and skip.
    Step 3 reviews. Step 4 syncs templates. Steps 5-7 build docs and plan.
```

```
User: Picking this project back up after a month.
--> Run meta-join. Steps 1-4 to assess and sync. Conditionally skip 5-6
    if docs are still current. Refresh the plan in step 7.
```

```
User: Join this project but I just need the basics.
--> Quick mode: drift-review + sync-skills only. Skip steps 1-2 and 5-7.
```

```
User: This project has code but zero documentation.
--> Steps 1-2 fill structure gaps. Step 3 reviews the code. Step 4 syncs
    templates. Steps 5-7 run fully to build context and plan from scratch.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
