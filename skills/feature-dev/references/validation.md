# Validation Protocol

## When to Validate

| Trigger | Why |
|---------|-----|
| Phase transition (all X.Y done, starting X+1) | Catch drift before it compounds |
| Every 5 stories | Periodic consistency check |
| After context reset (new session, new agent) | Verify state is clean |

## What to Check

Query artifact DB for completion records:

```bash
source artifacts/db.sh
db_read_all "dev" "story-complete"
```

Cross-check against prd.json:
1. Every `passes: true` story has a DB completion record
2. No DB records exist for stories still `passes: false`
3. Stories completed in dependency order (no story complete before its dependsOn)
4. PROGRESS.md current story matches next incomplete story in prd.json

## Phase Transitions

When all stories in a phase are complete:
1. Query DB for all phase completions — review what was built
2. Check lessons learned in Qdrant: `memory_call > search` with project + phase tags
3. Confirm with user before starting next phase
4. Check if remaining stories still make sense given what was learned

## If Drift Is Detected

- PROGRESS.md says story 2.3 but prd.json shows 2.1 incomplete → fix prd.json or PROGRESS.md
- DB has completion record but prd.json shows `passes: false` → update prd.json
- Missing DB record for completed story → backfill from git log

Fix drift before continuing. Do not build on top of inconsistent state.
