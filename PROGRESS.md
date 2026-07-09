# PROGRESS.md — Claude Skills Suite

> Current state as of 2026-07-09. Static context in GROUNDING.md; journey in ENGINEERING-NOTEBOOK.md; detailed plans in `artifacts/plans/` when present.

## Where We Are

Long-arc foundation project (skills + hooks + behavioral protocol). Cold-start
**session janitor** is live: agents auto-heal memory surface (quota 5,
supersede/tag only) via behavioral-reminders + `/rehydrate` Step 8 +
session-prewarm nudge. `/memory-sleep` is the bulk supervised path (dry-run
default). Grok can use the MCP gateway via `~/.grok/config.toml` (native HTTP).

## Blockers

| Item | Blocks | Status |
|------|--------|--------|
| Gateway default-exclude for `gunk`/import sources | Tags alone don't demote noise in search | Open — mcp-gateway work |
| `/hygiene-check` dual-mode (`--fix`) | On-demand janitor beyond rehydrate | Scaffold only; plan in `artifacts/plans/hygiene-check-skill.md` |

## Recent Changes

| Date | Change |
|------|--------|
| 2026-07-09 | Session janitor shipped (`80ff47c`, `04cb7d6`); notebook Entry 19; Qdrant d7a8057c |
| 2026-07-09 | `/memory-sleep` skill + interagent inbox nudge (`01f97e7`); notebook Entry 18 |
| 2026-07-09 | Doc placement correction: janitor **not** a GROUNDING Key Decision — status here + Entry 19 |
| 2026-07-08 | As-you-go memory hygiene + retrieval-feedback in behavioral-reminders (`21a0dc4`) |
| 2026-07-07 | PROGRESS.md restored as seventh load-bearing artifact (Entry 17) |

## Doc roles (do not blur)

| File | Role | Cadence |
|------|------|---------|
| GROUNDING.md | WHY, constraints, durable anti-patterns | Rarely |
| PROGRESS.md | NOW — this file | Per significant session |
| ENGINEERING-NOTEBOOK.md | JOURNEY — dated decisions/implementations | Per significant session |
| `project-context.md` | Deep technical architecture (if needed) | When architecture shifts |
| Skills (`/project-organize`, `/project-context`) | Encode the structure above | When suite conventions change |

## Next

1. Gateway: default-exclude `gunk` / import sources on search  
2. Finish `/hygiene-check` with `--fix` mode (janitor tiers)  
3. Optional: first `/memory-sleep triage` dry-run batch (memory-system project)
