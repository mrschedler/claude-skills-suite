# Primitives

Source: `official-docs-reference.md` section 2 (vendor documentation) and
`jev-architecture-brief.md` section 2 (the resolution of confidence-vs-pmax). Every question
you write is one of these three types. Questions in one call are evaluated independently and
in parallel: one question's answer is not hidden context for another, and adding or removing a
question does not change the others' results.

## Choice

One of a fixed, known set of mutually exclusive options.

- `criteria`: map of option key to description. String, object, array, or `null`. Up to 255
  options.
- Returns: `choice` (the argmax key), `probabilities` (sum to 1 across all options),
  `confidence` (0-1, from the shape of the distribution).
- Always include a described `other` or `none_of_the_above` option unless the list is
  genuinely exhaustive. Pass the full option list, never a shortlist.
- When options blur together, use structured criteria objects (`what`, `not_for`, `examples`)
  instead of a bare sentence.
- For a deep taxonomy, ask one Choice per level rather than one Choice over every leaf, and let
  code descend the tree (a "beam search" pattern that matched 4/4 leaves on a 2,600+ node
  taxonomy versus 2/4 for a single flat Choice).
- Use for one-of-N with no natural order (team, category, language). An ordered spectrum is a
  Score. Yes/no is a Noul, not a two-option Choice: see "no structural invariants" below.

## Score

Degree along one described dimension, for ordering only.

- `criteria`: an ordered array of 2-10 level descriptions, low to high. The docs recommend 3-10
  distinct levels.
- Returns: `score` (the probability-weighted level, e.g. `{0: 0.0, 1: 0.57, 2: 0.43}` gives
  1.43), `legend` (index to description), `probabilities`, `confidence` (1.0 when one level
  holds all the mass).
- Describe each level as a concrete situation ("someone is waiting on Matt and will follow up
  within a day or two"), never as a degree word ("moderately urgent" is bad: it gives the
  model nothing to anchor on).
- One dimension per Score. If a judgment has several independent dimensions, ask several Scores
  and combine them with weights in code (the vendor's composite-scoring cookbook pattern),
  never fold them into one Score.
- Do not use a Score's numeric value to interpolate an exact magnitude, and do not port a
  threshold fit on a Score to any other primitive. Score type is measurably the worst
  calibrated of the three (ECE 0.25-0.33 versus 0.02-0.09 for Noul and Choice in-distribution;
  `references/thresholds-and-calibration.md`).

## Noul

A single yes/no, expressed as a probability.

- `instructions`: the yes/no question or statement. `criteria` optional:
  `{"true": ..., "false": ...}` to sharpen the boundary.
- Returns: `noul` in [0, 1]. **No confidence field**: a two-outcome distribution is fully
  described by the one number.
- One condition per Noul. A compound condition ("is this urgent and from a known sender")
  should be two Nouls, combined in code.
- Phrase so that high means yes, and make the boundary the criteria describe unambiguous.
- Threshold in code by the cost of the two error types: 0.5 when errors are symmetric, raise
  the bar when a false positive is expensive (auto-filing a real order), lower it when a miss
  is expensive (letting a suspicious message through).

## Confidence, and why to gate on `pmax` instead

The documented formula for a three-option Choice is `(3 * pmax - 1) / 2`; this generalizes to
`(N * pmax - 1) / (N - 1)` for N options, confirmed to within 0.006 mean absolute error by
independent replication. That means the `confidence` field carries no information beyond the
top probability: it is a fixed rescaling of `pmax` that changes shape as the option count
changes. Gate on `pmax` directly so a threshold stays comparable when you add or remove
options from a Choice. Noul has no confidence field at all; gate on distance from 0.5, or
simply on the `noul` value itself when high-means-yes.

## Advanced structure

Instructions, Choice option values, Score level entries, and Noul true/false criteria all
accept JSON structure, not just strings. Two uses: label a multi-part question with keys
instead of prose, and hand over existing structured data (a schema, a database row) rather
than serializing it into a sentence. A single field-spec object can be shared by key across
several questions in the same call.

## No structural invariants between primitives

The same underlying fact does not answer consistently across primitives. One documented case:
"Is the customer asking for a refund?" as a Noul returned 0.22, while the equivalent Choice
(`refund` vs `something other than a refund`) returned 0.01 / 0.99, and the two Choice
probabilities summed to 1.19, not 1.0, across repeats. Never assume `1 - noul` equals a
different question's answer, and never carry a threshold fitted on one primitive over to
another framing of "the same" question.
