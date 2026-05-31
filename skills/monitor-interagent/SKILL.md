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

1. **Resolve scope** (so you report it accurately and don't double-arm):
   - `MACHINE` = `machine:` line from `/c/dev/.machine-id`.
   - `PROJECT` = `git rev-parse --show-toplevel` basename, else cwd basename.
   - The poll script auto-detects both — you do NOT pass them as args. You resolve
     them only to tell the user what scope is being watched.

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
     command: "bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh <interval>"
   }
   ```
   The script polls the `interagent_assignments` table over SSH (`ssh deepthought`
   → `pgvector`), dedupes against a per-machine+project seen-file, and emits one line
   per NEW pending message routed here (to this machine or `any`, tagged for this
   project or untagged broadcast).

4. **Confirm to the user:** what's being watched (machine + project), the interval,
   and that "stop monitoring" disarms it.

## On each wake event (a line from the poller)

Each emitted line is a chat event that wakes this session. When it fires:

1. **Read once:** `interagent_call > inbox {machine: <MACHINE>}`.
2. **Apply routing** (see README table):
   - tagged `{type:"project", id:<this project>}` or addressed to this session →
     surface **and** `claim`.
   - untagged / broadcast → surface, **do NOT** claim (leave for sibling sessions).
   - tagged for another project → **skip**.
3. **Act on the assignment**, then close the loop on the agent side, not just to the
   user: reply with `interagent_call > complete {id, result}` (or `send` a follow-up
   to the originating agent/machine). Per Matt's standing instruction: when you have a
   response to another agent's question, tell the AGENT (via interagent), not only Matt.

## Notes

- This is **opt-in per session** — a running process, not something every session
  carries. It does not survive the session ending.
- It is NOT a hook (hooks in this suite are local-only and cannot do network); it's a
  Monitor-driven background process, which is allowed to SSH.
- `PushNotification` (to Matt's phone/desktop) is a SEPARATE layer for notifying the
  human — not part of this agent-to-agent path. Only use it if the user asks to be
  pinged personally.
- Test the poller without arming: `bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh --once`.
