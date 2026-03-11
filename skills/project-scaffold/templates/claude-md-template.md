# {{PROJECT_NAME}}

IMPORTANT: Read these files before starting any task:
- `project-context.md` — architecture, decisions, constraints
- `features.md` — what the product does
- `project-plan.md` — implementation roadmap
- `coterie.md` — collaboration rules (all agents)
- `cnotes.md` — collaboration log (newest first)

## Permissions

NEVER allow dangerous or irreversible operations without explicit user confirmation:
- No `rm -rf`, `git push --force`, `DROP TABLE`, or equivalent destructive commands
- No hardcoded secrets — use environment variables with empty-string fallbacks
- No skipping hooks (`--no-verify`) or bypassing safety checks

## Living Documents

After completing work, update:
- `cnotes.md` — log what you did (structured note, see `coterie.md` for schema)
- `todo.md` — mark completed items, add new ones discovered
- `features.md` — if your work changed what the product does

## Context Management

IMPORTANT: When context usage reaches 80% or higher, run the `/meta-compact` skill to preserve session state before continuing. Do not wait until context is full — by then it is too late for a clean save.

## Evolve

If your work changes architecture, tech stack, or key decisions:
- Update `project-context.md` in place, add changelog entry at the top (newest first)
- Update `project-plan.md` in place, add changelog entry at the top (newest first)
- Identify yourself as `CLAUDE` in changelog headers
- See `references/evolve-context-diff.md` and `references/evolve-plan-diff.md` for format
