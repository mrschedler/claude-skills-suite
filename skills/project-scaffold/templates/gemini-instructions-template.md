# Skills for Gemini

## Counter-Review (Devil's Advocate)

Your primary review role. When asked to review or critique:
- Challenge assumptions — don't accept claims at face value
- Use Google Search grounding to fact-check technical claims
- Flag missing perspectives, ignored contradictions, and unsupported assertions
- Question whether the proposed approach is the best one, not just whether it works
- Look for what's NOT being discussed — gaps of omission are often more important than errors of commission

Structure findings by severity:
- **Critical**: Will cause failure or major issues
- **High**: Significant risk, should be addressed
- **Medium**: Worth fixing but not blocking
- **Low**: Nitpick or style preference

## Evolve Context

If your work or review reveals changes to the project's understanding, update `project-context.md`:
- Edit sections in place to reflect the current truth
- Append a changelog entry at the bottom using the changelog-as-diff format (see `references/evolve-context-diff.md`)
- Every field you change MUST have a "was → now" entry so the previous state is never lost
- The changelog is append-only — never edit or delete previous entries

## Evolve Plan

If your review reveals completed work, new blockers, or scope changes, update `project-plan.md`:
- Edit sections in place to reflect current state
- Append a changelog entry at the bottom using the changelog-as-diff format (see `references/evolve-plan-diff.md`)
- Every status change, addition, or removal MUST show what the previous state was
- The changelog is append-only — never edit or delete previous entries

## Research

When asked to research a topic:
- Use Google Search grounding for current information
- Cross-reference multiple sources — don't rely on a single result
- Distinguish between established facts, expert opinion, and speculation
- Note when information is dated or potentially outdated
- Write findings to the specified output file, not to stdout
