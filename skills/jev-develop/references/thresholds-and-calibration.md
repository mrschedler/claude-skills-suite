# Thresholds and calibration

Source: `jev-architecture-brief.md` sections 2, 3.2, 3.7, 4.5, 4.7, and `evidence-swot-rubric.md`
sections 3 and 6. Every number in this file is a **starting default**, not a fixed rule. Fit it
per task and per model version once labels exist, and refit whenever the model version changes.

## Calibration is real, but small, and type-specific

The vendor claims Jev's probabilities are "trained for calibrated decisions." Independent
measurement shows the advantage is operational, not statistical: Jev beats 16 of 19 LLMs'
casually-elicited confidence, but Claude Opus 5 (ECE 0.066), Claude Fable 5.1 (0.073), Claude
Sonnet 5 (0.075), and Gemini Flash Lite (0.061) match or beat Jev's own calibration when those
models are explicitly asked for a full 0-1 probability rather than a casual confidence word.
Calibration also differs sharply by primitive on identical inputs: Noul ECE 0.012-0.08 (best),
Choice ECE 0.08-0.11 (worse, overconfident), Score ECE 0.25-0.33 (worst). Treat these as three
different calibration problems, never one.

**Practical rule:** the calibration advantage is for gating (separating likely-right from
likely-wrong so cheap automation is safe), not for reading probabilities as literal correctness
odds. Gate on the top band only; never threshold a Score's numeric output as if it were a
probability.

## First live batch

The first live use of any battery is a 20-email shadow batch, each message labeled by hand via
`decide.log_outcome`, not by any automated rule. Below 50 labels there is no calibration fit at
all: the first batch's 20 labels feed the label count but do not, by themselves, fit anything, so
every band stays `review`/`abstain` until enough further labels accumulate.

## Fitting a threshold with labels

- Budget 50-100 `decide.log_outcome` labels per gated question before trusting a fitted
  threshold. Fewer than 30 labels makes calibration measurably worse than leaving it
  uncorrected (documented up to 4x worse ECE).
- A Platt-scaling refit (intercept only, per `(purpose, provider, model_resolved, question)`) cut ECE by
  62% at 50 held-out labels in one study. The slope tends to be stable (roughly 2.1-2.6 across
  difficulty tiers); the intercept is what moves with base rate (roughly -0.48 to +1.75).
- Refit every 50 new labels and on any model version change. Keep a refit only if it improves
  holdout ECE: do not apply a refit that makes things worse just because it is newer.
- Calibration direction is not uniform across studies: some find Noul underconfident and
  Choice/Score overconfident, others find compression toward 0.5 on a difficulty gradient. Do
  not assume a direction; measure it for your own purpose.

## Thresholds by reversibility (starting defaults)

| Action class | Starting `pmax`/`noul` floor | Basis |
|---|---|---|
| Advisory only | 0.60 | Vendor's own "proceed with caution" band starts here; below it, do not act. |
| Reversible, additive (flag, label, unsent draft) | 0.70 | 0.70 is the brief's starting floor for additive actions; the 0.7-0.9 band is near coin-flip (53%, TDS), so corroboration is required. |
| Reversible, but hides something (auto-file, archive) | 0.90 | A hidden item is the costly miss; one study found p≥0.9 fully precise at 21.5-32.5% coverage. |
| Irreversible (send, delete, spend, commit) | Never on Jev alone | No band should authorize an irreversible action; corroborate with a human or a second signal, always. |

Corroborate for anything beyond advisory: require the primary answer to clear its floor **and**
any corroborating Noul (suspicion, injection, money/legal) to stay below its own floor. Combine
multiple hazard scores with `max`, never an average: a single high-hazard score should never
be diluted by several low ones.

## Drift, pinning, and cache

- **Pin the resolved model id** (for example `typesafe/jev-1.13`), never an alias like
  `jev-latest` or `jev-preview`; aliases move their target without notice.
- Log the echoed `model_resolved` string on every call. OpenRouter has been observed to echo a
  dated concrete id (e.g. `typesafe/jev-1.13-20260917`); a changed id should drop the affected
  battery to shadow mode until it is separately calibrated.
- Run a nightly canary of roughly 20 labeled states through the pinned model. Same-version
  flip rate is normally 0.2-2.1%; a flip rate above 3%, or a mean probability shift above 0.05,
  should force shadow mode and an alert, since it signals silent drift.
- Cache is off for `evaluate` and `route_task` (states rarely repeat); on for `email_triage`
  with a roughly 7-day TTL, since unread mail is re-seen on every sweep.

## Graduation from ad hoc to preset

A purpose graduates once all three hold:

1. **Labels:** at least 50-100 `decide.log_outcome` rows per gated question.
2. **A fitted calibration row:** a Platt refit that improved holdout ECE, stored keyed on
   `(purpose, provider, model_resolved, battery_version, question_id)`.
3. **A repeat caller:** the same purpose is being called by more than one occasion or one
   identity, not a one-off.

On graduation, write a versioned battery file, define its action bands from the labeled data
(not by guessing), and request a grant scoped to that preset. For email triage specifically,
the architecture brief's shadow plan graduates one action at a time, in order: `flag` first,
then `file`, then `draft`, each requiring roughly 50 labeled messages in its band and a
precision floor (98% for `file`, 95% for `flag` and `draft`) before it stops being shadow-only.

## A provider with no fitted row

If a call resolves to a provider or model that has never had a calibration row fitted for this
purpose (a first-time local-model fallback, for example), every band is forced to `escalate`
regardless of its raw score, until the labeled set has been replayed against that provider and
its own row fitted. Interface portability across providers (Jev, a local clone) is solved by a
shared wire contract; calibration portability is not, and must be redone per provider.

## Scoped identities and shadow mode

For a scoped identity (`grokbot-assistant`, `claude-assistant`, the future n8n identity), the
server computes the returned band only from a fitted calibration row for that exact
`(purpose, provider, model_resolved, battery_version, question_id)` key, and ignores any
`thresholds` the caller passed in. `calibrated: false` never yields `act` for any identity,
including `matt-interactive`; an uncalibrated purpose returns `review` (or `abstain`) regardless
of the raw score. A human at the keyboard may still decide on the probabilities themselves, and
`log_outcome` records what was done.

`email_triage` while in shadow mode (before any category has graduated, section 3.8 of the
architecture brief) returns `action: null` for every message: it logs what it would have done,
but recommends nothing. And regardless of graduation state, no preset's `act` band fires on one
signal alone: every `act` band requires either a second corroborating signal (a Noul below its
own floor, per Phase 7's corroboration rule) or an independent code rule to agree before it is
treated as actionable.
