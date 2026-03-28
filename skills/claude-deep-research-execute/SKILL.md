---
name: claude-deep-research-execute
description: "Internal Opus subagent for Claude-only deep research. Runs ~15 workers with steelman/steelman debate. Never invoke directly — dispatched by /claude-deep-research."
disable-model-invocation: true
---

# claude-deep-research-execute

Dispatched by `/claude-deep-research`. Read `references/protocol-detail.md` for
full phase instructions.

## Rules

1. You own ALL DB writes. Subagents return content in their response. You write.
2. Update `artifacts/research/{NNN}D/progress.md` after each phase.
3. Check DB for existing phase outputs before executing (checkpoint/resume).
4. Every subagent prompt must end with: "Include Source Tally (queries executed, results scanned, sources cited) at the end."

## DB Setup

Every Bash call that touches the DB must start with:
```bash
export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
export PROJECT_DB="[absolute project root]/artifacts/project.db"
source artifacts/db.sh
```

## Adaptive Source Target

`sub_questions × assigned_connectors × 3 × 20`. Report actual vs expected.

## Phases

1. **Decomposition** → dispatch table + source target
2. **Fan-out** → 3 tracks parallel (A: Opus reasoning, B: Sonnet connectors, C: Sonnet WebSearch) → batch-write all findings to DB → aggregate source tally
3. **Coverage expansion** → 2 reviewers → addendum if: >2 thin areas OR below source target OR emergent topics. Skip if coverage sufficient. Max 1 cycle.
4. **Steelman debate** → Advocate (FOR) + Challenger (AGAINST with fresh WebSearch) → you judge
5. **Convergence scoring** → VERIFIED / HIGH / CONTESTED / UNCERTAIN / DEBUNKED per claim
6. **Summary** → `artifacts/research/summary/{NNN}D-{topic-slug}.md` (300-500 lines)
7. **Report** → store to Qdrant, return summary path + tally + claim counts + contested findings

## Convergence Matrix

| Outcome | Confidence |
|---|---|
| Both agree | VERIFIED |
| Advocate strong, Challenger concedes | HIGH |
| Both present strong evidence | CONTESTED |
| Neither has strong evidence | UNCERTAIN |
| Challenger disproves with evidence | DEBUNKED |

## Error Handling

- MCP connector unavailable → WebSearch fallback
- Subagent failure → mark affected claims UNCERTAIN
- Coverage reviewers fail → proceed with available reviews
- Addendum threshold not met → skip, note in methodology
