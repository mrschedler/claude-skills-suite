---
name: monitor-interagent
description: Use when the user says "monitor interagent", "/monitor-interagent", "watch interagent", or otherwise wants THIS session to auto-react to new interagent mail while idle (instead of only checking when prompted). Arms the Monitor tool with the interagent poll script, scoped to the current project. Also handles "stop monitoring" / "/monitor-interagent stop" to disarm. Deterministic front door to the "monitor interagent" command in behavioral-reminders Step 5.
argument-hint: [stop to disarm | <seconds> poll interval, default 5]
---

# Monitor Interagent

Arm (or disarm) a persistent background poller so this session reacts to new
[interagent](../../hooks/README-interagent-push.md) mail **while idle**, without
waiting for the user to say "check interagent". The underlying mechanism is the
`Monitor` tool running `interagent-monitor-poll.sh`; this skill is just a reliable,
discoverable way to invoke it (so it never depends on the agent happening to notice
a natural-language phrase).

## Disarm path (run this first if asked to stop)

If the argument is `stop` (or the user said "stop monitoring" / "stop watching
interagent"):

1. Find the running interagent monitor via `TaskList` (look for a Monitor task whose
   description starts with `interagent inbox`).
2. `TaskStop` that task.
3. Confirm: "Stopped monitoring interagent for `<project>`." Then stop — do not arm.

## Arm path

1. **Resolve scope** and pass it explicitly:
   - `MACHINE` = `machine:` line from `/c/dev/.machine-id` (see the table below).
   - `PROJECT` = `git rev-parse --show-toplevel` basename, else cwd basename.
   - **Check the PROJECT you resolved is really this project.** `$HOME`
     (`C:/Users/matts`) is itself a git repo root, so from any directory under it
     that is not its own repo — Git-Bash `/tmp` maps in there too — the git-root
     inference returns `matts` and the session silently watches the wrong scope.
     If that is what you got, use the real project name.
   - The script can infer both, but pass them anyway: it announces what it resolved
     (`INTERAGENT watching machine=… project=… source=…`) as its first line, and an
     explicit `INTERAGENT_PROJECT` overrides the inference outright.

2. **Don't double-arm.** `TaskList` first. If a Monitor task with description
   `interagent inbox (project=<this project>)` is already running, tell the user it's
   already armed and stop. One poller per project per session is enough.

3. **Arm the Monitor tool.** Default interval 5s (fast enough for live multi-session
   coordination; a single SSH round-trip is ~0.3s so DB cost is negligible). If the user
   passed a number, use it. For a long, mostly-idle watch, a larger interval (30–60s) is fine.
   ```
   Monitor {
     description: "interagent inbox (project=<PROJECT>)",
     persistent: true,
     command: "INTERAGENT_MACHINE=<MACHINE> INTERAGENT_PROJECT=<PROJECT> INTERAGENT_MAX_LIFETIME_S=2100 bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh <interval>"
   }
   ```
   The poller's first stdout line reports the scope it actually resolved. **Read
   it.** If it does not say the project you meant, disarm and re-arm with the
   right `INTERAGENT_PROJECT` — a poller on the wrong scope looks perfectly
   healthy and delivers nothing.

   **Spell out `INTERAGENT_MACHINE` for every Claude row, the personal `claude`
   session included** — there it merely repeats the `.machine-id` default, and that
   is the point: an unnamed poller is indistinguishable from any other in a process
   list, and a machine-wide kill sweep took out three sessions on 2026-09-21 for
   exactly that reason.

   | Launch | `INTERAGENT_MACHINE` |
   |---|---|
   | `claude` | `dell-xps` |
   | `claude-work` | `dell-xps-work` |
   | `grok-agent` | `dell-xps-grok` |

   **`INTERAGENT_MAX_LIFETIME_S=2100` is not optional for this caller.** The Monitor
   tool caps at 30 minutes and leaves its poller running past that, so without the cap
   every armed watch leaves a process behind. At 2100s (35 min) the poller prints
   `INTERAGENT poller lifetime reached (2100s) - re-arm` and exits 0; re-arm it the
   same way if the user is still working.

   The script polls the `interagent_assignments` table over SSH (`ssh deepthought`
   → `pgvector`) and emits one line per pending, **unclaimed** message routed here
   (to this machine or `any`, tagged for this project or untagged broadcast), plus
   sender-side lines for mail this machine sent.

   Other callers of the same script, for reference:
   ```bash
   # Grok's PowerShell -> bash watcher (its own inbox name, no Monitor cap)
   INTERAGENT_MACHINE=dell-xps-grok bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5

   # one pass, no arming (test)
   bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh --once
   ```

   **Rolling this out across a fleet: one pass, not session by session.** Old and
   new pollers must not coexist on a machine — an old-format state file carries no
   owner record, so a new poller's sweep can judge it only by age and will remove a
   quiet-but-live old poller's state after about a day. So: `/monitor-interagent
   stop` in **every** live session first; install *both*
   `hooks/interagent-monitor-poll.sh` and `hooks/interagent-monitor-process.js`
   (the poller does nothing without the second); re-arm each session with
   `INTERAGENT_MACHINE` **and** `INTERAGENT_PROJECT` set; and in each one confirm
   the first stdout line says `source=INTERAGENT_PROJECT` and names the project you
   meant. Any other source, or the wrong project, means disarm and re-arm.

4. **Confirm to the user:** what's being watched (machine + project), the interval,
   the 35-minute lifetime, and that "stop monitoring" disarms it.

## The claim IS the acknowledgement — claim promptly, then work

Nothing in this system stamps "delivered". The poller cannot prove a live reader
(on Git-Bash a write into an unread pipe succeeds for 64 KiB, so every probe lies),
so it does not try: **the acknowledgement is your `claim`**, which only a session
that actually read the message can write.

So: **claim first, then do the work.** Do not read a message, start working, and
claim at the end. Until you claim it:

- it is re-announced every time a poller is armed here, and
- the sender is told `UNCLAIMED #id … - 5 min` and again at 15 and 60.

Both are correct behaviour, not noise — an unclaimed message genuinely has nobody
holding it.

## On each wake event (a line from the poller)

Each emitted line is a chat event that wakes this session.

| Line | What it means | What to do |
|---|---|---|
| `INTERAGENT new #id [project=…] from …` | pending, unclaimed, routed here | `inbox`, then **`claim` at once**, then work, then `complete` |
| `INTERAGENT new #id [broadcast] from …` | untagged broadcast, under 24h old | surface it; **do NOT claim** (leave it for sibling sessions) |
| `CLAIMED #id by <who> after <n> s` | mail *you sent* was picked up | nothing — it is confirmation |
| `COMPLETED #id: <result snippet>` | that work is done | read the snippet; `inbox` for the full result if you need it |
| `UNCLAIMED #id <title> - 5/15/60 min` | mail *you sent* has nobody holding it | the receiver is not watching, is busy, or is offline. Chase it another way, or tell Matt |
| `INTERAGENT WARN: poll failed …` | the ssh/psql hop is down | **not** an empty inbox. Nothing was marked seen; it will all be re-announced on recovery |
| `INTERAGENT recovered: …` | the hop is back | nothing |
| `INTERAGENT poller lifetime reached …` | the 35-minute cap | re-arm if still working |

Routing for what you claim (see the README table):

- tagged `{type:"project", id:<this project>}` or addressed to this session →
  surface **and** `claim`.
- untagged / broadcast → surface, **do NOT** claim (leave for sibling sessions).
- tagged for another project → **skip**.

Then **act on the assignment** and close the loop on the agent side, not just to
the user: reply with `interagent_call > complete {id, result}` (or `send` a
follow-up to the originating agent/machine). Per Matt's standing instruction:
when you have a response to another agent's question, tell the AGENT (via
interagent), not only Matt.

## Notes

- This is **opt-in per session** — a running process, not something every session
  carries. It does not survive the session ending.
- It is NOT a hook (hooks in this suite are local-only and cannot do network); it's a
  Monitor-driven background process, which is allowed to SSH.
- `PushNotification` (to Matt's phone/desktop) is a SEPARATE layer for notifying the
  human — not part of this agent-to-agent path. Only use it if the user asks to be
  pinged personally.
- Test the poller without arming: `bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh --once`.
- **Re-arming re-announces still-unclaimed mail. That is intended** — a message
  nobody claimed should come back. Old untagged broadcasts (over 24h) do not, and
  `CLAIMED`/`COMPLETED` from before the poller started are never replayed.
- Each poller keeps its dedupe state in its own per-pid directory under
  `%LOCALAPPDATA%\claude-interagent\`, deleted on exit. Two pollers cannot
  interfere with each other, so a leftover one from an expired Monitor is harmless
  — you never need to hunt for a stale pidfile or "clear the seen-file" before arming.
- Offline test suite (no network, no live DB):
  `bash /c/dev/claude-skills-suite/hooks/testdata/interagent-delivery-ack/run-tests.sh`.
