# Research Dispatch Templates

Fill-in shapes for the Phase 0 research fan-out. Each template names the model tier to
use (see corrections-ledger.md #3: every dispatch names its model, never the default).
Six run as Claude subagents (Sonnet or Opus). Two run on Grok, reached only through
interagent, never as a subagent (see SKILL.md Phase 0).

Every Claude-side agent writes one self-contained markdown file to
`artifacts/research/<slug>/<file>.md` and returns a one-paragraph summary. The director,
never the subagent (anti-pattern A2), stores the corresponding artifact DB row.

## 1. Docs reference (Sonnet)

```
Research [NAME] from zero. Do not assume I know what it is.

Read the official docs, the vendor's own announcement or launch material, and at least
one independent write-up. Cover: what it is, who makes it, when it shipped, what problem
it claims to solve, the core primitives or API surface, pricing, rate limits, context or
size limits, and official SDKs/languages supported.

Write findings to artifacts/research/<slug>/official-docs-reference.md. Every claim
needs a source (URL or publication). Flag vendor claims that are unverified marketing
language as such; do not repeat them as fact.
```

## 2. Integration survey (Sonnet)

```
Given [NAME] (see artifacts/research/<slug>/official-docs-reference.md for the basics),
research how it would integrate into this stack: [name the harness / gateway / runtime
the user actually runs]. Cover: available SDKs and their fit with our language/runtime,
auth model, how a call would be made from our existing infrastructure, and any
architectural constraint the docs impose (statelessness, context limits, streaming).

Write findings to artifacts/research/<slug>/harness-integration-survey.md.
```

## 3. System inventory (Sonnet)

```
Before we decide whether [NAME] is useful, find out where this class of decision
already happens in the user's own stack today. Search memory, project docs, and code
for existing tools, workflows, or manual steps doing the same job [NAME] would do.
Name each one, what it costs (time, tokens, money), and whether it is a good or bad
fit for replacement.

Write findings to artifacts/research/<slug>/system-decision-inventory.md.
```

## 4. Local / self-hosted alternative (Sonnet)

Dispatch by default whenever a vendor is involved (corrections-ledger.md #7). Do not
wait for the user to ask about running it themselves.

```
Research whether [NAME] (or an equivalent open-source/self-hostable model or tool) can
run locally or self-hosted, specifically against this hardware: [name the user's actual
hardware, e.g. GPU, RAM, CPU]. Cover: minimum viable hardware, expected performance at
that hardware tier, licensing, and setup complexity. State plainly whether the user's
current hardware is sufficient, insufficient, or borderline, and what upgrade (if any)
would change that.

Write findings to artifacts/research/<slug>/local-alternatives-<hardware-tag>.md.
```

## 5. Retention comparison (Sonnet)

Dispatch by default whenever a vendor is involved (corrections-ledger.md #9). This must
exist before any retention or egress preference question is asked in Phase 2.

```
Compare data retention policy for [NAME] across every access path the user can actually
reach: direct vendor API, [name every gateway/reseller the user has access to, e.g.
OpenRouter, Vercel AI Gateway, Cloudflare AI Gateway]. For each path: default retention
period, whether a zero-data-retention flag or agreement is available, cost difference if
any, and any limitation the ZDR path imposes (feature loss, latency, model version lag).
Anchor the comparison against what the user already accepts today: [name the user's
existing retention baseline, e.g. "uses Claude Fable for IP work under a 30-day
retention policy"].

Write findings to artifacts/research/<slug>/retention-comparison.md.
```

## 6. Skeptic evidence and rubric (Opus)

```
Take an adversarial pass on [NAME]. Find independent benchmarks (not vendor-published),
build a real cost model at the user's actual expected volume, enumerate failure modes
and the inputs that trigger them, and assess vendor risk (funding, maturity, lock-in).
Then build a comparison rubric: [NAME] versus the incumbent approach(es) from the system
inventory, one row per decision criterion that actually matters here, with a winner and
the evidence behind it.

Write findings to artifacts/research/<slug>/evidence-swot-rubric.md. Where this
contradicts the docs-reference or integration-survey files, name the contradiction and
say which source should win and why.
```

## 7. Social signal (Grok, via interagent only)

Commit the prompt file before sending, per corrections-ledger.md #4 and #5: send only
after the file exists, and arm `/monitor-interagent` in the same turn as the send.

```
Search X, Hacker News, Reddit, and [NAME]'s own changelog/release notes for live signal
on [NAME] from the last [N] days: real user reports, complaints, workarounds, and any
detail the vendor's own docs would not surface. Every finding needs an account handle or
username and a link. Prioritize recency: this is the value you bring that a docs read
cannot. Reply with your findings directly in this message.
```

Save the prompt itself to
`artifacts/research/<slug>/<date>-grok-research-<slug>-social-prompt.md`, commit it, then
send via interagent (`to: dell-xps-grok`, topic tagged to the project) and arm the
monitor before reporting the send as done. Grok replies over interagent, not by writing a
file: when the reply arrives, the director saves it verbatim to
`artifacts/research/<slug>/grok-social-signal-<date>.md`. Grok never writes repo files.

## 8. Application-type survey (Grok, via interagent only)

Dispatch this alongside #7, before Phase 2 opens. It is what keeps the interview from
narrowing to the one application named in the user's opening prompt
(corrections-ledger.md #8).

```
[NAME] is being evaluated as a general mechanism, not for one application. Search for
the full breadth of ways people are actually using it in the wild, every application
type you can find evidence of, not just the obvious one. For each type: a one-line
description, the source (account/link), whether it looks like a real deployment or a
demo/toy, and evidence of where it is a good fit and where it is not, with the reason
for each. Group into rough categories. Reply with your findings directly in this
message.
```

Save and send the same way as #7: committed prompt file first, then the interagent send,
then arm the monitor. Grok replies over interagent; the director saves that reply
verbatim to `artifacts/research/<slug>/grok-application-types-<date>.md`. Grok never
writes repo files.
