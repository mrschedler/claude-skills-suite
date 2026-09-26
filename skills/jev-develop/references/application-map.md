# Application map

Source: `jev-architecture-brief.md` section 6.2 (shapes) and
`grok-application-types-2026-09-26.md` (the 27-better / 17-not-better catalog). Use this when
judging whether a genuinely new task is Jev-shaped, after the six-question fit test in
`SKILL.md`. Every number below is one source's measurement, not a guarantee for your task.

## Shapes that fit, and where this workspace uses them

| Shape | Example use here |
|---|---|
| Classification | Email triage; Work Dispatch categoricals; Obsidian filing among same-label folders only |
| Detection | Mail injection signals; contradiction checks; log triage |
| Scoring | Review severity; anything where code compares the raw values afterward (e.g. calendar times) |
| Routing | `route_task`; interagent claim routing; a task-executor pick |
| Filter and rerank | Memory relevance filtering ahead of a frontier read |
| Verification / done-gates | Tool-call gating; pre-commit and project-rule checks; a "did the agent actually finish" check |
| Extraction by choice | Regex finds candidates, Jev picks which one answers the question. Never let Jev invent a value it wasn't offered |
| Action selection | A closed set of next steps (browser click target, a bounded command set) |

Explicitly not recommended: context compaction (an independent test found built-in
summarization recalled 12/12 versus Jev's 11/12 keep/delete calls).

## Where independent or reported sources said Jev was better (attributed, not vendor claims unless marked)

| Type | Result (source) |
|---|---|
| Security issue classification | 5x cheaper, reported higher accuracy (@grichadev, X) |
| Email forward/send triage (alongside a model that still sends) | About a quarter of the prior cost (@saadiq, X) |
| Chat next-action (not "which specialist") | 94.0% vs 91.2% on replayed live chats; 986/986 correct at ≥0.97 confidence (Entagl) |
| Batched ticket judgments | 0.739 s vs 74.42 s for a frontier reasoning model (TrueStandard) |
| Email spam | 98.7% vs 97.7-98.0% (Aman Kumar) |
| Sentiment | 95.7% vs 92.7-93.0% (Aman Kumar) |
| News topic | 91.3% vs 88.3-89.7% (Aman Kumar) |
| Product catalog classification | 736/1,000 vs 739/1,000, 0.9 s vs 82 s (Colin Zima) |
| Local event-listing validation | 48/50 vs 42-43/50 (Near Here) |
| Claim-vs-source grounding | 96.3% vs 93.5-94.4% (TrueStandard) |
| Phishing, after decomposing the question | 95.0% vs a single-question 62.6% (Rajesh Beri) |
| Agent-trace pass/fail judging | 500/500 matched a human, vs Claude Sonnet 4.6 80.0% and GPT-5.6 Terra 99.8%, on five fixed weather-agent traces repeated (LangChain) |
| Hallucination detection, after tuning the cutoff | 87%, matching Claude Opus 5, at roughly 1/300 the cost (Arize) |
| Tool-call risk classification | 91.7%, tying Claude Sonnet 5, ~40x cheaper (themsquared) |
| Pre-execution hazard-per-question firewall | 0% false blocks on benign cases vs 39.2% for one holistic question (Ansh Choudhary) |
| Project-rule check on agent writes | 6 rule breaks in 150 runs without the guard, 0 with it (pi-warden) |
| Browser next-action | Median task time 9.45 s to 7.09 s (browser-use; only 3 trial pairs, authors flag it as weak evidence) |
| WebMCP tool selection | 49/49 vs 25/49 without dedicated tool schemas (Idan Levin) |
| Coding-agent model/effort pick (backtest, not live) | $349 vs $871 over a 7-day replay (0xNatoshi) |
| Vulnerability first pass over code | ~0.25 s vs ~10 s per call (depthfirst) |
| Legal passage rerank ahead of BM25 | Top-1 accuracy 5% to 18% (TypeSafe's own cookbook; vendor claim) |
| Regulatory checklist, many questions in one call | 12.2x cheaper in one call vs one call per question (TypeSafe; vendor claim) |
| Legal-discovery page routing | 5-6x faster than a frontier model on the classification step (LangChain) |
| Multi-phase estimating steps | 30 s / $0.40 to ~1 s / $0.02 (Timothy Cardoza) |
| Confidence cascade in front of a frontier model | Matched or slightly beat the frontier model at ~26-28% of estimated cost, sending only the uncertain 19-23% onward (Fluixo, summarizing a third party) |

## Grok's eight not-better findings

These eight, all from `grok-application-types-2026-09-26.md`'s "Claimed, but the same sources
said it was not better" list, are the specific benchmark results behind several of this
workspace's exclusions (`SKILL.md` "Anti-patterns" and "When not to use Jev"):

| Type | Result (source) |
|---|---|
| Hot coding-turn routing (Theo) | OpenRouter's own `jev-router` versus GPT-6 Astra-low on DeepSWE: roughly the same performance, slightly higher cost, and almost 5x longer (@theo, X; secondhand, unverified) |
| "Which specialist" answers a live chat | Jev 91.4% and 83.7% versus the original frontier routing at 98.1% and 97.8% (Entagl) |
| One-shot "is this phishing?" | 62.6% versus Haiku 4.5 81.3% on a single undecomposed question (Rajesh Beri) |
| 77-way banking intent | Aman Kumar: 76.0% versus gpt-5.6-luna 81.7%. OpenRouter: 81.0% versus Claude Opus 5 84.4%, though 13x faster and about 1/22 the cost |
| Multi-turn RAG joint state (route, scope, mode, restrictions all correct together) | 61.4% versus self-hosted Gemma 4 31B 77.0% (LargitData) |
| Invoice-style extraction | 61.8% versus GPT-5.6 Terra 74.7% and Claude Opus 5 78.4% |
| Form fill versus a tiny specialist | Hosted Jev 83.6% versus a purpose-built form-fill model at 99.7% |
| Context-compaction recall | 11/12 for Jev's keep/delete calls versus 12/12 for built-in summarization |

## Other reported not-better findings

Nine more from the same "not better" list, not already covered above:

| Type | Result |
|---|---|
| Four-workflow board (vendor's own benchmark) | 67.8% vs 74.1% (GPT-class) and 73.1% (Claude Opus 5) |
| Chart near-miss trading adjudication | A count-matched mechanical rule beat Jev's adjudication outright |
| Financial-research rubric grading | Matched a frontier model on 91.5% of checks at far lower cost, but a mid-size open model agreed 93.5% of the time at its own lower cost |
| Raw score treated as a correctness probability | ECE ran 2.1-2.5x the noise floor even where accuracy was 97.5% |
| Easy claim checks | 91.7% vs 100% for frontier models on the easy tier (Jev led only on the hard tier) |
| Routed-answer p95 latency | 34% slower end-to-end despite a cost and accuracy win, in one full-pipeline benchmark |
| Summary ranking against expert order | Matched a judge model on agreement but was the weaker ranking signal overall |
| Earlier event-listing set (different from the "better" row above) | 49/50 vs a comparator's 50/50 |
| Unsourced fact-checking | Correctly refused to answer 12 of 13 items with no source attached, settling only 1: a correct refusal, not a working fact-checker |

## Workspace exclusions

Separate from every benchmark result above, these are excluded by Matt's own ruling, not by a
measurement: security labels, the policy gate, unmeasured cascades (a fallback never checked
against Jev's own low-confidence slice), generative narrative writing, and memory-sleep verdicts
(manual by Matt's ruling). See `jev-architecture-brief.md` section 6 "Not worth doing" and
`SKILL.md` "When not to use Jev".

## Reading this table

A positive result in one study is not a guarantee for a superficially similar task in this
workspace: decomposition, state shape, and label count moved the same phishing task from 62.6%
to 95.0% in the same source. Use this map to decide whether a *shape* is worth prototyping as an
ad hoc `decide.evaluate` call, then let your own labels (via `decide.log_outcome`) decide
whether it graduates, not the table above.
