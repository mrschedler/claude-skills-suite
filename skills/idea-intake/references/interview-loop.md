# Interview Loop Checklist (Phase 2)

Run this after every single answer, before asking the next question. This is what keeps
the adaptive loop adaptive instead of a fixed list of questions asked one at a time. See
SKILL.md's Why This Exists for the direct quotes this loop implements.

## The checklist, after every answer

Do all five below before you ask anything else, in order. Write the result of each into
the running problem-statement document from SKILL.md's Outputs (a scratchpad or
artifact-DB file), not only into context: a session can be interrupted or compacted, and
a later correction needs the running state to return to, not a memory of it.

1. **Source check.** Before composing the next question, ask whether it can already be
   answered:
   - **Memory:** search Qdrant (`memory_call` search) for the topic and for the user's
     prior rulings on it.
   - **Project documents:** GROUNDING.md, PROGRESS.md, ENGINEERING-NOTEBOOK.md,
     `artifacts/project.db` via `db_search`, and the plans and reviews folders.
   - **The web:** WebSearch/WebFetch, or dispatch a Sonnet research agent.
   - **Current signal from X:** the Grok seat over interagent, for anything recent or
     contested that memory and docs cannot settle.
   Only a question that survives all four sources, meaning none of them answers it, gets
   asked. If any source does answer it, record the answer and skip the question. Do not
   be lazy about background already held: asking the user something memory, the project
   docs, the web, or X could answer wastes their time and undermines the interview.
2. **Update.** Revise the working problem statement and intent model with whatever the
   answer, and anything the source check turned up, changed. If the answer contradicts
   something already recorded, the record changes; it does not stack contradictions.
3. **Challenge assumptions.** List the guard rails and prior decisions the current
   framing depends on. For each, ask whether it still holds today rather than assuming
   it: check the memory's date and whether a newer ruling supersedes it; if it is a
   technical constraint, check the actual code or config, not a description of it.
   Surface anything that looks stale as a question or a finding, not a silent correction.
   Example from a real session: the design assumed a gateway's classification helpers
   gated egress; a live check of the code showed they run in audit mode and pass the very
   callers the design relied on them to block.
4. **Reframe or research.**
   - Does the answer change what the remaining questions should be? Drop the ones it
     already answered, reorder the ones it makes more urgent, rewrite the ones it
     reframes.
   - Does the answer open a gap that needs more research before anything downstream can
     be asked? Dispatch it now, by model tier (Sonnet routine, Opus judgment, Grok via
     interagent for live or social signal), and do not ask a question that depends on it
     until the research returns.
   - Did the user say, in any words, that the frame is too narrow? Treat this as the
     strongest possible reframe signal: stop going deeper into the current example
     immediately and back out to the general design.
5. **Judge sufficiency.** Run the test below. Only leave the loop on a genuine yes.

If step 5 is not yet a yes, go back to asking one question, informed by whatever steps
1-4 changed. The question list is not fixed: the final question is not known until the
second-to-last answer arrives, because each answer can retire questions, promote new
ones, or send one off to research before it can be asked.

## Sufficiency test

Answer each honestly. A rationalized yes to end the loop early defeats the point of the
loop.

- Do you know the **meta-goal** behind the example the user gave, not just the example
  itself? (The email-triage instance is not the product; the routing decision is.)
- Do you know the **classes of use** this idea covers, not just the first instance named?
- Do you know the **constraints from memory** that bear on this: retention stance,
  hardware, routing policy, prior rulings the user has already made?
- Do you know the user's **risk stance** on the open questions, from a researched
  comparison, not assumed from a generic default?
- Do you know what is **explicitly out of scope**?

If any answer is no and it is researchable, research it (dispatch by model tier) instead
of asking. If any answer is no and it is not researchable, that becomes the next single
question, after it passes the source check above. Only when every answer is yes does
sufficiency hold and the loop hands off to Phase 3.

## Common ways this loop is skipped

- Asking two questions in one message because they felt related. They are not asked
  together; the second one is informed by the first answer, or it is not.
- Treating "the residue from Phase 1 is exhausted" as sufficiency. The residue is a
  starting seed, not the finish line: an answer can open new questions the brief never
  anticipated.
- Judging sufficiency from how much detail you have about the one example in front of
  you, rather than whether you know the classes of use it belongs to.
- Skipping the update step because the answer "didn't change anything." If it genuinely
  did not, say so in the record; do not skip writing it.
- Asking from a pre-written list without re-reading the last answer. The residue from
  Phase 1 is a starting point, not a script; a question that was next in line can be
  wrong the moment the prior answer lands.
- Skipping the source check because the question "feels like" something only the user
  would know. Recent product details, specific numbers, and anything time-sensitive are
  exactly what a web search or a Grok X-signal check catches and a guess does not.
- Skipping the challenge-assumptions step because the current framing "obviously" still
  holds. Guard rails age; the fastest way to find a stale one is to check it, not to
  trust that it was checked once already.
