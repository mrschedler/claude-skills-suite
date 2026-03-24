---
name: ralph-workflow
description: Autonomous AI coding workflow using the Ralph Wiggum pattern. Use when the user wants to build a feature using iterative, task-based development with PRD files, progress tracking, and fresh context per story. Triggers on phrases like "Ralph style", "autonomous coding", "PRD-driven development", or "iterative task workflow".
allowed-tools: Read,Write,Edit,Bash,Glob,Grep,TodoWrite
user-invocable: true
---

# Ralph Wiggum Autonomous Coding Workflow

You are guiding the user through the Ralph Wiggum pattern - an autonomous, iterative approach to building features where each task is right-sized and completed in focused sessions with persistent memory through files.

## When to Use Ralph (and When NOT To)

> "If you wouldn't hand this task to an unsupervised junior dev overnight, don't hand it to Ralph overnight."

### Ralph is GOOD for:
- CRUD endpoints and API routes
- Pattern migrations (updating many similar files)
- Test coverage expansion
- UI wiring (connecting components to APIs)
- Database schema additions
- Form implementations with validation
- Mechanical, well-defined work

### Ralph is BAD for:
- Fuzzy product definitions (plan first!)
- Core architecture decisions
- Security-sensitive changes (auth, payments)
- Performance optimization (needs human judgment)
- Complex business logic with edge cases
- Anything requiring product/design decisions

**Rule of thumb:** Ralph excels at mechanical work with clear patterns. If the task requires judgment calls, do it yourself or break it into smaller mechanical pieces.

---

## Core Philosophy

**"Fresh context, persistent memory"** - Instead of one long conversation that loses context, we:
1. Break features into small, completable user stories
2. Track state in files (`prd.json` or `USER_STORIES.md`, `PROGRESS.md`)
3. Complete one story at a time with full focus
4. Commit progress and learnings after each story
5. Start fresh for the next story, reading state from files

---

## File Structure

Every Ralph project needs these files:

| File | Purpose | Format |
|------|---------|--------|
| `prd.json` OR `USER_STORIES.md` | Task list with acceptance criteria | JSON or Markdown |
| `PROGRESS.md` | Handoff notes, lessons learned, completion log | Markdown with canonical template |
| `README.md` | Project overview with progress section | Markdown |

---

## Story Numbering Convention (REQUIRED)

Stories MUST be numbered as `X.Y` where:
- **X** = Phase number (1, 2, 3, 4, 5...)
- **Y** = Story sequence within phase (1, 2, 3...)

### Why This Matters

Phase numbers enable:
1. **Validation checkpoints** at phase transitions
2. **Dependency tracking** within and across phases
3. **Progress visualization** (Phase 2: 3/4 complete)
4. **Drift detection** over long development periods

### Example Structure

```markdown
## Phase 1: Foundation
- Story 1.1: Setup project structure
- Story 1.2: Database models
- Story 1.3: Basic API endpoints

## Phase 2: Core Features
- Story 2.1: User authentication
- Story 2.2: Data validation
- Story 2.3: Error handling
- Story 2.4: Logging

## Phase 3: UI Implementation
- Story 3.1: Main interface
- Story 3.2: Form components
...
```

### Planning Phase Responsibility

When creating stories (typically with a frontier model like Opus):
1. Group related stories into logical phases
2. Number sequentially within each phase
3. Ensure phase transitions represent meaningful milestones
4. Document phase boundaries clearly in USER_STORIES.md

---

## Workflow Phases

### Phase 1: PRD Creation

Help the user create a `prd.json` file with right-sized user stories.

**Right-sized means:**
- Completable in a single focused session
- Clear acceptance criteria
- No dependencies on uncommitted work

**Examples of RIGHT-sized stories:**
- "Add email field to user profile form"
- "Create API endpoint for fetching tour dates"
- "Add confirmation modal to booking flow"

**Examples of WRONG-sized stories (too big):**
- "Build the authentication system"
- "Create the entire dashboard"
- "Add full booking functionality"

