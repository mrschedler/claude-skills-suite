---
name: meta-init
description: "Full project initialization from zero to approved build plan. Triggers on new project, init from scratch, set up everything, take me from zero to plan."
---

# meta-init

Meta-skill that chains all initialization atomic skills in order, taking a
project from nothing to an approved build plan ready for implementation.

**Context-window strategy**: See `references/meta-skill-guards.md`.

## Chain

```
project-scaffold -> repo-create -> project-questions -> project-context
    -> research-plan -> [optional: research-execute] -> build-plan

Delegation key:
  [S] = subagent   — runs out of main context
  [I] = inline     — requires user interaction, stays in main thread

  scaffold[S] -> repo-create[I] -> project-questions[I] -> project-context[I]
      -> research-plan[S] -> [research-execute: via /meta-research] -> build-plan[S]
```

## Inputs

| Input | Source | Required |
|---|---|---|
| Project name | User prompt | Yes |
| Project root path | User prompt or cwd | Yes |
| Initial project description | User prompt | Yes |

## Instructions

### Mode Selection

If the project already has some phases completed (scaffold exists, repo exists, context exists), detect this automatically and present:

> "Detected existing: [list what exists].
> 1. **Resume** — skip completed phases, continue from [first missing phase]
> 2. **Full** — re-run everything from scratch"

Default to Resume if the user doesn't specify.

### Phase 1: Scaffold [Subagent]

Dispatch a subagent to handle scaffolding. Do NOT read `../project-scaffold/SKILL.md`
into the main context. Read `agents/scaffold.md` for the prompt template —
fill in [NAME] and [PATH] before spawning.

Review the subagent's summary. Present the scaffold summary to the user for
confirmation.

**Exit condition**: All standard directories and template files exist. User
has confirmed the scaffold summary.

**Transition**: Proceed to Phase 2.

### Phase 2: Repository [Inline]

This phase is interactive — it requires user input about repo name, visibility,
and remote setup. Read and execute `../repo-create/SKILL.md` inline.

**Exit condition**: Git is initialized, remote origin is set, initial commit
is pushed. User has seen the repo URL.

**Transition**: Proceed to Phase 3.

### Phase 3: Deep-Dive Interview [Inline]

This phase is interactive — it conducts an aggressive interview with the user.
Read and execute `../project-questions/SKILL.md` inline.

Pass the user's initial project description. The interview will web-ground
the domain, then conduct an aggressive probe to surface assumptions, gaps,
and constraints. Do not rush this phase — it is the foundation everything
downstream depends on.

**Exit condition**: No fundamental gaps remain. The user has confirmed the
structured summary of everything learned.

**Transition**: Proceed to Phase 4.

### Phase 4: Context Document [Inline]

This phase is interactive — the user must review and approve the context doc.
Read and execute `../project-context/SKILL.md` inline.

Use the interview output from Phase 3 as input. Write the definitive
project-context.md. Present for user review and approval before writing.

**Exit condition**: `project-context.md` exists in the project root, all
sections filled, user has approved it.

**Transition**: Proceed to Phase 5.

### Phase 5: Research Plan [Subagent]

Dispatch a subagent to analyze the project context and produce a research plan.
Do NOT read `../research-execute/SKILL.md` into the main context. Read
`agents/research-plan.md` for the prompt template — fill in the skill path
(research-execute, Phase 0), project root, and NNN before spawning.

Present the subagent's topic summary to the user.

**Exit condition**: A research plan exists with specific research questions,
sources to consult, and expected outputs.

**Transition**: Ask the user the following decision question before proceeding.

### Decision Gate: Research Execution

Present this choice to the user:

> "Research plan is ready. Do you want to execute the research now before
> building the plan? This will validate technology choices and surface risks
> early, but takes additional time.
>
> 1. **Run research** — execute research, then feed findings into build-plan
> 2. **Skip research** — proceed directly to build-plan using project-context.md alone"

Wait for the user's answer. Do not assume.

**If the user chooses option 1**: Proceed to Phase 6a.
**If the user chooses option 2**: Skip to Phase 7.

### Phase 6a: Research Execution (optional) [Subagent]

This phase is already context-minimal by design — `/meta-research` dispatches
an Opus subagent that orchestrates research workers. Simply invoke the
meta-research skill flow. Do NOT read `../research-execute/SKILL.md` into the
main context.

Pass the existing research plan from Phase 5. The meta-research flow handles
approval, dispatch, and synthesis.

**Exit condition**: Research findings are synthesized and written to the
project's `artifacts/research/` directory.

**Transition**: Proceed to Phase 7. The build-plan phase will use both
project-context.md and the research synthesis.

### Phase 7: Build Plan [Subagent]

Dispatch a subagent to generate the build plan. Do NOT read
`../build-plan/SKILL.md` into the main context. Read `agents/build-plan.md`
for the prompt template — fill in the skill path, project root, and
optionally the research summary path before spawning.

Review the subagent's summary. Read `project-plan.md` and present it to the
user for review and approval.

**Exit condition**: `project-plan.md` exists with phased work units,
dependencies, acceptance criteria, and complexity estimates. User has
reviewed and approved the plan.

**Transition**: Chain complete. Present the final decision gate.

### Final Decision Gate

After build-plan is approved, present this choice:

> "Project initialization is complete. You have:
> - Scaffolded project structure
> - GitHub repository
> - project-context.md (approved)
> - project-plan.md (approved)
> [- Research findings (if research was run)]
>
> What next?
> 1. **Start building** — run meta-execute to implement the plan
> 2. **Run a review first** — run meta-review to stress-test the plan
>    before building
> 3. **Done for now** — stop here and come back later"

Wait for the user's answer. If they choose 1, tell them to run
`/meta-execute`. If they choose 2, tell them to run `/meta-review`.
If they choose 3, confirm and exit.

## Error Handling

- If any phase fails or the user wants to skip it, note what was skipped and
  continue. The chain is designed to be sequential but individual phases can
  be re-run independently later.
- If the user already has some phases done (e.g., scaffold exists, repo
  exists), detect this and skip completed phases. Confirm with the user:
  "Scaffold already exists — skipping to Phase 3. OK?"
- If Gemini CLI is unavailable during research phases, fall back to Claude
  WebSearch per the gemini skill's fallback rules.

### Timeout Guards

See `references/meta-skill-guards.md` for shared timeout and stall detection rules.

## Examples

```
User: "I want to start a new project from scratch. It's a real-time
       collaboration tool called collab-space."
Action: Run the full chain. Start with scaffold (ask for root path), create
        repo, interview about the collaboration tool domain, write context,
        plan research, ask about research execution, then build the plan.
```

```
User: "New project. Set up everything — I want to go from zero to a plan
       I can start building from."
Action: Ask for project name and description, then run the full chain.
```

```
User: "/meta-init nexus-api — a REST API for managing IoT device
       configurations"
Action: Project name is nexus-api. Start the chain. Domain-ground IoT device
        management. Interview will focus on device types, protocols, scale,
        and security constraints.
```

```
User: "I scaffolded the project already and have a repo. Just need to go
       from interview to plan."
Action: Detect existing scaffold and repo. Confirm skip. Start at Phase 3
        (project-questions) and continue through to build-plan.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
