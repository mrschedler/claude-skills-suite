# Session janitor — detail for /rehydrate Step 8

Authority: behavioral-reminders SESSION JANITOR (2026-07-09). This file is overflow
from SKILL.md; the skill remains the entry point.

## When it runs

Default **on** after MCP rehydrate. Skip when:

- `--quick`
- `--no-mcp`
- `--no-hygiene`

## Quota

- ≤5 write actions total (`supersede` / `update` / `confirm` / tag via `update`)
- Or stop after ~60s
- Never unbounded-clean
- Never `memory_call > delete`

## Sources of work (priority)

1. Rehydrate `hygiene` block — top findings only (cap ~5; do not exhaust never_retrieved dumps)
2. Semantic audit of rehydrate memories vs GROUNDING / PROGRESS / pipeline / git / file tree
3. Cheap structural checks:
   - Governing memories cited in GROUNDING / CLAUDE return from Qdrant? (hint, not UUID)
   - Active phase: pipeline vs `artifacts/plans/current.md`?
   - PROGRESS.md state vs latest notebook entry?

## Auto-heal without asking

| Case | Action |
|------|--------|
| Broken supersede / superseded_visible | `memory_call > supersede` |
| State memory clearly stale vs PROGRESS / pipeline / git | `update` or `supersede` → current truth |
| Import / low-density noise (openai-import, claude-import, empty shells) | `update` tags: add `gunk,exclude-from-default` |
| Still-accurate governing memory you verified | `confirm` |
| Additive cross-links / case-normalized graph merges | `graph_call` as needed |

## Always ask / stop

- patent, protected, evolution-tagged subjects
- Two *current* sources disagree and both look intentional
- Large 0.85 cluster consolidate → defer to `/memory-sleep` or propose
- Any hard delete

## Remove means

Out of default steering (supersede + tag), not erase.

## Boundary vs /memory-sleep

| | Session janitor | /memory-sleep |
|--|-----------------|---------------|
| When | Every cold start /rehydrate | Manual supervised pass |
| Quota | ≤5 | ≤50 after dry-run approve |
| Delete | Never | Never (supersede-only) |
| Dry-run | No | Default |

## Over quota

Apply highest-confidence auto-heals first; list deferred IDs in the rehydrate report.
Optionally spawn hygiene subagent with the **same** quota+tiers when findings > ~10
(see behavioral-reminders HYGIENE AGENT).

## Report line

```
**Hygiene:** N fixed (brief what), M deferred, K need Matt
```

Or `skipped (--no-hygiene|--quick|--no-mcp)` or `none`.
