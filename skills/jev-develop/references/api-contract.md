# API contract

Two contracts matter here. Agents in this workspace only ever touch the first one. The second
is background for understanding why Jev behaves the way it does.

## 1. The gateway contract (`decide_call`), what agents actually use

Source: `jev-architecture-brief.md` section 3.1. This is the contract the gateway's `decide`
module implements, or will implement once Phase 0 ships. No agent, hook, or n8n node holds a
TypeSafe or OpenRouter key; the gateway holds the one key and enforces every guardrail below.

**`decide.evaluate` request**

| Param | Required | Content |
|---|---|---|
| `purpose` | yes | Kebab-case tag such as `obsidian-filing`. Groups decisions for labels, calibration, and graduation. |
| `state` | yes | String, object, or array of text. |
| `questions` | yes | Map of id to `{type: choice\|score\|noul, instructions, criteria}`. |
| `model` | no | Pin; default `typesafe/jev-1.13`. Aliases such as `jev-latest` are rejected. |
| `thresholds` | no | Per-question `{act, review}`. Default act 0.90, review 0.60 on `pmax` or `noul`. |
| `source_refs` | no | Ids of the records the state came from, so egress checks can run on them. |

**`decide.evaluate` response**

```
{decision_id, purpose, calibrated, model_resolved, usage: {input_tokens, cost_usd, elapsed_ms},
 answers: {<id>: {type, value, probabilities, confidence, pmax, band: act|review|abstain}}}
```

`calibrated` is `false` until the purpose has a fitted calibration row. The `band` is advice,
not an instruction to act; callers act only within their own grants.

**Error response**

```
{decision_id, action: unavailable|refused_egress|invalid, error: {code, message, retryable}}
```

No partial answers are ever returned. `invalid` covers schema failures, an oversize state, a
missing `purpose`, or an alias model. `unavailable` covers timeout (3 s), 429/529 after one
retry, 5xx, a malformed or incomplete answer, or a cost-guard trip. `refused_egress` is
distinct and never overridable by the caller (`references/egress-rules.md`).

**Other tools**

- `decide.log_outcome`: records the true label for any decision. Required before any
  calibration or graduation. Limited to the caller's own decisions except for
  `matt-interactive`.
- `decide.email_triage`, `decide.route_task`, `decide.gate_tool_call`: thin presets that build
  their own state from a reference (not raw text, for email) and call `evaluate` internally
  with a versioned battery, then return a calibrated action band.

**Server-side guardrails on every call, regardless of preset:**

- Egress rules run on `source_refs` and on the raw text itself, with no override for any
  identity; redaction runs before sending. Refused state returns `refused_egress`. A separate,
  independent byte-level marker screen runs on top of the record-based checks
  (`references/egress-rules.md`).
- Every call carrying free text gets the module's own `instructs_reader` Noul appended
  automatically, in addition to the caller's own questions; `>= 0.5` forces `escalate`
  regardless of the caller's other answers (`references/egress-rules.md`).
- The module verifies zero data retention with its provider at startup and passes `zdr: true`
  on every provider call; until ZDR is verified it stays in mock mode and returns `unavailable`
  for real calls (`references/egress-rules.md`).
- Size budget: 32k tokens for state plus questions (OpenRouter path), estimated before sending.
- At most 50 questions per call, 255 options per Choice, 2-10 described levels per Score.
- Each identity has a rate window and a daily cost cap, reserved atomically before a call goes
  out so two concurrent calls cannot both slip in under a cap only one can afford; the cap trips
  into `unavailable`.
- For a scoped identity (`grokbot-assistant`, `claude-assistant`, the n8n identity), the server
  computes `band` only from a fitted calibration row keyed on `(purpose, provider,
  model_resolved, battery_version, question_id)` and ignores any `thresholds` the caller passed;
  an uncalibrated purpose returns `review` or `abstain`, never `act`, for that identity
  (`references/thresholds-and-calibration.md`).
- Every call writes a full `decision_log` row carrying `purpose`. State text itself is never
  stored in the gateway, only a hash and a reference.
- Cache is off for `evaluate` and `route_task` (states rarely repeat); on for `email_triage`
  with a 7-day TTL.

## 2. Phase 1: the editable config store (`decide.config_get`, `decide.config_review`, `decide.config_set`)

Source: decision 43. Not shipped in Phase 0; policy files are authoritative until it lands.

Phase 0 tunables (patent and TAS markers, attorney names, category sets, thresholds) live in
policy files the gateway reads at startup. Phase 1 moves the **hot** half of that set, phrases,
attorney names, TAS org names, category sets, and thresholds, into a versioned Postgres store:

- `decide.config_get`: reads the current value of a config key. Granted to `grokbot-assistant`,
  `claude-assistant`, and `matt-interactive`.
- `decide.config_review`: reads a key's version history and pending changes, for auditing before
  or after a `config_set`. Same grant as `config_get`.
- `decide.config_set`: writes a new version of a config key. `matt-interactive` only; no scoped
  identity may write its own thresholds.

The **floor** half, identity-based markers (which mailboxes, grants, and identities exist) and
any key marked file-only, stays in policy files regardless of Phase 1, and changing it needs a
deploy. Once Phase 1 ships, treat `decide.config_get` as the source of truth for hot keys and the
policy files as the floor and the fallback if the config store itself is unavailable.

## 3. The underlying vendor wire contract, for context

Source: `official-docs-reference.md` section 1, as documented by TypeSafe (docs.typesafe.ai)
for `POST https://api.typesafe.ai/v1/systemone`, and mirrored by OpenRouter's
`POST https://openrouter.ai/api/v1/systemone` (model id `typesafe/jev-1.13`). This is what the
gateway's provider layer speaks; agents never call it directly.

| Field | Type | Notes |
|---|---|---|
| `state` | string / object / array | Text only. |
| `model` | string | e.g. `jev-1.13.0`; `jev-latest` and `jev-preview` both currently resolve to it and move without notice. |
| `questions` | map<id, Question> | Each has `type` and `instructions`; type-specific `criteria`. |

Response: `{model, answers, usage: {input_tokens, output_tokens}}`. Output tokens are always 0
(output pricing is free). Errors: 401 (auth), 422 (validation), 429 (rate limit), 529
(overloaded); the docs recommend exponential backoff, which the gateway's provider layer
performs so callers of `decide_call` see only `unavailable` on exhaustion.

Limits per the vendor: 64k tokens total per request, 32k for state plus the longest question;
throughput 250,000 tokens/sec and 1,200 requests/min, "adjusting dynamically"; text only, no
images/audio/video; lower accuracy on non-English including CJK scripts. Pricing: $0.042 per
million input tokens, output free (`evidence-swot-rubric.md` section 1 notes roughly 260 fixed
tokens per request plus a tokenizer that runs 1.2-3x heavier on non-English text, so the
effective per-decision cost is higher than the raw rate implies).

No published deprecation policy or version-lifetime statement exists for vendor model ids.