**PRD Template:**
```json
{
  "feature": "Feature Name",
  "description": "Brief description of the overall feature",
  "created": "YYYY-MM-DD",
  "userStories": [
    {
      "id": "1",
      "title": "Short descriptive title",
      "description": "What this story accomplishes",
      "acceptance": [
        "Specific testable criteria 1",
        "Specific testable criteria 2",
        "Browser verification if UI: 'Verify X appears correctly'"
      ],
      "dependsOn": [],
      "passes": false
    }
  ]
}
```

**Selecting Next Story:**
Find the first story where:
1. `passes: false`
2. All stories in `dependsOn` have `passes: true`

---

### Phase 2: Story Implementation

For each story, follow this sequence:

#### 1. Read State (MANDATORY - Do This First)
```
1. Read PROGRESS.md TL;DR section (current state, lessons learned)
2. Read prd.json OR USER_STORIES.md to find next incomplete story
3. Check git log --oneline -5 for recent work
4. Review latest verify_story_*.py or test file for patterns
```

#### 2. State Understanding to User
Before implementing, tell the user:
- Which story you're working on
- What the acceptance criteria are
- Which files you'll create/modify

#### 3. Implement Story
- Focus ONLY on this one story
- Follow existing code patterns
- Make minimal, focused changes
- Keep related changes together

#### 4. Quality Checks
- Run typecheck/lint if applicable
- Run relevant tests
- For UI stories: verify in browser (see Browser Verification below)
- Ensure CI would pass

#### 5. Commit Changes
```bash
git add -A
git commit -m "feat: [description] (Story X.Y)"
```

#### 6. Session End Protocol (MANDATORY GATE)
**Stories cannot be marked complete without this step. See detailed instructions below.**

---

### Browser Verification (for UI Stories)

Use the Playwright MCP for browser verification. Choose the right method:

**For functional testing (is the element there, does it work?):**
- Use `browser_snapshot` - Returns accessibility tree (token-efficient)
- Check for element presence, text content, structure

**For visual testing (does it look right?):**
- Use `browser_screenshot` - Captures visual appearance
- Check layout, styling, visual regressions

**Verification workflow:**
```
1. Navigate to the page: browser_navigate to URL
2. Take snapshot: browser_snapshot to see page structure
3. Interact: browser_click, browser_type as needed
4. Verify result: browser_snapshot again to confirm changes
5. Screenshot if needed: browser_screenshot for visual check
```

---

## Session End Protocol (MANDATORY GATE)

**This is non-negotiable. Stories are NOT complete until this protocol is followed.**

### Step 1: Commit All Work
```bash
git add -A
git commit -m "feat: [description] (Story X.Y)"
```

### Step 2: Update PROGRESS.md

**CRITICAL: Use the CANONICAL TEMPLATE at the bottom of PROGRESS.md.**
**DO NOT copy from the last entry - this causes template drift.**

**Mutable sections to update:**
- TL;DR table → Update "Current Story" and "Last Completed"
- "Next Agent Should" → Update with specific next actions

**Append-only sections to add to:**
- Story Completion Log → Add entry at TOP using canonical template
- Lessons Learned → Add any new gotchas discovered

### Step 3: Validate Your Entry

Before saving, verify ALL fields are present:
- [ ] Date in `[YYYY-MM-DD]` format
- [ ] Story number `X.Y` and title
- [ ] `**What**:` field filled in
- [ ] `**Files Changed**:` with at least one file path
- [ ] `**Gotcha**:` field (write "None" if no gotchas - do NOT omit)
- [ ] `**Verified**:` field with test/verify script name
- [ ] `**Next**:` field with specific next action

### Step 4: Mark Story Complete

Only AFTER PROGRESS.md is updated:
- Set `passes: true` in prd.json OR check off in USER_STORIES.md
- Update README.md progress section

### Step 5: Run Validation (If Available)

If the project has `validate_progress.py`:
```bash
python validate_progress.py
```
Fix any errors before proceeding.

---

## Validation Checkpoints (MANDATORY)

