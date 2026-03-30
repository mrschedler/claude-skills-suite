# Sub-Project Context Strategy

## Why Sub-Projects Exist

Quality at 100K tokens is fundamentally different from quality at 500K. Sub-projects
keep every session in the high-accuracy zone by partitioning a parent project into
a focused sub-workspace.

## Context-Window Strategy

Non-interactive phases delegate to subagents. The discovery interview (Phase 2)
stays inline. Each subagent reads its own instructions from `agents/` — never
load reference files into main context unless explicitly needed.

## Merge-Back Guidance

When the sub-project is complete and ready to merge back:

1. Run integration tests from the parent root
2. Check for convention drift (run `/compliance-review` from parent)
3. Update parent's `project-plan.md` to reflect completed work
4. Remove worktree if used: `git worktree remove <path>`
5. Clean up the sub-project branch if merged

This guidance is documented in the sub-project's `architecture.md` under
"Known Constraints" so future sessions have it.
