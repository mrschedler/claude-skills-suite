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

Who to `send` `to` / `from` lives in the **interagent** skill. This skill is only
**how THIS session watches its own inbox** (and sees delivery/claim/complete on
mail it sent).

## Setup on YOUR end (copy the row that is you)

The poller keys the inbox by `$INTERAGENT_MACHINE`, else the `machine:` line of
`/c/dev/.machine-id`. Put the name in the **poller command** — do not assume a
child process inherits the launcher env.

| You are | Launch | Your name | Arm polling with |
|---|---|---|---|
| Claude personal | `claude` | `dell-xps` | `/monitor-interagent` → `bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5` |
| Claude work | `claude-work` | `dell-xps-work` | `/monitor-interagent` → `INTERAGENT_MACHINE=dell-xps-work bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5` |
| Grok TUI | `grok-agent` | `dell-xps-grok` | `/monitor-interagent` → PowerShell: `$env:INTERAGENT_MACHINE='dell-xps-grok'; & 'C:\Program Files\Git\bin\bash.exe' -lc '/c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5'` |
| Grok, no TUI | `interagent-dispatch.sh` | `dell-xps-grok` | Do **not** also arm this skill (race on claim). Dispatcher is the watcher. |

## Disarm path (run this first if asked to stop)

If the argument is `stop` (or the user said "stop monitoring" / "stop watching
interagent"):

1. Find the running interagent monitor (Claude: `TaskList`; Grok: the `monitor` task whose
   description starts with `interagent inbox`).
2. Stop it (Claude: `TaskStop`; Grok: `kill_command_or_subagent`).
3. Confirm: "Stopped monitoring interagent for `<project>`." Then stop — do not arm.

## Arm path

1. **Resolve scope** (so you report it accurately and don't double-arm):
   - `MACHINE` = `$INTERAGENT_MACHINE` if set, else the `machine:` line from `/c/dev/.machine-id`.
   - `PROJECT` = `git rev-parse --show-toplevel` basename, else cwd basename.
   - The poll script auto-detects both — you do NOT pass them as args. You resolve
     them only to tell the user what scope is being watched.

2. **Don't double-arm.** List running tasks first. If a monitor whose description is
   `interagent inbox (project=<this project>)` is already running, tell the user it's
   already armed and stop. The poller also takes a pidfile lock
   (`poller-<machine>-<project>.pid`) so a second process on the same seen-file refuses.

3. **Arm the Monitor tool.** Default interval 5s. Use the command from the setup table
   for **your** name. Description: `interagent inbox (project=<PROJECT>)`,
   `persistent: true`.

   Each poll (one SQL round trip) upserts `interagent_watchers`, stamps
   `delivered_to` / `delivered_at` when it emits an inbox line, and may also emit
   sender-visibility lines: `DELIVERED`, `CLAIMED`, `COMPLETED` (first ~200 chars of
   `result`), or `UNDELIVERED … old poller or offline`.

4. **Confirm to the user:** what's being watched (machine + project), the interval,
   and that "stop monitoring" disarms it.

## On each wake event (a line from the poller)

| Line prefix | Action |
|-------------|--------|
| `INTERAGENT new #id` | `inbox` → route → `claim` if yours → act → `complete` / `send` reply |
| `DELIVERED` / `CLAIMED` / `COMPLETED` | surface to the user (sender-side progress); no claim |
| `UNDELIVERED` | surface warning — receiver not acking |

For inbox wakes:

1. **Read once:** `interagent_call > inbox {machine: <MACHINE>}`.
2. **Apply routing** (see README table): project-tagged for this project → claim;
   broadcast → surface only; other project → skip.
3. **Close the loop on the agent side** with `complete {id, result}` or `send`.

## Notes

- Opt-in per session; does not survive session end. NOT a hook (SSH is allowed).
- `INTERAGENT_UNDELIVERED_MIN` (default 5) controls the first undelivered alarm.
- Test without arming: `INTERAGENT_MACHINE=<your name> bash …/interagent-monitor-poll.sh --once`.
- Offline suite: `hooks/testdata/interagent-delivery-ack/run-tests.sh`.
