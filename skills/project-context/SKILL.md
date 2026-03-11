---
name: project-context
description: Writes project-context.md, the definitive handoff artifact. Use after project-questions interview or when project-context.md is missing or stale. Any agent must be able to cold-start from it.
disable-model-invocation: true
---

# project-context

Write `project-context.md` — the comprehensive project context document that
any agent (Claude, Codex, Gemini, Copilot) can read to cold-start on this
project with zero additional context. This is the single most important file
in the project. If the project burned down and you could save one document,
save this one.

## When to use

- The `project-questions` interview just finished and context is in the
  conversation.
- User says "write the context doc" or "create project context."
- A project exists but has no `project-context.md`.
- An existing `project-context.md` is stale and needs a full rewrite (for
  incremental updates, use `evolve-context` instead).

## Inputs

| Input | Source | Required |
|---|---|---|
| Interview context | Conversation history from project-questions | Yes |
| Project root path | cwd or user prompt | Yes |
| context-template.md | Bundled in `templates/` beside this skill | Yes |

## Instructions

1. **Gather raw material.** Read through the conversation history from the
   `project-questions` phase. If that skill was not run and the user is asking
   you to write context from scratch, warn them: "The context doc will be
   stronger if we run the interview first. Proceed anyway?" Respect their
   choice either way.

2. **Use the template.** Copy `templates/context-template.md` as the skeleton.
   Fill in every section. The template includes these sections — do not skip
   any:

   - **What Is This** — One paragraph. A stranger should understand the project
     after reading this.
   - **Problem Statement** — What specific problem does this solve? Why does it
     matter?
   - **Target Users** — Who, specifically. Not "developers" — be precise.
   - **Non-Goals** — What this project explicitly does NOT do. Equally
     important as goals because it prevents scope creep and tells agents where
     NOT to go.
   - **Tech Stack** — Languages, frameworks, databases, hosting. Include
     version constraints if known.
   - **Architecture Overview** — High-level system design. Reference a diagram
     if one exists in `docs/`. A few sentences or a bullet list for simple
     projects; more detail for complex ones.
   - **Project Structure** — Directory layout with one-line descriptions of
     each top-level folder/file. Keep it current.
   - **Key Decisions** — Table format with columns: Decision, Alternatives
     Considered, Why This One. This is critical — the "why" behind decisions
     prevents agents from re-litigating settled questions. Every non-obvious
     choice belongs here.
   - **Current State** — What exists today. What works, what's broken, what's
     in progress. Update this section on every major milestone.
   - **Constraints** — Hard limits: budget, timeline, platform, compliance,
     performance SLAs. Anything that constrains design choices.
   - **Open Questions** — Unresolved issues that need answers before
     proceeding. Tag each with priority (P0 = blocks progress, P1 = important,
     P2 = nice to resolve).
   - **Glossary** — Domain-specific terms. Agents from different model families
     may not share vocabulary — define terms explicitly.

3. **Write for cold-start.** The reader has never seen this project. They do
   not have the conversation history. They do not know what you know. Write
   accordingly:
   - Spell out acronyms on first use.
   - Link to relevant files by relative path.
   - Include the "why" behind every decision — not just what was chosen, but
     why alternatives were rejected.
   - Keep it under ~200 lines. This is a reference document, not a novel. If
     a section needs more depth, put it in `docs/` and link to it.

4. **Review for completeness.** Before presenting to the user, re-read the
   document and ask: "Could a senior developer with no context about this
   project read this and start contributing in 30 minutes?" If not, fill the
   gaps.

5. **Present for approval.** Show the user the complete document. Ask for
   corrections, additions, or approval. Do not write the file until the user
   says it's good — this is too important to get wrong silently.

6. **Write the file.** Save as `project-context.md` in the project root.

## Exit condition

`project-context.md` exists in the project root. Every template section is
filled (no placeholders, no TODOs). The user has reviewed and approved it.

## Examples

```
User: [Just finished project-questions interview]
      "OK, write the context doc."
Action: Synthesize everything from the interview into project-context.md
        using the template. Present for review. Write on approval.
```

```
User: "This project needs a context doc. Here's the gist: it's a REST API
       for inventory management, built in Go, deployed on Kubernetes."
Action: Warn that the interview would strengthen the doc. If user wants to
        proceed, write what you can, mark gaps as Open Questions, and flag
        sections that need more input.
```

```
User: "The project-context.md is out of date, rewrite it."
Action: Read the existing file first. Ask what changed. Rewrite the full
        document, preserving still-accurate sections and updating the rest.
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
