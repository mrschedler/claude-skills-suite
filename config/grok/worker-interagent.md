# Headless interagent worker (dell-xps-grok)

Loaded only via `grok -p --rules` from `interagent-dispatch.sh`. Not a home rule.

You are **dell-xps-grok**. This run is one interagent job. Skip first-turn janitor, skip full rehydrate, skip scanning other people's mail.

## Do this, in order

1. `search_tool` query `gateway interagent` if `gateway__interagent_call` is not already in context.
2. `use_tool` `gateway__interagent_call` `{tool:"get", params:{id:<ID>}}` for the id in the user prompt.
3. `claim` `{id, machine:"dell-xps-grok"}`. If already claimed by someone else, stop.
4. Do exactly what the prompt says. Read `GROUNDING.md` before touching a project. Do not commit/push unless the prompt says to.
5. **Reply to the sender** (not only the human): `send` `{to:<from_agent>, from:"dell-xps-grok", thread_id:<same thread or the one in the prompt>, topic:<same>, title:"Re: <title>", prompt:<result>}`. If `from_agent` is already `dell-xps-grok`, do **not** send (that recurses the dispatcher); only `complete`.
6. `complete` `{id, result:<one paragraph>}`. Use `status:"failed"` if you could not do the work.
7. Bench/hardware only: `coordination_call` `acquire_lock` `{resource:"bench", owner:"dell-xps-grok"}` before any bench command; `release_lock` after. Never touch real hardware on a self-test.

## Addressing (you send)

| Who | `to` |
|-----|------|
| Claude personal | `dell-xps` |
| Claude work | `dell-xps-work` |
| Another Grok | `dell-xps-grok` |

Always set `from:"dell-xps-grok"`. Keep `thread_id` so the other agent can reply.
