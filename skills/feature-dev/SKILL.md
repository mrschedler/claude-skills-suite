---
name: feature-dev
description: Unified feature development skill. Automatically determines appropriate rigor level based on task complexity. Use for any development work - from quick fixes to complex features. Triggers on "build a feature", "implement", "develop", "create functionality", or when user describes work that needs planning.
allowed-tools: Read,Write,Edit,Bash,Glob,Grep,AskUserQuestion,TodoWrite
user-invocable: true
---

# Feature Development Skill

One skill that adapts to what you are building. No unnecessary ceremony for simple tasks. Full rigor when complexity demands it.

---

## Always: Project Memory (CLAUDE_NOTES.md)

**Every project should have a CLAUDE_NOTES.md file.** This is separate from task tracking - it is persistent context that survives across sessions, days, or weeks.

### On Session Start
1. Check for CLAUDE_NOTES.md in project root
2. If exists: Read it to understand project context, recent work, known issues
3. If missing: Create it after understanding the project

### On Session End (or significant milestones)
Update the notes with:
- What was accomplished
- Any new patterns discovered
- Known issues or next steps
- Anything future-you needs to know

### Why This Matters
- User often returns to projects days/weeks later with no more memory than Claude
- Reading this file gives instant context without re-exploring the codebase
- Low overhead (one file to read/update) but high value

---

## Then: Assess Complexity

| Complexity | Signals | Approach |
|------------|---------|----------|
| **Simple** | Single file, clear fix, under 30 min | Just do it |
| **Medium** | 2-4 files, clear scope, 1-2 hours | Light planning, then do it |
| **Complex** | 5+ files, unclear scope, multiple sessions | Full PRD + Ralph workflow |

---

## The PRD Format (When Needed)

Only create prd.json for complex, multi-session work. Stories need: id, title, description, acceptance criteria, dependsOn array, passes boolean.

---

## Progress Tracking (For Multi-Session Work)

Create progress.txt for complex features with: Patterns Discovered, per-story entries (Done, Files, Learned, Build Status).

---

## The Ralph Pattern (When You Step Away)

1. Create prd.json with remaining stories
2. Each new session: Read prd.json, find next incomplete story, implement it
3. After each story: Mark passes: true, append to progress.txt
4. Fresh context = fresh focus

---

## Autonomous Execution (No Approval Gates)

**For running without human oversight or with Sonnet/Haiku.**

### Start of Each Iteration
1. Read CLAUDE_NOTES.md (required)
2. Read prd.json (find current story)
3. Read progress.txt (see previous iterations)
4. Check git log --oneline -5
5. Run build/tests - fix failures first

### During Execution
- Implement ONE story only
- Follow existing code patterns
- Make minimal, focused changes
- Run build + tests frequently

### End of Each Iteration (Write to FILES)
1. Git commit with descriptive message
2. Update prd.json: Set passes: true
3. Append to progress.txt: What, files, gotchas, build status
4. Update CLAUDE_NOTES.md if needed

### If Something Breaks
- Do NOT mark story complete
- Document failure in progress.txt
- Next iteration can diagnose/fix
- Git history enables rollback

---

## Browser Verification (UI Stories)

Use Playwright MCP for UI stories:
- browser_navigate to URL
- browser_snapshot for structure (token-efficient)
- browser_screenshot for visual verification
- Document results in progress.txt

---

## Quality Gates (Non-Negotiable)

Before marking ANY story passes: true:
- Build passes
- TypeCheck passes (if TypeScript)
- Related tests pass
- UI verified (if applicable)
- Code follows existing patterns
- No regressions

If ANY gate fails: Do NOT mark complete. Document in progress.txt.

---

## Git Commit Protocol (Required)

### Commit Timing
- Commit AFTER each completed story
- Each story = one atomic commit = one rollback point
- Never batch multiple stories

### Commit Format
feat|fix|refactor: Short description (Story #X)
- What was changed
- Why it was changed
Co-Authored-By: Claude <noreply@anthropic.com>

### Rollback
- git log --oneline (see iterations)
- git diff HEAD~1 (see changes)
- git revert HEAD (undo cleanly)
- git reset --hard HEAD~1 (nuclear)

### Never
- Commit broken code
- Use vague messages
- Skip commits

---

## What NOT to Do

- Create prd.json for simple fixes
- Ask questions when task is obvious
- Skip git commits in autonomous mode
- Mark stories complete if gates fail

## What TO Do

- Match rigor to complexity
- Always maintain CLAUDE_NOTES.md
- Always commit after each story
- Always run quality gates

---

## Quick Reference

| Task Type | Planning | Notes | Tracking | Gates | Commits |
|-----------|----------|-------|----------|-------|---------|
| Simple | None | If relevant | None | Basic | One when done |
| Medium | Inline | After | None | Build+test | Per unit |
| Complex | prd.json | Per story | progress.txt | Full | Per story |
| Autonomous | prd.json | Each iteration | progress.txt | Strict | Required |

---

*Rigor should serve the work, not the other way around.*
