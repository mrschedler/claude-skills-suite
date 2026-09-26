---
name: idea-intake
description: Turns a sparse idea into a plan both sides agree on before any build. Use when the user says "interview me" or "make sure you are on point".
---

# idea-intake

Turn a one-paragraph idea about an unfamiliar tool, product, or approach into a plan the
user can actually approve. A sparse prompt about something unfamiliar invites the wrong
first move: guessing, asking questions research could answer, or building around the one
example the user happened to mention. Before every question, check memory, project
documents, the web, and X (see `references/interview-loop.md`): only ask what none of
them can answer. `idea-intake` runs first, before any scaffolding skill; its agreed plan
is what `project-questions` and `meta-init` then build from.

## When to use

- The user describes an idea in a paragraph or less and asks to be interviewed.
- The user names a tool, product, or approach the agent does not recognize.
- "Help me figure out how to use X", "what would a skill for X look like", "I have an
  idea", "interview me", "do you understand what I want", "make sure you are on point."
- Any task where a wrong build would waste real effort from misread intent.
- Not for a quick lookup with no interview or approval step: use `claude-light-research`
  or `claude-deep-research` instead.

## Why This Exists

A real two-hour session (`artifacts/research/jev/idea-intake-process-2026-09-26.md`) took
eleven corrections to turn a one-paragraph idea into a plan the user called "exactly what
I want to build." The failure this skill prevents: treating an unfamiliar noun like a
familiar one, guessing, asking what could be researched, latching onto the one example
named, and building before the goals were confirmed. Full detail in
`references/corrections-ledger.md`.

| # | Rule the correction produced |
|---|---|
| 1 | Research from zero before question one. Build a rubric. Store findings in the artifact DB. |
| 2 | The director orchestrates and judges; delegate everything fetchable, in parallel. |
| 3 | Every dispatch names its model: Sonnet for routine, Opus for judgment, Grok via interagent for second-vendor or live-social judgment. |
| 4 | Never report a send or action done before the tool result confirms it. |
| 5 | Arm the interagent monitor in the same turn as any interagent send, and re-arm on every expiry. |
| 6 | Name the sources a researcher must use; require an account and a link per finding. |
| 7 | Every vendor evaluation includes the self-hosted or local alternative by default. |
| 8 | Hold the interview at the level the user opened it; the first application is an instance, not the product. |
| 9 | A preference question is fair only after the option space is researched. |
| 10 | Before any build: restate goals, ground use cases in the user's history, get explicit approval. |
| 11 | Taking an implicit answer as a decision: state the reading out loud once, then proceed. |

The user later refined this: the interview is an adaptive loop, not a fixed list, and the
build waits for a mutual yes, not approval of a document. In the user's words: "one
question at a time... evaluate if you have enough information to move on... Never jump
into implementation until we BOTH agree we are going in the right direction." Phase 2
and 3 implement this.

## Inputs

- The user's idea, one paragraph or less. Required.
- Canonical preferences and recent rulings from memory (`memory_call` / `pref_call`),
  recalled before the first research dispatch. Enhancement: proceed without it if
  unavailable, but say so.
- `artifacts/db.sh`. Create it if missing, same pattern as `claude-light-research`.
- Agents to run the research fan-out: Claude subagents for the six Sonnet/Opus templates,
  interagent for the two Grok templates. See `references/research-dispatch-templates.md`.

## Outputs

- Research files under `artifacts/research/<slug>/`, one per dispatched agent.
- An artifact DB row per finding plus one for the brief
  (`db_upsert 'idea-intake' 'research' '<slug>/<file>' "$CONTENT"`).
- A synthesis brief: `artifacts/research/<slug>/<slug>-architecture-brief.md`.
- A running problem-statement document, updated every loop iteration in Phase 2:
  `artifacts/research/<slug>/problem-statement.md` or an artifact DB row.
- A charter file: `artifacts/research/<slug>/<slug>-application-project.md`.
- Grok prompt files, committed before each send:
  `artifacts/research/<slug>/<date>-grok-research-<slug>-<aspect>-prompt.md`.
- Decision memories in Qdrant, written as they are made, not batched at the end.

## Instructions

### Phase 0: Recall and research from ignorance

1. Recall canonical preferences and recent rulings from memory first (`pref_call` /
   `memory_call`). Several corrections were reminders of rules already stored.
2. Identify every noun in the idea the agent does not actually know. Research them; do
   not ask the user about them.
3. Write a short first-pass orientation from a quick web pass
   (`artifacts/research/<slug>/orientation.md`), enough to name what needs deeper
   research, not the final answer.
