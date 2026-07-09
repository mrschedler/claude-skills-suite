---
name: memory-sleep
description: "Supervised Qdrant sleep pass (light/deep/dream/triage): worker verdicts, judge-gated destructive actions, dry-run default. Invoke with /memory-sleep."
argument-hint: [light | deep | dream | triage] [--execute <report-label>]
---

# Memory Sleep

Sleep/dream consolidation for the Qdrant memory system: episodic-to-semantic
transfer, pruning, and keystone synthesis, run as a MANUAL supervised pass.
Exists because the store accumulates low-fact-density episodics that semantic
search must wade through; cleanup need scales with usage, not calendar.
Principle: **workers propose, the judge disposes.**

Design authority: `C:\dev\memory-system\artifacts\plans\sleep-cycle-architecture-2026-07-08.md`
— its **§Interview decisions** section governs wherever it conflicts with the
earlier cadence/vehicle sections or with the Sprint 15 pipeline description.

## Pass Types

| Pass | Stages | Scope | Judge tier |
|---|---|---|---|
| `light` | 0–3 | Last-48h memories + small rolling legacy window; prune obvious chaff | worker tier |
| `deep` | 0–3 | Full manifest from gateway triage tools | frontier tier |
| `dream` | 4 only | 2–3 themes: keystone synthesis, graph edges, retrieval-feedback rollup | frontier tier |
| `triage` | 1–3 | Pre-built legacy batches (see Inputs); claude-import era first | frontier tier |

Model tiers describe roles, not hardcoded models: **worker tier** = a mid-tier
model (design default: Opus-class), **judge tier** = the most capable model
available to the executing agent (design default: Fable-class). An agent maps
tiers to whatever equivalents it has.

## Inputs

- Pass type argument (required — ask if missing; never guess a destructive scope)
- MCP gateway memory tools (`memory_call`: search/get/consolidation_candidates/
  dedup/stats read-side; store/update/confirm/supersede/consolidate write-side)
- memory-system artifact DB: `cd /c/dev/memory-system && source artifacts/db.sh`
  — audit trail home, and (triage) the Stage-0 manifest rows
  (`db_read 'sleep-cycle' 'stage0-manifest' 'batch-001'` … `batch-101`,
  built 2026-07-08; see `triage-manifest-2026-07-08.md` beside the design doc)
- Neo4j via `graph_call` (dream pass: entity neighborhoods and edges)

## Outputs

- **Dry-run (default):** a repercussions-first report (see
  `references/report-contract.md`) + one artifact-DB record
  (`db_add 'sleep-cycle' 'dryrun-report' '<pass>-<date>' …`). NO memory writes.
- **Execute (`--execute <report-label>`):** gateway writes capped at 50 actions,
  per-action audit rows (`skill=sleep-cycle, phase=stage3-execution`), and one
  sleep-report memory (category `memory-system`, tag `sleep-cycle`).
- Never, in any mode: `memory_call delete`. Supersede-only; undo =
  `unconsolidate` / supersede-chain rescue.

## Instructions

### Phase 0 — Preflight

1. Resolve pass type and mode. `--execute` is valid ONLY with a `<report-label>`
   pointing at an existing `dryrun-report` record that Matt has approved in
   conversation. No approved dry-run record → refuse and run a dry-run instead.
2. Matt approves EVERY destructive pass for now. Autonomy graduation is his
   explicit call later — never earned by run count. Do not propose it.
3. Before `--execute` of `deep`/`triage`: verify a Qdrant snapshot exists that
   postdates the last memory-writing day (backup infra on deepthought). Cannot
   verify → stay report-only and say so.
4. Gateway unreachable → stop; this skill is inoperable without it (exception
   to the usual MCP-optional rule — the memory store IS the work surface).

### Phase 1 — Stage 0: Manifest (mechanical, no LLM)

Build the batch manifest with gateway tools only — no model judgment here:

- `light`: `memory_call list/search` for last-48h memories + up to 2 legacy
  batches from the triage manifest if any remain.
- `deep`: union of `consolidation_candidates` (≥0.70), `dedup`,
  retrieval_count=0 & age>30d, decay-expired episodics, superseded-orphans.
- `triage`: read the next unprocessed manifest batches from the artifact DB.
  The manifest is a point-in-time snapshot — re-verify members are not already
  superseded/consolidated before batching.

Then, for every pass: **exclude protected/patent-tagged memories HERE**,
upstream of any LLM (the gateway tools default to `exclude_tags: protected`;
additionally drop anything tagged `patent*`). Chunk into batches of ~25, one
cluster/category/era per batch. Record the manifest (batch labels + member IDs)
in the artifact DB before Stage 1 — the report and any later `--execute` must
reference this exact manifest.

### Phase 2 — Stage 1: Worker verdicts (parallel, read-only)

One worker per batch, prompt template in `references/worker-prompt.md`.
Workers return per-memory verdicts — KEEP / UPDATE / PROMOTE / CONSOLIDATE /
ARCHIVE — and perform NO writes. Non-negotiable worker rule: verify claims
against cheap ground truth (hybrid keyword search via the `keyword` param for
names/IDs, git log, PROGRESS.md files, project pipeline) — memory-vs-memory
comparison alone is insufficient (proven 2026-07-08).

