---
name: project-questions
description: Deep-dive interview to surface assumptions, gaps, and constraints before planning or building. Use when a new project idea is vague or project-context needs more info.
disable-model-invocation: true
---

# project-questions

Interview the user about their project until there are no fundamental gaps in
understanding. This is not a polite questionnaire — it is an aggressive probe
that pokes holes in assumptions, challenges vague answers, and keeps digging
until the project is well-defined enough to plan against.

## When to use

- User describes a project idea (even informally).
- User says "let's plan", "I want to build X", or "new project."
- The `project-context` skill needs input but the conversation lacks depth.
- A project-context.md exists but has empty or vague sections.

## Inputs

| Input | Source | Required |
|---|---|---|
| Initial project description | User prompt | Yes |
| Domain keywords | Extracted from description | Auto |

## Instructions

### Phase 0: Domain Research (Gemini)

Before interviewing the user, ground yourself in the project's domain:

1. Check Gemini availability: `which gemini >/dev/null 2>&1`
2. If available, run domain research:
   ```bash
   unset DEBUG 2>/dev/null
   GTIMEOUT="/opt/homebrew/bin/gtimeout"; GEMINI="/Users/trevorbyrum/.npm-global/bin/gemini"
   test -x "$GEMINI" || GEMINI="/opt/homebrew/bin/gemini"
   $GTIMEOUT 120 "$GEMINI" --agent generalist -p \
     "Research the domain of [PROJECT_DESCRIPTION]. Cover: key terminology, common patterns, existing solutions, market landscape, and common pitfalls. Be specific and practical — this will inform a project interview." \
     2>/dev/null
   ```
3. Use the research output to ask better, more informed questions during the interview. Reference specific domain knowledge to surface assumptions the user might not think to mention.
4. If Gemini is unavailable, proceed without domain research — the interview still works, just with less domain grounding.

1. **Open with a summary.** Restate what you understood from the user's
   description in 2-3 sentences. Ask "Is this accurate, or am I off?" This
   surfaces misunderstandings immediately instead of 20 questions deep.

2. **Run the interview.** Cover these categories. Do not ask them as a
   checklist dump — weave them into a natural conversation, following threads
   where the user gives interesting or vague answers:

   **Core understanding:**
   - What problem does this solve? For whom?
   - What happens if this project doesn't exist? (Forces articulation of value)
   - What does success look like in 30 days? 90 days?

   **Users and scope:**
   - Who are the target users? Be specific — "developers" is too broad.
   - What is explicitly NOT in scope? (Non-goals are as important as goals)
   - Is this a tool, a product, a service, an internal thing, or a prototype?

   **Technical:**
   - Any hard tech constraints? (Language, framework, hosting, budget)
   - What does the user already know vs. what needs research?
   - Are there existing systems this integrates with?
   - What's the data model? (Even a rough sketch)
   - Performance requirements? Scale expectations?

   **Prior art and context:**
   - Has the user tried building this before? What happened?
   - Are there existing solutions? Why are they insufficient?
   - Reference projects or UIs the user admires?

   **Logistics:**
   - Timeline — hard deadline or open-ended?
   - Solo or team? Who else touches this?
   - How will it be deployed and maintained?

3. **Poke holes.** After each answer, ask yourself: "Does this actually hold
   up?" Challenge assumptions directly:
   - "You said X, but that conflicts with Y — which takes priority?"
   - "You haven't mentioned authentication — is that intentional or an
     oversight?"
   - "That scope sounds like 6 months of work for a solo dev. What would you
     cut to ship in 6 weeks?"

   The goal is not to be adversarial for sport — it is to surface the gaps NOW
   when fixing them is free, not after 2 weeks of building the wrong thing.

4. **Know when to stop.** The interview is done when:
   - You can explain the project to a stranger in 60 seconds.
   - You know the problem, the user, the non-goals, the tech stack, and the
     constraints.
   - Your remaining questions are implementation details, not fundamentals.
   - The user says "I think you've got it."

5. **Close with a summary.** At the end, provide a structured summary of
   everything learned. This stays in conversation context — the `project-context`
   skill will consume it to write `project-context.md`.

## Exit condition

No fundamental gaps remain. You can articulate the project's problem, users,
scope, non-goals, tech stack, and constraints without hedging. The user has
confirmed the summary.

## Examples

```
User: "I want to build a dashboard for my homelab"
Action: Gemini-ground "homelab dashboard" domain. Restate understanding. Then
        dig: What services? Who uses it — just you? Real-time or polling?
        Mobile-friendly? What's wrong with existing dashboards (Heimdall,
        Homer, Homarr)? Keep going until the vision is concrete.
```

```
User: "Let's plan a CLI tool for managing dotfiles"
Action: Gemini-ground "dotfiles manager CLI" domain. Ask: Which OS? Symlinks
        or copies? Templating? How is it different from chezmoi/stow/yadm?
        What's the install story? Challenge: "If stow already does this, what
        specifically does it get wrong for you?"
```

```
User: "I have an idea for a SaaS product"
Action: Immediately ask what the product does — "SaaS" is a business model,
        not a product. Then dig into target market, pricing model, competitive
        landscape. Challenge unit economics if the user mentions "free tier."
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
