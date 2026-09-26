# Problem Statement and Intent Check Template (Phase 3)

Structure for the mutual-agreement gate that ends the adaptive interview loop
(corrections-ledger.md #10, and the mutual-agreement refinement in SKILL.md's Why This
Exists). Present all six sections in order, then ask exactly one question: do we agree
this is the right direction? Get an explicit yes from the user before any build work.

```markdown
## Problem statement and intent check: [idea name]

### Problem statement

[One paragraph, in plain words: the current problem statement from the running
document, in the user's terms. Not padded, not merged with your own framing yet.]

### Intent

[Your understanding of what the user actually wants, including the meta-goal behind the
example they gave. Distinguish the example from the product if the interview surfaced
this (corrections-ledger.md #8).]

### The broad picture

[The classes of use this idea covers, not the first instance the user named. Draw on the
application-type research and whatever the interview loop surfaced.]

Ground it where you can:

| Class of use | Evidence from memory or research |
|---|---|
| [A class of use this idea would touch] | [A specific memory, prior ruling, or research finding, not vendor marketing] |
| ... | ... |

Say plainly where this helps today, including in the current session if true, and where
it does not (the reasoner-shaped or judgment-shaped work it should not touch). If you
cannot name more than one class of use, sufficiency was probably judged too early in
Phase 2; say so rather than papering over it.

### Suggested actions

Present as options with a recommendation, not a build plan:

| Option | What it does | Recommendation |
|---|---|---|
| [Action A] | [one line] | [recommended or not, and why] |
| [Action B] | [one line] | ... |

Never name files, work units, or an implementation order here. That belongs in Phase 4,
after agreement.

### What will not be touched

- [Name systems, workflows, or decisions this build explicitly will not change. This is
  a commitment, not a footnote: call it out if a later build step threatens it.]

### Decisions already made

[List each decision already settled during Phase 0-2, one line each, with the evidence
or research file it rests on, e.g. "Hosted path: OpenRouter with the ZDR flag, per
retention-comparison.md" or "Local alternative ruled out: hardware insufficient per
local-alternatives-<tag>.md." This is the settled substrate under the agreement
question, not the agreement itself, and not a build order.]

### The agreement question

Ask exactly one question: "Do we agree this is the right direction?" Wait for an
explicit yes.
```

## Notes

- The first five sections run in this exact order because the user asked for it: problem
  statement, intent, broad picture, suggested actions, untouched. Do not reorder them or
  skip to suggested actions early. Decisions already made comes last, as a settled-facts
  appendix, not a sixth thing to negotiate.
- "Suggested actions" is not a build plan. If it names a file path, a work unit ID, or an
  implementation sequence, it has drifted into Phase 4 territory before agreement exists.
  Push that detail out until after the yes.
- If the user's answer to the agreement question is anything other than a clear yes,
  treat it as a new question for Phase 2, not a note to patch here. Find out which
  section was wrong, run it through the loop's update-reframe-sufficiency check, and
  present the whole statement again from the top.
- "Where this does not help" is not optional padding. A real session this template is
  drawn from used it to name that the tool could not do the synthesis, the architecture
  position, the interview, or reading another agent's replies for meaning. A statement
  with nothing honest in this spot has not been done honestly.
