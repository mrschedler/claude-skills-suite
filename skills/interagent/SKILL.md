---
name: interagent
description: Use when the user wants to post, read, or audit agent-to-agent messages and to-dos via the interagent system — e.g. "leave a message/to-do for a future agent", "message session B", "check interagent", "what's waiting for me", "interagent history on <topic>", or "send <agent> a task". Routes natural phrasing to the correct interagent_call tool. For the live auto-react watcher, see the monitor-interagent skill (this skill points you there).
---

# Interagent

The front door to the **interagent** messaging system: a Postgres-backed,
cross-machine, claim-based queue of messages and durable to-dos, exposed through the
gateway as `interagent_call` / `interagent_list`. This skill maps how you *talk*
about agent messaging to the exact tool calls — so a fresh agent never has to recall
the API.

## CRITICAL API shape (read first)
`interagent_call` takes the tool name plus args **nested under `params`**:
```
interagent_call({ tool: "inbox", params: { machine: "dell-xps" } })
```
A flat call (`interagent_call({tool:"inbox", machine:"dell-xps"})`) silently drops the
args — `machine` arrives as undefined. This bit multiple sessions. Always nest under `params`.

(Same nesting applies to `vault_call` and `redis_call`.)

## Scope resolution
- `MACHINE` = `machine:` line from `/c/dev/.machine-id` (e.g. dell-xps, skip).
- `PROJECT` = `git rev-parse --show-toplevel` basename, else cwd basename.
- Use these for `from`, `machine`, and (via `topic`/`context_refs`) project tagging.

## The thin-read model (why this exists)
`inbox` and `list` return **headlines only** (id, kind, topic, title, status, to, from,
created_at) — never the message body. This keeps a scan from filling your context. To
read one full message, call `get {id}`. **Never** dump full bodies to triage; scan thin,
then `get` the one you care about.

## Verb routing

| User says | Call |
|---|---|
| "leave a to-do / note for a future agent to fix X" | `todo {title, prompt, from:MACHINE, topic}` — durable, never expires, to='any' |
| "message session B / dell-xps that …" | `send {to, title, prompt, from:MACHINE, topic, kind:'msg'}` |
| "send <agent> a task: …" | `send {to, title, prompt, from:MACHINE, topic, priority}` |
| "check interagent / what's waiting for me" | `inbox {machine:MACHINE}` (thin) → `get {id}` on the relevant one |
| "show me everything incl. claimed" | `inbox {machine:MACHINE, include_claimed:true}` |
| "what's the history / audit on <topic>" | `list {topic:'<topic>'}` (thin) → `get {id}` as needed |
| "show the <thread> conversation" | `list {thread_id:'<id>'}` then `get` each |
| "read message 142 / open that one" | `get {id:142}` |
| "I'll take that one / claim it" | `claim {id, machine:MACHINE}` |
| "mark it done: <result>" | `complete {id, result}` (status defaults 'completed'; 'failed' on failure) |
| "did <agent> pick up my message?" | `check {id}` |
| "tidy / archive that completed item" | `archive {id}` (hides from inbox/list, preserves history) |
| "monitor interagent / watch for messages" | → use the **monitor-interagent** skill (arms a background poller) |

## Conventions
- **topic**: short kebab tag for filtering/audit, e.g. `backup`, `g3-claims`, `dd-deploy`.
  Encourage one whenever the user implies a subject — it's what makes the store auditable.
- **kind**: `msg` (default, expires per ttl) vs `todo` (durable, never expires). Use `todo`
  for "leave this for later / for a future agent."
- **to**: a machine name (`dell-xps`, `skip`) or `any` (next free agent claims it).
- **ttl_hours**: omit for default (72 for msg); pass `null` to never expire (todo does this
  automatically). To-dos created before v2 used to vanish at 72h — `todo` fixes that.
- **context_refs**: attach `[{type, id, label}]` pointers to memories/plans/projects when relevant.

## Routing rules when reading the inbox
After `inbox`, decide per message:
- tagged for THIS project (via topic/context_refs) or addressed to this session → surface **and** `claim`.
- untagged / broadcast → surface, **do NOT** claim (leave for sibling sessions).
- tagged for another project → **skip**.

When you have an answer to another agent's question, **close the loop on the agent side** —
`complete {id, result}` or `send` a reply to the originating machine — not only to the human.

## Examples

"leave a to-do to fix the server backup cron"
→ `interagent_call({tool:"todo", params:{title:"Fix server backup cron", prompt:"<details>", from:"dell-xps", topic:"backup"}})`

"check interagent"
→ `interagent_call({tool:"inbox", params:{machine:"dell-xps"}})` → then `get {id}` on anything relevant.

"what's the history on the g3-claims topic"
→ `interagent_call({tool:"list", params:{topic:"g3-claims"}})`

## Notes
- Durable + offline-safe: rows persist whether or not a session is watching. A live watcher
  (monitor-interagent) just makes a session react *immediately*; without it, the next inbox
  read still finds everything.
- Tool mechanics live in `interagent_list`; this skill is the intent→call layer; the
  SessionStart/UserPromptSubmit hook is the habit layer (reminds you to check). Three layers,
  so discovery is pull, not recall.
- v2 (2026-05-31) added: thin reads, `get`, `todo`, `archive`, `topic`/`kind`/`thread_id`,
  never-expire to-dos. Design: see Qdrant memory "interagent v2 tool design" / artifact
  `mcp-gateway/design/interagent-v2-tool-design`.