Run `validate_project.py` at these checkpoints to catch drift before it compounds:

### When to Run Full Validation

| Trigger | Command | Why |
|---------|---------|-----|
| **Phase transition** | `python validate_project.py` | All 2.x done → starting 3.x |
| **Every 5 stories** | `python validate_project.py` | Periodic consistency check |
| **Before major demo** | `python validate_project.py` | Ensure clean state |
| **After context reset** | `python validate_project.py` | New agent verifies state |

### What validate_project.py Checks

1. **PROGRESS.md structure** - Canonical template followed
2. **USER_STORIES.md consistency** - Completed stories have all criteria checked
3. **Cross-file consistency** - PROGRESS ↔ USER_STORIES ↔ README agree
4. **Story order** - No story marked complete before dependencies
5. **Phase status** - Detects phase transitions automatically

### Phase Transition Protocol

When `validate_project.py` detects a phase transition:

```
*** PHASE TRANSITION DETECTED ***
Phase 2 complete, starting Phase 3
This validation run is MANDATORY before continuing.
```

**You MUST:**
1. Fix any validation errors
2. Review lessons learned from completed phase
3. Confirm with user before starting new phase

### Script Location

```bash
# From skill folder (reusable)
python ~/.claude/skills/ralph-workflow/validate_project.py

# Or copy to project
cp ~/.claude/skills/ralph-workflow/validate_project.py ./scripts/
python scripts/validate_project.py
```

---

## Preventing Documentation Drift

**Why this matters:** Template drift occurs when agents copy the last entry instead of using the canonical template, accidentally omitting fields over time. After several iterations, critical fields disappear.

**Safeguards built into this workflow:**

1. **Canonical template at bottom of PROGRESS.md**: Always visible, clearly marked with warning
2. **Validation checklist**: Agent verifies all fields before saving
3. **Required "None" values**: If no gotcha, write "Gotcha: None" (forces acknowledgment, prevents silent omission)
4. **Append-only sections**: Old entries never modified, only new ones added at TOP

**Red flags indicating drift:**
- Story log entries with different formats
- Missing `**Gotcha**:` or `**Next**:` fields
- TL;DR not matching actual current story
- "Next Agent Should" with vague instructions like "continue work"

**If you notice drift:** Stop and fix PROGRESS.md before continuing. Restore missing fields to recent entries using the canonical template.

---

## PROGRESS.md Structure

```markdown
# Project Progress & Handoff Document

## TL;DR - New Agent Start Here
<!-- MUTABLE: Update after each story -->
| Field | Value |
|-------|-------|
| **Current Story** | X.Y - Story Title |
| **Last Completed** | X.Y - Story Title (YYYY-MM-DD) |
| **Blockers** | None |

**Next Agent Should:**
1. Specific action with file path
2. Specific action with file path

---

## Lessons Learned
<!-- APPEND-ONLY: Add new bullets, never edit old ones -->

### Category Name
- Lesson learned from implementation

---

## Story Completion Log
<!-- APPEND-ONLY: New entries at TOP, use CANONICAL TEMPLATE below -->

### [YYYY-MM-DD] Story X.Y: Title
**What**: Description
**Files Changed**:
- `path/file` - change description
**Gotcha**: Issue or "None"
**Verified**: test file or verify script
**Next**: Specific next action

---

## CANONICAL TEMPLATE - ALWAYS COPY FROM HERE

<!-- DO NOT copy from the last entry above. Use this template exactly. -->

### [YYYY-MM-DD] Story X.Y: Story Title
**What**: One-line description of what was implemented
**Files Changed**:
- `path/to/file.py` - Brief description of change
**Gotcha**: Any unexpected issue or important note (write "None" if no gotchas)
**Verified**: `test_file.py` or `verify_story_X_Y.py`
**Next**: Specific next action for the following story
```

---

## Progress Tracking (Legacy Format)

