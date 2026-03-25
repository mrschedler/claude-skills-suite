---
name: project-context
description: Writes project-context.md, a comprehensive handoff document. Use after a project-questions interview or when project-context.md is missing or stale. Complements GROUNDING.md with deeper technical detail.
---

# project-context

Write `project-context.md` — a comprehensive project context document that any
agent can read to cold-start with zero additional context. This complements
GROUNDING.md (which covers why and constraints) with deeper technical detail
(architecture, structure, state).

If a project already has a thorough GROUNDING.md, project-context.md may not
be needed. Use this when the project's technical complexity warrants a separate,
detailed reference doc.

## When to use

- After a `project-questions` interview, to capture the depth
- A project exists but lacks comprehensive technical context
- An existing project-context.md is stale and needs a full rewrite

## Inputs

| Input | Source | Required |
|---|---|---|
| Interview context | Conversation history from project-questions | Yes |
| Project root path | cwd or user prompt | Yes |
| GROUNDING.md | Project root (if exists) | No — build on it, don't duplicate |

## Instructions

1. **Gather raw material.** Read conversation history from the interview. If
   `project-questions` was not run, warn: "The context doc will be stronger
   if we run the interview first. Proceed anyway?" Respect the choice.

2. **Read GROUNDING.md if it exists.** Don't duplicate what's already there.
   project-context.md adds depth — architecture detail, project structure,
   current state, glossary. GROUNDING.md covers the why.

3. **Write the document** with these sections (skip any already covered in GROUNDING.md):

   - **What Is This** — one paragraph, a stranger should understand after reading
   - **Problem Statement** — what problem, why it matters
   - **Target Users** — specific, not "developers"
   - **Non-Goals** — what this explicitly does NOT do
   - **Tech Stack** — languages, frameworks, databases, hosting, versions
   - **Architecture Overview** — high-level system design
   - **Project Structure** — directory layout with one-line descriptions
   - **Key Decisions** — table: Decision | Alternatives | Why This One
   - **Current State** — what exists, what works, what's broken, what's in progress
   - **Constraints** — hard limits (budget, timeline, platform, compliance)
   - **Open Questions** — unresolved issues, tagged P0/P1/P2
   - **Glossary** — domain-specific terms

4. **Write for cold-start.** Spell out acronyms. Link to files by relative path.
   Include the "why" behind every decision. Keep it under ~200 lines.

5. **Present for approval.** Show the complete document. Ask for corrections.
   Do not write the file until the user approves.

6. **Write the file.** Save as `project-context.md` in the project root.

## Exit condition

`project-context.md` exists. Every section filled (no placeholders). User approved.

## Examples

```
User: [After interview] "Write the context doc."
→ Synthesize everything into project-context.md. Present for review.
```

```
User: "The project-context.md is out of date, rewrite it."
→ Read existing file. Ask what changed. Rewrite, preserving accurate sections.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
