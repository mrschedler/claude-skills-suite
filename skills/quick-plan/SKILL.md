---
name: quick-plan
description: "Lightweight in-session planning. Quick structured plan with phases, acceptance criteria, and open questions. Not for formal project-plan.md — use /build-plan for that."
argument-hint: "<description> to start, refine to iterate"
---

# Quick Plan

Create or refine a structured implementation plan in-session. This is for quick planning — not a formal project-plan.md artifact.

## Usage

```
/quick-plan <description>         Start a new plan
/quick-plan refine                Continue refining the current plan
```

## Instructions

When creating or refining a plan, follow this structure strictly:

### Plan Format

Write the plan using this template — bullets only, no prose paragraphs:

```markdown
# Plan: <Title>

## Objective
- <1-2 bullet points describing the goal>

## Scope
**In scope:**
- ...

**Out of scope:**
- ...

## Prerequisites
- [ ] <Things that must be true before starting>

## Phases

### Phase 1: <Name>
**Tasks:**
- [ ] Task description
- [ ] Task description

**Acceptance criteria:**
- <How to verify this phase is done>

### Phase 2: <Name>
...

## Open Questions
- <Anything unresolved that needs user input>

## Files to Create/Modify
| File | Action | Purpose |
|------|--------|---------|
| ... | CREATE/MODIFY | ... |
```

### Behavioral Rules

1. **Stay in plan mode** until the user explicitly says "approve", "implement", "go", or similar. Never exit plan mode on your own.
2. **Track change requests** — when the user asks for modifications, maintain a numbered checklist of all requested changes. Confirm each is addressed before presenting the updated plan.
3. **Present approaches first** — if the plan involves architectural decisions or multiple valid paths, present 2-3 options with tradeoffs before committing to one.
4. **Keep it concise** — bullet points, not paragraphs. The plan should fit in a quick read, not a thesis.
5. **Scope boundaries matter** — always include "Out of scope" to prevent creep. If the user asks for something outside scope, flag it explicitly.
6. **Acceptance criteria are mandatory** — every phase needs a concrete way to verify it's done. "It works" is not a criterion.

### For Refinement

When the user says `/quick-plan refine`:
1. Read the most recent plan file or context
2. Ask what needs to change (or infer from conversation)
3. Present a diff-style summary of changes
4. Update the plan preserving everything that wasn't changed
