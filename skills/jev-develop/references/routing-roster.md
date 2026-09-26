# Routing roster (route_task)

Source: `jev-architecture-brief.md` sections 5.1-5.5 and `harness-integration-survey.md`
sections 3 and 7. This is the full detail behind Phase 4 of `SKILL.md`.

## Scope

`route_task` is a preset on `evaluate`. It runs before an Agent dispatch on a cold subagent
brief only, never on a live, ongoing conversation. Independent evidence backs this scope
limit: OpenRouter's own model-tier router measured roughly the same accuracy, slightly higher
cost, and about 5x slower wall time than simply running a cheap model at low effort on a hot
coding turn (a widely repeated but unverified secondhand report); a separate router lost
$19.53 over 309 requests by re-routing mid-conversation and discarding the prompt cache. Route
once per dispatch; a resumed agent keeps its model.

## State shape

```json
{
  "task_brief": "<the prompt about to be sent, up to 6,000 chars>",
  "project": "memory-system",
  "facts": {
    "matt_named_a_model": null,
    "brief_mentions_shared_infra_paths": true,
    "brief_mentions_remote_or_server_ops": false,
    "prior_attempt_failed": false,
    "task_writes_to_repo": true
  }
}
```

`facts` are regex and flag checks done in code, never asked of Jev. Briefs touching lan-only or
patent material are refused by the egress policy before this state is even built; that work
stays in the current session or goes to Matt, and Grok is never a route for it.

## Battery (question wording, verbatim from the brief)

| id | Type | Instructions | Options / levels |
|---|---|---|---|
| `engine` | Choice | "What kind of worker should handle the task in `task_brief`?" | `code`: an exact lookup, count, date comparison, regex, file listing, or a script with known steps. `jev`: a single snap judgment over information already in hand, a list pick, a rated scale, or yes/no, with no text to write. `llm_agent`: reading, writing, or editing code or prose, multi-step investigation, or synthesis across sources. `human`: a preference, a spend, credentials, anything sent in Matt's name, deletes, server or secret operations. |
| `agent` | Choice | "If an AI agent does the task in `task_brief`, which agent fits? Pick the cheapest that would reliably get it right. Judge difficulty and blast radius, not the length of the brief." | `sonnet`: everyday work with a clear scope: implement to a spec, write or fix tests, scribe or summarize, run a checklist review, gather facts from known files. `opus`: judgment: ambiguous goals, design trade-offs, subtle or cross-file bugs, security-sensitive code, adversarial verification, reviewing another agent's work. `grok`: judgment that benefits from an independent second model or live X and social search, where minutes of interagent latency are acceptable. `director`: the task needs this conversation's accumulated context and would take longer to brief than to do. |
| `effort` | Choice | "How much deliberation does the task in `task_brief` need before acting? Pick the lowest level at which a careful engineer would still trust the result." | `low` "Quick one-pass answer" through `max` "Correctness dominates cost and time," with `medium` and `high` between. |
| `is_routine` | Noul | "Would two competent engineers given `task_brief` produce essentially the same result?" | |
| `context_sufficient` | Noul | "Does `task_brief` contain enough context for someone who has not seen this conversation to start work?" | |
| `irreversible` | Noul | "Would carrying out `task_brief` change something that reverting a commit cannot undo: remote state, sent messages, deleted data, server or secret changes?" | |
| `harness` | Choice | "Which check should confirm the result of `task_brief` before it is trusted?" | `none`, `unit_tests`, `api_tester`, `browser_review`, `verifier_agent`, `matt_review`, each with a one-line description. |
| `importance` | Score | "How much depends on the task in `task_brief`?" | 0 "Nice to have; no one is waiting." 1 "Part of the current sprint." 2 "Blocks Matt or a live system today." Used only with the code rules below, never alone. |

## Code rules that sit on top of the answers

1. Matt's explicit instruction wins, including a named model.
2. A hard human list, no Jev involved: sends in Matt's name, deletes, server and secret
   operations, matched by keyword and path. This is a code check that runs before any provider
   call is made, so it applies even when `route_task` is unavailable or in mock mode.
   `irreversible` ≥ 0.50 adds to this list, never subtracts from it.
3. Default Sonnet for routine work. Upgrade to Opus when `agent` = opus at `pmax` ≥ 0.70, or
   `is_routine` < 0.50, or `importance` ≥ 1.5 with `is_routine` < 0.80.
4. Grok only when `agent` = grok at `pmax` ≥ 0.80 and egress passes, dispatched via an
   interagent prompt file, never via the Agent tool (which only runs Claude models).
5. Never downgrade on doubt: moving from LLM to Jev or code needs `engine` `pmax` ≥ 0.85 and
   `is_routine` ≥ 0.80. Every surveyed router converged on this rule independently.
6. Never route to the director's own model for a subagent; `agent` = `director` means the
   director does the work itself, not a subagent.
7. Route once per dispatch; a resumed agent keeps its model.
8. `context_sufficient` < 0.50 means rewrite the brief before dispatching, not dispatch anyway.
9. On `unavailable`, `route_task` itself returns `abstain`: it never fabricates a
   recommendation. The protocol step calling it is the one that falls back to today's static
   default rule.
10. The model id `route_task` resolves to is checked against `policy/decide-model-allowlist.json`
    (hashed, loaded at startup, never in code) the same way `evaluate` checks it; an unlisted
    echoed id or a hash mismatch puts the module in mock until a reviewed policy change.

## How other routers phrase the same criteria

For calibration when writing a similar battery elsewhere, other surveyed routers converge on
this wording pattern (`harness-integration-survey.md` section 3):

- Model tier: "Which model tier fits the task? Pick the cheapest tier that would reliably get
  this right. Judge difficulty and blast radius, not length of the message."
- Effort: "How much deliberation does the task need before answering or acting? Pick the
  lowest level at which a careful engineer would still trust the result."
- Follow-up detection: "Is this message a short continuation of the previous reply that only
  makes sense given that reply?" Every router that skipped this needed it added later.

None of the surveyed routers name a vendor in their criteria; they describe the work and map a
tier to a model in a separate table, which keeps the battery portable across model rosters.

## Convergent policy across all surveyed routers

1. An explicit user request always wins.
2. Below the confidence threshold (0.7 in most), never downgrade.
3. Route once per conversation or per fresh turn, then pin.
4. Skip Jev above a large context size and cap the switch cost.
5. Keep the state small: the task text and a short structured summary, not the full context.
6. Fail open: a timeout or bad answer passes the request through unchanged. This workspace's
   `route_task` implements the same end effect differently: it returns `abstain` rather than
   guessing, and the calling protocol step supplies the fallback (see rule 9 above).
