---
name: todo-features
description: Updates todo.md and features.md to reflect current project state. Invoke explicitly with /todo-features — do NOT auto-trigger after other skills.
disable-model-invocation: true
argument-hint: [optional: "todo" to update only todo.md, "features" to update only features.md, omit to update both]
---

# Todo & Features

Maintain two living documents: `todo.md` (what needs doing now) and `features.md` (what the thing does and will do). These are intentionally separate from `project-plan.md` — three different lenses on the same project.

## The Three Lenses

- **project-plan.md** — How we're building it. Phases, work units, dependencies, sequencing. The builder's view.
- **todo.md** — What needs doing right now. Actionable items, ordered by priority. The operator's view.
- **features.md** — What the thing does and will do. Capabilities, status, user-facing behavior. The product view.

These overlap intentionally. A work unit in the plan might generate three todos and describe one feature. Keeping them separate means each document answers its own question cleanly.

## Instructions

### Updating todo.md

1. **Read the current todo.md** (if it exists) and **project-plan.md**. Understand what's already tracked and what the plan says is next.

2. **Sync with reality.** Remove or check off items that are done. Add items discovered during recent work. Re-prioritize based on current blockers and dependencies.

3. **Format consistently.** Use this structure:

   ```markdown
   # Todo

   ## Now (current sprint / immediate)
   - [ ] Item with enough context to act on without re-reading the plan
   - [ ] Item referencing work unit if applicable (WU-N)

   ## Next (queued, unblocked)
   - [ ] Item
   - [ ] Item

   ## Later (blocked or low priority)
   - [ ] Item — blocked by [what]
   - [ ] Item — low priority, revisit after [milestone]

   ## Done (recent, for context)
   - [x] Item — completed YYYY-MM-DD
   ```

4. **Each item should be actionable.** "Fix auth" is too vague. "Add JWT expiry validation to auth middleware (WU-3)" tells someone what to do. Include enough context that the item stands alone.

5. **Keep the Done section short.** Only the last 5-10 completed items, for context. Older items get removed — the plan changelog is the permanent record.

### Updating features.md

1. **Read the current features.md** (if it exists) and **project-context.md**. Understand what capabilities are documented and what the project currently supports.

2. **Sync with reality.** Update feature statuses based on what's been built. Add newly discovered features. Mark features that were cut or deferred.

3. **Format consistently.** Use this structure:

   ```markdown
   # Features

   ## Shipped
   - **Feature Name** — Brief description of what it does, from the user's perspective.

   ## In Progress
   - **Feature Name** — What it will do. What's left to finish. (WU-N if applicable)

   ## Planned
   - **Feature Name** — What it will do. Why it matters. Expected phase.

   ## Deferred / Cut
   - **Feature Name** — What it was. Why it was deferred/cut. Revisit condition.
   ```

4. **Write from the user's perspective.** Features describe what the product does, not how the code works. "JWT-based authentication" is a feature. "AuthMiddleware class with RS256 validation" is an implementation detail for the plan.

### Creating from Scratch

If neither file exists (first run, typically during init):
1. Read `project-context.md` and `project-plan.md`.
2. Derive the initial todo list from the plan's first phase and any prerequisites.
3. Derive the initial feature list from the project scope and planned capabilities.
4. Write both files using the formats above.

## Examples

```
User: /todo-features
```
Read both files and the plan/context. Update todo.md with newly completed items checked off and any new items. Update features.md with any status changes.

```
User: update the todos — we just finished the auth layer
```
Read todo.md. Check off auth-related items. Add any follow-up items that emerged. Move items from "Next" to "Now" if they're unblocked.

```
User: /todo-features features
```
Only update features.md. Read project-context.md for current state. Move features between Shipped/In Progress/Planned as appropriate.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
