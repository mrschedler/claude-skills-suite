# Fixtures

This directory is currently empty on purpose. It describes what will live here, not what does.

No labeled data exists yet for this skill, and none has been invented for it. Fixtures belong
here only once they come from real outcomes: `decide.log_outcome` rows the gateway has
recorded, or Matt's own reviewed corrections during a shadow period. Do not seed this directory
with synthetic or guessed labels: a wrongly-labeled fixture is worse than no fixture, because
it will silently mis-calibrate a threshold or hide a real regression in the nightly canary.

## What a golden fixture set will hold, once it exists

Per `jev-architecture-brief.md` sections 3.7 and 6 (roadmap Phase 0: "50-message golden set";
the nightly canary described in `references/thresholds-and-calibration.md` replays roughly 20
labeled states):

- **One file per battery** (for example `email_triage.v1.fixtures.jsonl`), each line a record
  of `{state, questions_version, expected: {<question_id>: <true label>}, outcome_source,
  labeled_at}`.
- **`outcome_source`** distinguishes how the label was obtained: `matt_action` (Matt's own
  behavior was the implicit label, moved mail, replied, ignored), `matt_review` (an explicit
  adjudication during a shadow-mode disagreement review), or `agent` (a downstream agent's
  action confirmed or corrected the label). Seed labels from an inactive classifier (for
  example old Haiku-based email classifications) are not ground truth and must be marked as
  such if ever included, per the architecture brief's caution about the 109 Haiku rows in
  `email_classifications`.
- **A canary subset**, a fixed roughly-20-item slice replayed nightly against the pinned model
  to catch silent version drift (flip rate above 3%, or a mean probability shift above 0.05,
  forces the affected battery to shadow mode).
- **A held-out calibration slice**, at least 50 labels per gated question, kept separate from
  whatever slice was used to fit the Platt intercept, so calibration quality can be checked
  honestly rather than measured on the same data it was fit to.

## How fixtures get here

Fixtures are populated by the gateway's `decide` module once it is logging outcomes, or by a
shadow-mode review process (the architecture brief's two-week email shadow plan, section 3.8).
This skill does not generate them. If you are building a new preset and need fixtures to test
it, either wait for real labels to accumulate under the new `purpose`, or explicitly mark any
placeholder data you write as synthetic and non-authoritative, and do not use it to fit a
threshold that will govern a real action.
