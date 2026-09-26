# Egress rules

Source: `jev-architecture-brief.md` sections 3.4, 3.5, 3.9, and the retention research
(`retention-comparison.md`, `grok-retention-signal-2026-09-26.md`). These rules are enforced by
the gateway itself, server-side, before any provider call. No agent, hook, or skill can
override them; this file exists so an agent understands what will be refused and why, and does
not try to route around a refusal by pre-processing restricted content itself.

## Egress refusal order (server-side, no override)

Evaluated in this order on every call, including a raw ad hoc `evaluate`. Any hit returns
`action: refused_egress`, distinct from `unavailable`, and logs only a reason code, never the
content:

1. **TAS mailboxes and material:** always refused.
2. **Mailbox or folder not on the allow list:** refused.
3. **Records classified `lan-only`:** refused (routes to a local provider once one exists,
   never to a hosted vendor). This check runs on the raw `state` and `questions` text itself for
   every caller, not only on records reached through `source_refs`. An ad hoc `evaluate` call
   cannot bypass it by typing restricted content inline instead of citing a record.
4. **Patent material** (by tag, project slug, or marker regex): refused (same local-only
   routing once available), and likewise checked against the raw text itself, not only against
   cited records.
5. **Redaction:** secrets, one-time codes, and card/account numbers are stripped from anything
   that does pass the first four checks, before it leaves the gateway.

Independently of the four record- and classification-based checks above, the `decide` module
runs its own deterministic, byte-level marker screen over every call's `state` and `questions`,
regardless of what classification mode the rest of the gateway is running in. This screen is a
second, independent layer, not a substitute for rules 1-4, and it has no override for any
identity, including `matt-interactive`.

These checks apply to every tool and every caller, including a `matt-interactive` ad hoc
`evaluate` call typed directly by a Claude session. There is no grant that bypasses them.

## Fail-closed semantics

Timeout (3 s), a 429/529 after one retry, a 5xx, a malformed or incomplete answer, or a
cost-guard trip all return `action: unavailable`, never a partial answer. Callers that would
act on the result must treat both `unavailable` and `refused_egress` as "do not act; send to
review." An advisory preset such as `route_task` returns `abstain` on `unavailable`: it never
fabricates a recommendation of its own. It is the protocol step calling that preset, not the
preset itself, that falls back to its own static default on an `abstain`. This is a caller-type
distinction, not a severity distinction: acting calls fail closed, and the thing an advisory
preset hands back on failure is a clearly-marked non-answer rather than a guess.

The module also verifies zero data retention (ZDR) with its provider at startup. Every
provider call it makes carries the `zdr` flag explicitly; if ZDR cannot be verified, the module
stays in mock mode and returns `unavailable` for real calls rather than send content to a
provider under unverified retention terms. The hard human list in `route_task` (sends in Matt's
name, deletes, server or secret operations) is a code check that runs before any provider call
is made, not a Jev-driven decision, so it applies even when the module is in mock or is
returning `unavailable`. Allowed model ids live in `policy/decide-model-allowlist.json`, hashed
and loaded at startup, never in code; an unlisted echoed id or a hash mismatch puts the module in
mock until a reviewed policy change. Each identity's daily cost cap is reserved atomically
before a call goes out, so two concurrent calls cannot both slip in under a cap that only one of
them can actually afford.

Any call carrying free text (an email body, a task brief, an untrusted excerpt) also gets the
module's own `instructs_reader` Noul appended automatically, on top of whatever questions the
caller asked. A score at or above 0.5 forces `escalate` regardless of what the caller's own
questions returned. In Phase 0, a Grok-sourced recommendation arriving through any preset is
suggest-only for every identity, not only unattended ones: the module never sends anything on
Grok's word, and a `matt-interactive` caller decides as a human, reading the recommendation
rather than having it executed on their behalf.

## Where the data actually goes today

Every hosted path sends the state's text to TypeSafe for the call; "zero data retention" (ZDR)
means the content is not kept afterward, not that it never left the machine. The decided
provider order for this workspace (the charter, `jev-application-project.md`, read together with
`retention-comparison.md` and `grok-retention-signal-2026-09-26.md`) is:

1. **OpenRouter, `typesafe/jev-1.13`, with `zdr: true`, pay-as-you-go.** The only hosted path in
   Phase 0. No waitlist, one key already in Vault, echoes `usage.cost`. OpenRouter's own ZDR
   endpoint list includes this model as of 2026-09-26, confirmed live
   (`grok-retention-signal-2026-09-26.md` section 2); whether both of OpenRouter's HTTP surfaces
   (`/api/alpha/decisions` and `/api/v1/systemone`) honor `zdr` identically is not independently
   confirmed (`retention-comparison.md` gaps section), so the gateway always passes the flag
   explicitly and verifies it at startup rather than assuming it (see Fail-closed semantics
   above).
2. **Vercel AI Gateway with `zeroDataRetention: true`, only if Matt upgrades to a Vercel Pro
   plan.** Vercel has the strongest directly-quoted contract language of any hosted path, a
   confirmed ZDR provider-table entry with TypeSafe's own clause that it will not retain prompts
   "for any longer than is necessary to generate Output," but the toggle requires Pro or
   Enterprise, and the charter's own decision (`jev-application-project.md`) is explicitly "no
   Vercel Pro upgrade" for now. This tier stays second, not adopted, until Matt changes that
   decision.
3. **TypeSafe direct, after a zero-retention agreement, or for non-sensitive material only.**
   Enterprise ZDR removes an intermediary but is gated behind a sales conversation, and as of the
   charter date TypeSafe signups were still paused (`grok-retention-signal-2026-09-26.md` section
   1). Absent enterprise ZDR, TypeSafe direct's own retention language is vague ("as long as
   reasonably necessary"), so this path is for after that agreement exists, or for material that
   does not need ZDR at all.
4. **Local: a Kev or Laya clone via `simple-jev` on Unraid CPU.** Nothing leaves the machine, so
   there is no third-party retention question. Shadow-only until its own calibration row is
   fitted (`references/thresholds-and-calibration.md`), and it is the only engine allowed to see
   `lan-only` or patent state, at any time, regardless of what the hosted tiers above look like.
   That assignment does not wait for local calibration to finish. No GPU has been purchased; a
   CPU-only clone is measurably less accurate and worse-calibrated than hosted Jev
   (`jev-architecture-brief.md` section 3.9).

Two paths were checked and are not used: **Cloudflare Workers AI / AI Gateway** labels the model
zero-retention in its catalog, but gateway logging is on by default and separately switchable,
and whether this path even carries Jev today was not independently confirmed. **Standard
(non-ZDR) keys on any provider** have vague, unfixed retention language and are avoided for
anything beyond already-public or already-low-sensitivity text.

## What this means for state design

Regardless of which provider tier is live, keep these habits (`retention-comparison.md`
recommendation), because they are the control an agent actually has:

- Send headers-and-facts extracts, never a full thread or document.
- Cap untrusted body text at roughly 1,500 characters.
- Strip attachments, inline images, and tracking content before building state.
- Redact account numbers, one-time codes, and anything the redaction pass might miss on its
  own: do not rely on the gateway's redaction as the only layer.
- Treat every provider's ZDR flag as something that must be explicitly set on each call, never
  as a silent default.

## Decisions already made for this workspace

From the approved charter (`jev-application-project.md`), read with `retention-comparison.md`
and `grok-retention-signal-2026-09-26.md`: hosted path is OpenRouter `typesafe/jev-1.13` with the
`zdr` flag, pay-as-you-go, key already in Vault, the only hosted path in Phase 0. Vercel AI
Gateway with `zeroDataRetention: true` is second, adopted only if Matt upgrades to Vercel Pro,
which he has declined for now. TypeSafe direct is third, used after a zero-retention agreement
or for non-sensitive material only. A local Kev or Laya clone via `simple-jev` on Unraid CPU is
fourth, shadow-only until calibrated, and the only engine for `lan-only` or patent state at any
time; no GPU purchase is planned yet. Email scope: stripped 1,500-character bodies over the
zero-retention path, all five non-TAS mailboxes in scope, starting with the two QuickLinks boxes
plus Gmail, label-only shadow for two weeks before any per-action graduation.
