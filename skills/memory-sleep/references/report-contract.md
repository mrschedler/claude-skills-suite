# Report Contract — Repercussions First

This format is load-bearing. Matt is big-picture and will skim; the report
must let him approve or veto on the first screen. Consolidation intentionally
trades fine texture for coherence — the report's job is to disclose exactly
which texture is being traded, per decision, up front.

## Rules

1. The report **starts** with a bullet summary. Each bullet is ~20 words and
   states a **granularity loss / repercussion of approving** — the shape is
   "lose: <what texture disappears>; keep: <what survives and where>".
2. **No laundry list of facts/figures up front.** Counts, memory IDs, batch
   manifests, per-memory verdicts, judge rulings — all of it goes BELOW the
   bullets, as reference material only.
3. The presenting agent must be ready to **expand any bullet** into a detailed
   summary on request. That is the drill-down path; it never preloads into the
   report body.
4. Every report names its manifest (batch labels) and gets an artifact-DB
   record: `db_add 'sleep-cycle' 'dryrun-report' '<pass>-<date>' "<report>"`.
   The `--execute` run references this exact label.
5. Zero destructive verdicts survived the judge → say so in one line; don't
   pad. The bullets section can be empty; that is a valid, good report.

## Template

```markdown
# Sleep report — <pass> — <date> (DRY RUN | EXECUTED)

## What you'd be approving (one bullet per repercussion, ~20 words each)

- lose: per-session play-by-play of DD v2 Phase 8 debugging (9 memories);
  keep: outcome + root cause in keystone.
- lose: individual Feb-era homelab config attempts; keep: final working
  config + why earlier ones failed.
- <one bullet per consolidation cluster / archive group — group by theme,
  not by memory>

## Not lost (context, one or two lines)

Play-by-play survives in engineering notebooks and transcripts; keystones are
searchable memory's view, not the only record.

## Reference (do not read unless drilling down)

- Manifest: <batch labels + member counts>
- Verdict counts: KEEP n (m confirmed) / UPDATE n / PROMOTE n / CONSOLIDATE n / ARCHIVE n
- Judge: approved n, conditional n, rejected n (rejection reasons listed)
- Per-memory verdicts: <table or artifact-DB pointer>
- Proposed keystones: <full text of each, verbatim>
- Deferred (action cap): <what carries to next cycle>
```

## Anti-patterns

- Opening with "Processed 25 memories across 3 clusters with 92% ..." — that
  is a laundry list; it tells Matt nothing about what he is giving up.
- Bullets that state actions ("consolidate 9 memories") instead of
  repercussions ("lose: the day-by-day debugging trail...").
- Burying a tombstone-rule conditional approval in the reference section —
  conditions Matt must sign off on are bullets, not footnotes.
