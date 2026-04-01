---
name: quick-plan
description: "Lightweight in-session planning. Quick structured plan with phases, acceptance criteria, and open questions. Not for formal project-plan.md — use /build-plan for that."
argument-hint: "<description> to start, refine to iterate"
---

# Quick Plan

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

### Constraints

- Stay in plan mode until user says "approve", "implement", or "go"
- Track change requests as a numbered checklist; confirm each before updating
- Present 2-3 options with tradeoffs for architectural decisions before committing
- Bullets only, no prose paragraphs
- Always include "Out of scope" to prevent creep
- Every phase needs concrete acceptance criteria ("it works" is not a criterion)

### For Refinement

When the user says `/quick-plan refine`:
1. Read the most recent plan file or context
2. Ask what needs to change (or infer from conversation)
3. Present a diff-style summary of changes
4. Update the plan preserving everything that wasn't changed
