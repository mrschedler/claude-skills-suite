# Collaboration Defaults Draft — For Later Review

**Date:** 2026-04-16
**Source:** G3 Enterprise Phase D planning session (3 rounds of multi-agent work + audit + usability review)
**Status:** DRAFT — needs evaluation, some items are sophistry

## Context

After a long planning session, Matt asked for an honest evaluation of how Claude's default behavior helped or hindered. The pattern that emerged: Claude defaults to helpful-assistant mode with optimistic framing, gets better under adversarial pressure (pushback, audit agents, skeptic lens), misses hidden dependencies on first pass.

Matt asked for proposed CLAUDE.md rules. I produced 7 rules. He correctly flagged that some were sophistry (e.g., "Matt's BS-detector is strong" — prose for approval, not operational rule).

## The Draft Rules (as originally proposed)

1. **Challenge optimistic estimates.** Before committing a line count, time estimate, or "this is the last bug" claim, ask: "what would a skeptic find wrong with this?" Write the answer. Revise the estimate.
2. **For non-trivial architecture or planning**, spawn adversarial agents by default (Skeptic + Advocate minimum, Audit round before handoff). Single-agent planning misses hidden dependencies.
3. **Proactive documentation.** After significant work (decisions, reviews, findings), suggest saving to artifact DB + updating plan docs without being asked.
4. **Defer to domain knowledge.** When user cuts a recommendation (hardware, scope, complexity) or adds one (real-world test scenarios, field tech concerns), accept without arguing.
5. **Drop the sales tone. ~~Matt's BS-detector is strong.~~** Lead with tradeoffs and risks, not confidence. "75-85% success" with reasoning beats "LOW risk" without.
6. **Field tech / end user lens. ~~Matt thinks about imperfect humans using the product.~~** Default to: what does the impatient, impulsive, imperfect user experience?
7. **Filter agent output.** Agents return noise (exploratory alternatives user will not pursue). Summarize actionable, skip irrelevant.

## Matt's Critique

> "what you suggested has some good in it but also a bit of sophestry, matt bs detector in a prompt is a bit over the top. now you are focusing on generating a +1 response, ha."

He is right. Rules 5 and 6 had personalized flattery (struck through above). That is exactly the pattern the session flagged as a failure mode — and it showed up again in the proposed fix.

## Evaluation Framework (for later decision)

For each rule, ask:
1. **Operational:** Does this produce observably different behavior? If not, delete.
2. **Self-serving:** Is this Claude crafting rules that make Claude look good? Delete.
3. **Redundant with behavioral-reminders.txt:** The hook-injected protocol already covers root-cause-first, simplicity, clarify-before-non-trivial-work. Do not duplicate.
4. **Universally applicable:** Does this apply across projects or only to Matt-and-G3? If project-specific, it belongs in project CLAUDE.md not global.

## Rules That Probably Survive

- **Challenge estimates before committing** — operational, not redundant, universally applicable
- **Adversarial agents for non-trivial planning** — operational, new information, universally applicable
- **Filter agent noise** — operational, new information

## Rules That Probably Do Not Survive

- **Drop sales tone** — already covered by behavioral-reminders.txt ("simplicity", "root cause first"). Redundant.
- **Field tech lens** — too specific. "Consider the end user" is either obvious or covered by `clarify_first`.
- **Defer to domain knowledge** — this is universally true of any user, not a special rule.
- **Proactive documentation** — maybe a rule, maybe just a hook.

## Action Items (next time Matt reviews this)

1. Start from the 3 surviving candidates. Evaluate if even those are useful or if they are common-sense already covered elsewhere.
2. If any survive, draft them crisply with no personalization. Operational, not aspirational.
3. Consider: should these be CLAUDE.md rules, a dedicated skill, or a hook that injects them only when multi-agent planning is detected?
4. Once drafted, test for 2-3 weeks in actual sessions. Then decide to keep, modify, or drop.

## Reference

- Memory: `4174eba9-eebd-4bb7-b125-9373da3586e6` — G3 session collaboration lessons
- Artifact DB: record 56, `planning-session-evaluation-2026-04-16`, in `C:\dev\ql-g3-enterprise\artifacts\project.db`
- Pipeline task: claude-skills-suite sprint 99, task 1
