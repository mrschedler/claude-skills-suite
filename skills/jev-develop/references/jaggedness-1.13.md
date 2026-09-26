# Jaggedness: jev-1.13

Two sources: the vendor's own documented weaknesses (`official-docs-reference.md` section 7,
paraphrased from docs.typesafe.ai's model-jaggedness page) and independent measurement
(`evidence-swot-rubric.md` sections 2 and 6). Numbers are attributed inline; unattributed
statements are the vendor's own wording.

## The nine documented weaknesses

1. **Literal reading.** "Answers the question you wrote, not the one you meant." Scoping
   words, negations, and implied conditions are taken at face value. If you find yourself
   explaining what you really meant after a wrong answer, that explanation is the missing half
   of the instruction.
2. **Math and numbers.** Does not count reliably (characters, term occurrences, list items);
   error grows with size. Cannot reliably judge whether two values are near each other. Score
   levels are weak in numerical calibration: do not interpolate an exact magnitude from a
   Score value. Independent measurement: counting accuracy 83-94% depending on list length
   (primeline); simple threshold arithmetic actually beat Claude Haiku and Sonnet in one study
   (YidiDev: 9.3% error vs 18.2% and 13.7%), but full logic fails completely. On random 3-SAT
   formulas, Jev's probability of "satisfiable" stayed at only 0.38 even on the trivially
   unsatisfiable `x AND NOT x` (willkelly, 123,805 calls), nowhere near the near-zero value
   correct reasoning would give it.
3. **Date and time comparison.** Reads dates as text, not as ordered quantities. Ordering,
   distance, and window membership are unreliable, worse with mixed formats or relative
   references ("next Tuesday"). Decompose dates into components (mode, month, day, year,
   weekday) as separate Choices and do the arithmetic in code; a documented cookbook pattern
   auto-accepted 5/6 dates and correctly flagged a nonexistent date at 0.46 confidence.
4. **Indirection.** Double negatives, property-of-a-property, and multi-hop reasoning cost
   accuracy. A full unassisted 10-step reasoning chain scored 29.4% versus 75.0% for the same
   model answering one step at a time (YidiDev). Jev is not a planner or a multi-step reasoner.
5. **Large state with irrelevant detail.** Accuracy falls as unrelated content grows in the
   state; distractors make debugging harder. Independent measurement found Jev robust to sheer
   padding (0% accuracy loss to 125k characters of padding) but fragile to how batched items
   are named: accuracy on 60 batched tickets fell from 1.000 to 0.420 when subjects were
   anonymized to "Ticket 1..60" instead of named by sender and date (willkelly).
6. **Adversarial content.** State is data, and Jev does not treat it as hostile by default.
   Content written to steer the model can move the answer. Independently measured: crude
   "IGNORE THE QUESTION" injections moved only 1/200 decisions, but authority-framed text
   ("the support lead already decided X") moved 147/200 (73.5%), with confidence dropping only
   to 0.68 (willkelly). This is the reason `instructs_reader` and `is_suspicious` style Nouls
   exist and must force escalation rather than merely lower a score.
7. **Contradictory instructions and criteria.** When instructions and criteria disagree, the
   model may follow either one unpredictably; one study found it followed the literal
   instruction over the criteria 20 of 20 times (primeline). Keep them aligned.
8. **No structural invariants.** See `references/primitives.md`: the same fact does not
   answer consistently across Noul and Choice framings, and Choice probabilities have been
   observed to sum to more than 1.0 across repeats of "the same" question.
9. **Generation.** Not trained to generate text. Chaining Choices to emit prose will not work
   well and will be slow. Use an LLM agent for anything that needs written output.

## Additional jaggedness from independent evidence (not in vendor docs)

- **Out-of-scope inputs answered at 0.99.** Forcing every input into an option at high
  confidence is systematic: 30/30 out-of-category messages scored ≥0.99 in one study
  (PriorBench); 0/30 were flagged in another (beri). Always include a described `other` option
  and still gate on confidence: a confident `other` is a real answer, but Jev given no `other`
  option will manufacture a confident wrong one.
- **Mid-band collapse.** Answers reported at 0.7-0.9 confidence were right only 53% of the time
  in one study (TDS); a 0.6-0.8 confidence band showed a 0.27 accuracy gap in another (Rusanau).
  Below roughly 0.8, treat the answer as close to a coin flip unless it has been separately
  calibrated for this exact purpose.
- **Latent constructs it cannot see.** On empathy in peer-support dialogue, 78% of items
  received ≥0.9 confidence while accuracy sat at 0.383 against a 0.371 base rate: confidence
  measures how peaked the distribution is, not whether the model can perceive the construct at
  all (NYU, arXiv 2609.24574). Jev trailed the best available LLM on 14 of 15 social-science
  annotation tasks by a median 11.6 F1 in the same study.
- **Joint multi-question state does not compound per-question accuracy.** Four simultaneous
  questions over one shared state were all correct together only 61.4% of the time even though
  each question individually scored within 1-2 points of a strong open baseline (LargitData).
  Do not assume a battery's accuracy is the product, or even close to the minimum, of its
  individual questions' accuracy.
- **Non-English costs accuracy and doubles calibration error.** Spanish state measured -3.0 to
  -6.4 points versus English on the same items, with error roughly doubling on NLI tasks and
  input tokens running 17-38% higher (jev-acento); Russian measured roughly -11 points and
  about 3x the tokens. Keep instructions in English regardless of state language, and treat any
  non-English deployment as unmeasured until you have your own labels.

## Summary anti-pattern

Every one of the above traces back to one of: asking Jev to compute something code can compute
exactly, hiding several judgments inside one question, a System Two task with layered
indirection, or handing over more state than the current questions need.