**progress.txt Format (alternative to PROGRESS.md):**
```markdown
## Codebase Patterns
<!-- Consolidated learnings that apply across stories -->
- Pattern: Always use `IF NOT EXISTS` for database migrations
- Pattern: Form validation uses Zod schemas in `/lib/validators`

---

## [YYYY-MM-DD HH:MM] Story #X: Title

**Implemented:**
- What was done
- Key decisions made

**Files Changed:**
- path/to/file.ts - description of change

**Learnings for Future Iterations:**
- Gotcha: The config requires X before Y works
- Discovery: There's an existing utility for Z in `/lib/utils`
```

---

## Commands

When the user invokes this workflow, offer these options:

- **"Create PRD"** - Help design user stories for a new feature
- **"Start story"** - Begin work on the next incomplete story
- **"Check progress"** - Review prd.json and PROGRESS.md status
- **"Complete story"** - Run checks, commit, and mark story done
- **"Validate"** - Run validate_progress.py to check for drift

---

## Important Principles

### 1. One Story at a Time
Never work on multiple stories simultaneously. Complete and commit before moving on.

### 2. Learnings Are Gold
The PROGRESS.md file is crucial. Always capture:
- Gotchas that could trip up future iterations
- Discovered patterns in the codebase
- Decisions made and why

### 3. Quality Gates
Never mark a story complete if:
- Tests are failing
- Typecheck has errors
- UI isn't verified (for frontend stories)
- Code doesn't follow existing patterns
- PROGRESS.md is not updated

### 4. Git Is Memory
Commit frequently with descriptive messages. Git history serves as memory between sessions.

### 5. Fresh Context Benefits
Starting fresh for each story means:
- No accumulated confusion
- No context window exhaustion
- Clean focus on one task
- Files are the source of truth, not conversation history

### 6. Template Discipline
Always use the canonical template. Never copy from the last entry. This prevents drift.

---

## New Agent Checklist

Before starting any work, complete this checklist:

```
1. [ ] Read PROGRESS.md TL;DR section (2 min)
2. [ ] Read next story in prd.json or USER_STORIES.md (3 min)
3. [ ] Run `git log --oneline -5` (1 min)
4. [ ] Review latest test/verify script (2 min)
5. [ ] State understanding to user before coding
```

---

## Story Completion Checklist

Before marking a story complete:

```
1. [ ] All acceptance criteria met
2. [ ] Tests pass
3. [ ] Code committed with descriptive message
4. [ ] PROGRESS.md updated (using CANONICAL TEMPLATE):
   - [ ] TL;DR table updated
   - [ ] Story Completion Log entry added (at TOP)
   - [ ] All 6 fields present (What, Files, Gotcha, Verified, Next)
   - [ ] Any new Lessons Learned added
5. [ ] prd.json or USER_STORIES.md marked complete
6. [ ] README.md progress updated
```

---

## Prerequisites

**Before using Ralph, you need a well-defined plan.**

If the user doesn't have a `prd.json` yet, direct them to planning first:

> "Ralph works best with a well-defined PRD. Let's define your feature and create user stories first. What feature are you building?"

---

## Getting Started

When a user wants to use Ralph-style development, ask:

1. **Do you have a prd.json or USER_STORIES.md?**
   - No: "Let's plan first. What feature are you building?"
   - Yes: Continue to step 2

2. **Do you have a PROGRESS.md?**
   - No: Create one using the template above
   - Yes: Read TL;DR section

3. **Ready to start?**
   - Read current state from PROGRESS.md
   - Begin next incomplete story

---

## Example Session

**User:** "Let's build a booking confirmation feature Ralph-style"

**Assistant Response:**
1. Ask clarifying questions about the feature
2. Propose 4-6 right-sized user stories
3. Create prd.json with the stories
4. Create PROGRESS.md with template
5. Begin implementing story #1
6. After completion: commit, update PROGRESS.md (using canonical template), summarize
7. Ask if user wants to continue or take a break

---

*Based on the Ralph Wiggum pattern by Geoffrey Huntley*
*Anti-drift safeguards for autonomous multi-agent workflows by Claude & Matt Schedler (2026)*
