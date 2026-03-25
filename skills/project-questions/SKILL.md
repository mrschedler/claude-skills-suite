---
name: project-questions
description: Deep-dive interview to surface assumptions, gaps, and constraints before planning or building. Use when a new project idea is vague or needs more definition.
disable-model-invocation: true
---

# project-questions

Interview the user about their project until there are no fundamental gaps.
This is not a polite questionnaire — it probes assumptions, challenges vague
answers, and keeps digging until the project is defined enough to plan against.

## When to use

- User describes a project idea (even informally)
- User says "let's plan", "I want to build X", or "new project"
- GROUNDING.md exists but has empty or vague sections

## Inputs

| Input | Source | Required |
|---|---|---|
| Initial project description | User prompt | Yes |

## Instructions

1. **Open with a summary.** Restate understanding in 2-3 sentences. Ask "Is this
   accurate, or am I off?" Surfaces misunderstandings immediately.

2. **Run the interview.** Cover these categories — weave into natural conversation,
   follow threads where answers are interesting or vague:

   **Core understanding:**
   - What problem does this solve? For whom?
   - What happens if this doesn't exist? (Forces articulation of value)
   - What does success look like in 30 days? 90 days?

   **Users and scope:**
   - Who are the target users? Be specific.
   - What is explicitly NOT in scope?
   - Tool, product, service, internal thing, or prototype?

   **Technical:**
   - Hard tech constraints? (Language, framework, hosting, budget)
   - What does the user already know vs. what needs research?
   - Existing systems this integrates with?
   - Data model? (Even rough sketch)
   - Performance / scale requirements?

   **Prior art:**
   - Tried building this before? What happened?
   - Existing solutions? Why insufficient?
   - Reference projects or UIs admired?

   **Logistics:**
   - Timeline — hard deadline or open-ended?
   - Solo or team?
   - How will it be deployed and maintained?

3. **Poke holes.** After each answer, challenge assumptions:
   - "You said X, but that conflicts with Y — which takes priority?"
   - "You haven't mentioned auth — intentional or oversight?"
   - "That scope sounds like 6 months solo. What would you cut to ship in 6 weeks?"

   The goal is to surface gaps NOW when fixing them is free, not after 2 weeks
   of building the wrong thing.

4. **Know when to stop.** Done when:
   - You can explain the project to a stranger in 60 seconds
   - Problem, users, non-goals, tech stack, and constraints are known
   - Remaining questions are implementation details, not fundamentals
   - The user says "I think you've got it"

5. **Close with a summary.** Structured summary of everything learned. This
   feeds into `/project-organize` (GROUNDING.md) or `/project-context`.

## Exit condition

No fundamental gaps. Can articulate problem, users, scope, non-goals, tech
stack, and constraints without hedging. User confirmed the summary.

## Examples

```
User: "I want to build a dashboard for my homelab"
→ Restate. Then dig: What services? Just you? Real-time or polling?
  Mobile-friendly? What's wrong with existing dashboards (Heimdall, Homer)?
```

```
User: "I have an idea for a SaaS product"
→ Ask what it does — "SaaS" is a business model, not a product. Dig into
  target market, pricing, competitive landscape.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