Orchestrate with the Claude Code Workflow tool where available —
`pipeline(batches, verdicts, judge)` skeleton in
`references/workflow-skeleton.md` — so judging starts per-batch without a
barrier. Agents without Workflow: run batches sequentially with subagents or
inline; the stage contract is identical.

### Phase 3 — Stage 2: Judge gate (destructive verdicts only)

KEEP/UPDATE/PROMOTE pass through. Every ARCHIVE and CONSOLIDATE verdict gets
adversarial review on the pass's judge tier — prompt in
`references/judge-prompt.md`. The judge enforces the **TOMBSTONE RULE**: no
memory recording the existence or closure of anything (account, vendor,
subscription, product, relationship) may be archived unless its one-line
historical fact already lives in a keystone. Superseded memories are
search-excluded — without the tombstone, "did I ever have X?" becomes
unanswerable. Test case: "did I ever have a Render account?" must stay one
search away forever. Judge rejection → verdict downgraded to KEEP, reason kept.

### Phase 4 — Report (dry-run terminus)

Write the report per `references/report-contract.md` — it STARTS with ~20-word
bullets, each stating a granularity loss/repercussion of approving; details
(memory IDs, batch manifests, per-memory verdicts) go below as reference only.
Be ready to expand any bullet on request. Store the report record
(`dryrun-report`) in the artifact DB with its manifest reference. **Dry-run
ends here.** Do not ask "shall I execute?" — Matt directs the execute run.

### Phase 5 — Stage 3: Execution (`--execute` only)

Single executor, ≤50 actions per cycle (excess carries to the next pass —
report what was deferred). Apply approved verdicts via gateway, supersede-only:

| Verdict | Gateway action |
|---|---|
| KEEP (verified accurate) | `confirm {memory_id}` — refreshes ranking freshness |
| UPDATE | `update {memory_id, content}` (old version auto-superseded) |
| PROMOTE | `store` the semantic fact (`source: consolidation`, confidence), then `supersede` the episodic source → new ID, reason `promoted-by-sleep-<date>` |
| CONSOLIDATE | `consolidate {content, source_ids, mark_sources: 'true'}`, then `supersede` each member → keystone ID, reason `consolidated` |
| ARCHIVE | `supersede` → covering keystone (or this pass's sleep-report memory), reason `sleep-archive-<date>`. Never delete |

Log every action as an artifact-DB row BEFORE issuing it (action, target IDs,
verdict provenance). Verify each write landed (`get` the target). Abort the
remainder of the cycle on the first failed/contradictory write — partial
execution is safe because everything is supersede-only.

### Phase 6 — Closeout

Store one sleep-report memory (category `memory-system`, tags
`sleep-cycle,state`): pass type, scope, verdict counts, actions applied/
deferred, report label. Note follow-ups (e.g. remaining triage batches).

### Dream pass (Stage 4) — separate path

No batches, no verdicts. Pick 2–3 themes (from consolidation clusters, recent
heavy-use projects, or Matt's ask). Per theme: pull related memories + the
Neo4j neighborhood → draft ONE keystone narrative ("what we know about X as of
<date>") — plain dated text with tags, provider-agnostic, no special structure.
Entity keystones are graph-derived, not hand-curated: any Neo4j entity linked
to 2+ projects qualifies (graph edges answer WHICH, the keystone answers WHY).
Also: aggregate recent `mcp-retrieval-feedback` memories into the report, and
propose (never apply) GROUNDING/GOTCHAS deltas to owning projects. Dry-run
default applies: keystone text goes in the report; `--execute` stores keystones
and creates graph edges, and any superseding of replaced stock still goes
through the judge gate first.

## Safety Rails (non-negotiable)

1. Dry-run is the default everywhere; execution requires `--execute` + an
   approved dry-run report for the same manifest.
2. Protected/patent tags excluded at Stage 0 — they never reach an LLM verdict.
3. ≤50 write actions per cycle. 4. Supersede-only; nothing deleted.
5. Full artifact-DB audit trail, written before each action.
6. Qdrant snapshot verified before deep/triage execution.

## References (on-demand)

- `references/worker-prompt.md` — Stage 1 verdict prompt template + JSON schema
- `references/judge-prompt.md` — Stage 2 adversarial gate + tombstone rule
- `references/report-contract.md` — repercussions-first report format + example
- `references/workflow-skeleton.md` — Workflow-tool orchestration script + fallback

## Examples

```
User: /memory-sleep triage
→ Read next manifest batch(es) from memory-system artifact DB, re-verify
  members, run workers → judge → repercussions-first report. No writes.
```

```
User: /memory-sleep triage --execute triage-2026-07-12
→ Verify that dryrun-report record exists and Matt approved it, verify
  snapshot, apply verdicts (≤50 actions), audit rows, sleep-report memory.
```

```
User: /memory-sleep dream
→ Pick 2-3 themes, draft keystones + graph edges + retrieval-feedback rollup
  into a report. Store nothing until an approved --execute run.
```

```
User: /memory-sleep
→ Ask which pass type. Suggest light if recent usage was heavy, dream if a
  week's worth of retrieval-feedback has accumulated.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
