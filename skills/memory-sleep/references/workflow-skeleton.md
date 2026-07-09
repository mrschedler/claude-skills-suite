# Workflow Orchestration Skeleton (Stages 1–2)

For agents with the Claude Code Workflow tool. `pipeline()` lets each batch
flow to the judge as soon as its verdicts land — no barrier. Stage 0 (manifest)
and Stage 3 (execution) stay OUTSIDE the workflow: Stage 0 is mechanical
gateway calls, Stage 3 is a single serial executor that must stop on first
failure — neither benefits from fan-out.

Pass real values via `args`; scripts cannot call Date.now(), so pass the date in.

```javascript
export const meta = {
  name: 'memory-sleep-verdicts',
  description: 'Sleep-cycle Stage 1 worker verdicts + Stage 2 judge gate',
  phases: [
    { title: 'Verdicts', detail: 'one read-only worker per batch of ~25' },
    { title: 'Judge', detail: 'adversarial gate on ARCHIVE/CONSOLIDATE only' },
  ],
}

// args = { batches: [{label, category, era, members: [{id, content, ...}]}],
//          workerPrompt, judgePrompt,   // full templates, placeholders filled per-batch by replace()
//          workerModel, judgeModel,     // tier mapping decided by the invoking agent
//          date }

const VERDICTS = { /* JSON Schema matching references/worker-prompt.md output */ }
const RULINGS  = { /* JSON Schema matching references/judge-prompt.md output */ }

const results = await pipeline(
  args.batches,
  b => agent(
    args.workerPrompt
      .replace('{{BATCH_LABEL}}', b.label)
      .replace('{{COUNT}}', String(b.members.length))
      .replace('{{CATEGORY}}', b.category)
      .replace('{{ERA}}', b.era)
      .replace('{{BATCH_JSON}}', JSON.stringify(b.members)),
    { label: `verdicts:${b.label}`, phase: 'Verdicts',
      schema: VERDICTS, model: args.workerModel }
  ),
  (res, b) => {
    if (!res) return null
    const destructive = res.verdicts.filter(v =>
      v.verdict === 'ARCHIVE' || v.verdict === 'CONSOLIDATE')
    if (destructive.length === 0) return { batch: b.label, verdicts: res.verdicts, rulings: [] }
    const enriched = destructive.map(v =>
      ({ ...v, content: b.members.find(m => m.id === v.id)?.content }))
    return agent(
      args.judgePrompt.replace('{{VERDICTS_JSON}}', JSON.stringify(enriched)),
      { label: `judge:${b.label}`, phase: 'Judge',
        schema: RULINGS, model: args.judgeModel }
    ).then(j => ({ batch: b.label, verdicts: res.verdicts, rulings: j ? j.rulings : null }))
  }
)

// rulings === null → judge died for that batch: treat ALL its destructive
// verdicts as REJECTED (fail closed). Same if a batch result is null.
return { batches: results.filter(Boolean), date: args.date }
```

After the workflow returns, the invoking agent (not a subagent):
1. Applies rulings: REJECT → verdict becomes KEEP; APPROVE_WITH_CONDITION →
   merge the condition into the keystone text before it enters the report.
2. Writes the repercussions-first report (`references/report-contract.md`).
3. Dry-run ends. Execution is Phase 5 in SKILL.md — serial, ≤50 actions,
   audit row before each write.

## Fallback without the Workflow tool

Same contract, sequential: for each batch, run the worker prompt (subagent or
inline), then the judge prompt on its destructive verdicts. Fail closed
identically. Slower, not different.