4. Dispatch the research fan-out in parallel, one agent per lens, every dispatch naming
   its model explicitly (a deliberate exception to "don't hardcode a model": the model
   tier is the fix correction #3 exists for). Do not fetch yourself in the director
   thread. See `references/research-dispatch-templates.md` for the eight prompt shapes
   and which model runs each:
   - Sonnet: docs reference, integration survey, system inventory.
   - Sonnet (default whenever a vendor is involved, unprompted): local/self-hosted
     alternative with hardware fit, and a data-retention comparison across every access
     path the user can actually use.
   - Opus: skeptic evidence and comparison rubric.
   - Grok, via interagent only, never as a subagent: live social signal and a broad
     application-type survey (this keeps the interview from narrowing to the one example
     the user named).
5. For every Grok dispatch: commit the prompt file, send it via interagent, and arm
   `/monitor-interagent` in the same turn, re-arming on every expiry. Do not report the
   send as done until the tool result confirms it went out.
6. As each agent returns, store its finding in the artifact DB yourself; never ask a
   subagent to write to the DB.
7. **Exit condition:** every unknown noun has a docs-reference and a skeptic-evidence
   finding; if a vendor is involved, the local-alternative and retention-comparison
   findings exist before Phase 2 opens.

### Phase 1: Synthesis brief

Dispatch one Opus agent to read only the research files, no new fetching, and write one
brief: verdict, comparison rubric, where the research agents disagreed and how it was
resolved, an architecture position, a design for the first instance, a roadmap, a skill
outline, and a ranked residue of unanswerable questions. Store and commit it; revise
until it holds before opening Phase 2.

**Exit condition:** the brief holds with no outstanding revision and names a ranked
residue of unanswerable questions (may be empty).

### Phase 2: Adaptive interview

This is a loop, not a fixed list: the final question is not known until the
second-to-last answer arrives, a question that no longer matters after an answer is
dropped, and a question the answer opened is researched before it is asked. Seed the
loop with the brief's ranked residue, then let each answer reshape what comes next.

1. Run the source check in `references/interview-loop.md`, then ask exactly one
   question, carrying a recommendation and the evidence behind it. Never ask two in one
   message; never ask a question research can answer.
2. Wait for the answer.
3. Before asking anything else, run the full checklist in `references/interview-loop.md`
   (source check, update the problem statement, challenge the assumptions the framing
   depends on, reframe or research, judge sufficiency) and record the result in the
   running problem-statement document from Outputs, not only in context.
4. If not yet sufficient, return to step 1 with the reframed or researched question set.

A risk or tradeoff preference question comes with an option table, never a yes/no
framing. An implicit answer taken as a decision still gets stated out loud once before
proceeding.

**Exit condition:** sufficiency judged yes per `references/interview-loop.md`, not merely
"the residue is answered."

### Phase 3: Problem statement and intent check

The mutual-agreement gate. Present one statement, in this order, then stop:

1. The user's problem statement in one paragraph, in plain words.
2. Your understanding of intent, including the meta-goal behind the example.
3. The broad picture: classes of use, not the first instance, grounded in memory.
4. Suggested actions only, as options with a recommendation, never a build plan.
5. What will not be touched.
6. Decisions already made so far, as a settled-facts appendix, not a build order.

See `references/goals-check-template.md` for the exact structure. Then ask exactly one
question: do we agree this is the right direction?

**Exit condition:** an explicit yes, never partial or implied. A correction becomes the
new first question of Phase 2; repeat until both sides agree.

### Phase 4: Dispatch the build

Starts only after the mutual yes in Phase 3, never before.

- Name each model by rule 3: routine work to Sonnet, judgment-heavy work to Opus, never
  the director model. A separate Opus verifier gets the original requirement, not the
  implementer's conclusions. Grok reviews independently with the identical committed
  prompt, sent via interagent with the monitor armed.
- Record decisions to Qdrant as made.
- Commit files at each milestone, not one final commit.
- Report what shipped and what is pending; never before the tool result confirms it.

**Exit condition:** every deliverable is shipped and committed, or reported pending with
a reason.

## Anti-patterns

1. Implementing, scaffolding, or dispatching builders before both sides explicitly agree.
2. Asking a question research could have answered instead of researching it first.
3. Running research fetches in the director thread instead of delegating them.
4. Dispatching a subagent with no model set instead of the routine/judgment tier.
5. Reporting a send or action as done before the tool result confirms it.
6. Sending an interagent message without arming the inbox monitor in the same turn.
7. Leaving research sources unspecified, so an agent skips the ones that matter.
8. Asking about self-hosting or hardware before researching the local alternative.
9. Interviewing at the level of the one named application instead of the general idea.
10. Asking a preference question, especially about risk, as yes/no before researching it.
11. Asking two questions at once, or skipping the update/reframe/sufficiency check
    between answers.
12. Presenting a build plan with file names or work units at the agreement gate.
13. Recording a decision from an implicit answer without stating the reading out loud.
14. Asking from a pre-written list without re-reading the last answer.
15. Being lazy about background already held: asking the user something memory, the
    project docs, the web, or X could answer.

## Relationship to other skills

- `claude-light-research` / `claude-deep-research`: one research pass, no interview or
  approval gate. Use these for just a question, not an idea to shape.
- `project-questions`: interviews on problem, users, scope, and tech stack once a project
  is framed. `idea-intake` runs first, while the idea is still unfamiliar; its agreed
  problem statement is what `project-questions`/`meta-init` scaffold from.
- `build-plan`: turns an approved GROUNDING.md into phases and work units. The agreed
  problem statement and chosen actions are a starting point for `build-plan`, not a
  replacement.

## Examples

```
User: "Interview me about [an unfamiliar tool]. I want to use it for X, maybe write a
skill for it."
→ Phase 0: research from zero across the Sonnet/Opus/Grok lenses. Phase 1: Opus brief
  with a ranked residue. Phase 2: adaptive loop, one question at a time, updating the
  problem statement and judging sufficiency after each answer. Phase 3: intent check,
  explicit mutual yes. Phase 4: dispatch the build.
```

```
User mid-loop: "We're building a general framework, not just an email tool. Why are we
deep in mailbox details?"
→ Reframe signal (Phase 2 step 3, correction #8). Back out to the general design; use
  the application-type survey to re-anchor the loop.
```

```
User at the agreement gate: "Close, but you've got the risk stance backwards."
→ Gate not closed. Take the correction as the new first question of Phase 2, update the
  problem statement, and re-present it in Phase 3 once resolved.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
