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

**Put BOTH `INTERAGENT_MACHINE` and `INTERAGENT_PROJECT` in the poller command.**
Do not assume a child process inherits the launcher env, and do not let either be
inferred:

- **Machine** — watching the wrong name drains *another* session's inbox, and
  with delivery stamping it would also write `delivered_to` onto mail that was
  never yours. The poller refuses to stamp a row whose `to_target` is neither its
  machine nor `any`, which bounds the damage; it does not undo the drain.
- **Project** — launched as PowerShell → Git-Bash `-lc`, the **login shell starts
  in `$HOME`**, so an inferred project silently becomes your home directory's
  basename and the poller filters on a project nobody sends to: a blind watch
  that looks perfectly healthy. The poller prints one
  `WARN: interagent project scope inferred as …` line when it can tell, but
  setting the variable is the fix.

| You are | Launch | Your name | Arm polling with |
|---|---|---|---|
| Claude personal | `claude` | `dell-xps` | `/monitor-interagent` → `INTERAGENT_MACHINE=dell-xps INTERAGENT_PROJECT=<project> bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5` |
| Claude work | `claude-work` | `dell-xps-work` | `/monitor-interagent` → `INTERAGENT_MACHINE=dell-xps-work INTERAGENT_PROJECT=<project> bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5` |
| Grok TUI | `grok-agent` | `dell-xps-grok` | `/monitor-interagent` → PowerShell: `$env:INTERAGENT_MACHINE='dell-xps-grok'; $env:INTERAGENT_PROJECT='<project>'; & 'C:\Program Files\Git\bin\bash.exe' -lc '/c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5'` |
| Grok, no TUI | `interagent-dispatch.sh` | `dell-xps-grok` | Do **not** also arm this skill. The two race on claim and both stamp delivery. Each now refuses while the other is live, naming the other's pid and cmdline. The dispatcher is the watcher. |

`<project>` is the git-root basename of the session the mail is routed to — the
same string the sender puts in `context_refs`.

## A poller does not run forever

| Ends it | Roughly | What you see |
|---|---|---|
| Claude Code Monitor cap | ~30 min | the task stops; no more lines |
| Monitor max-runtime | ~10 h | same |
| Session end / `TaskStop` | — | same |
| Its reader going away | next poll or next write | the poller exits on its own |

*(Runtime caps as reported by the Grok implementer this session; not measured
here.)* Nothing restarts a poller automatically — **re-arm it**, and on re-arm
follow stop → verify the pidfile is gone → start. A poller that has stopped looks
exactly like a quiet inbox, which is why `UNDELIVERED … [watcher: stale Ns]` on
the *sender's* side is the real signal that a receiver's watch has died.

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
   (`poller-<machine>-<project>.pid`): a starting poller reaps a pid that is dead
   or that `/proc/<pid>/cmdline` shows is not a poller, and **challenges** a live
   holder with `SIGUSR1` — the holder proves its pipe with a real write and exits
   if that write fails. So an orphan left by an expired Monitor hands the lock
   over instead of locking this session out, while a genuinely live poller keeps
   it and the newcomer refuses with `already running pid=…`. That refusal is the
   correct outcome, not an error to work around.

3. **Arm the Monitor tool.** Default interval 5s. Use the command from the setup table
   for **your** name. Description: `interagent inbox (project=<PROJECT>)`,
   `persistent: true`.

   Each poll (one SQL round trip) upserts `interagent_watchers`, stamps
   `delivered_to` / `delivered_at` for the lines the **previous** poll actually
   wrote to this session, and may also emit sender-visibility lines: `DELIVERED`,
   `CLAIMED`, `COMPLETED` (first ~200 chars of `result`), or
   `UNDELIVERED … old poller or offline [watcher: none|stale Ns|live Ns]`.

   A stamp therefore means "a live session received this line", never "the
   database was asked about it". See
   [README-interagent-push.md](../../hooks/README-interagent-push.md) §iteration 3.

4. **If the first line you see is a WARN.**
   `WARN: interagent schema not migrated — inbox-only mode (no delivery ack)`
   means the poller is running against an un-migrated database. Inbox delivery
   still works; `DELIVERED` / `CLAIMED` / `COMPLETED` / `UNDELIVERED` will not
   appear. Surface it to the user and point at
   `migrations/0001_interagent_delivery_ack.sql`. It is printed once per poller,
   not per poll — do not treat its absence on later polls as "fixed".

5. **Confirm to the user:** what's being watched (machine + project), the interval,
   and that "stop monitoring" disarms it.

## On each wake event (a line from the poller)

| Line prefix | Action |
|-------------|--------|
| `INTERAGENT new #id` | `inbox` → route → `claim` if yours → act → `complete` / `send` reply |
| `DELIVERED` / `CLAIMED` / `COMPLETED` | surface to the user (sender-side progress); no claim |
| `UNDELIVERED` | surface warning — receiver not acking. `[watcher: none]` = it has no poller at all; `[watcher: stale Ns]` = its poller has missed 3+ of its own intervals; `[watcher: live Ns]` = it is polling but not acking, i.e. an **old** poller |
| `WARN: … watch is BLIND` | consecutive polls did not RUN (the SSH hop to deepthought drops roughly every 30 min). Nothing was stamped and nothing was marked seen, so no mail was lost — but nothing is being announced either. Surface it; it clears itself with `INTERAGENT watch recovered` |
| `WARN: … project scope inferred` | the poller is watching a guessed project (probably `$HOME`). Re-arm with `INTERAGENT_PROJECT` set |
| `WARN:` (other) | the schema or the transport is degraded — surface it, do not swallow it |
| `INTERAGENT poller alive` | this poller answered another poller's start-up challenge; informational |

For inbox wakes:

1. **Read once:** `interagent_call > inbox {machine: <MACHINE>}`.
2. **Apply routing** (see README table): project-tagged for this project → claim;
   broadcast → surface only; other project → skip.
3. **Close the loop on the agent side** with `complete {id, result}` or `send`.

## Notes

- Opt-in per session; does not survive session end. NOT a hook (SSH is allowed).
- `INTERAGENT_UNDELIVERED_MIN` (default 5) controls the first undelivered alarm.
- `INTERAGENT_PROBE_SECS` (default 0 = off) enables a periodic real-write pipe
  probe. It costs one blank line per probe in the chat stream, so leave it off
  unless diagnosing a stuck poller.
- Test without arming: `INTERAGENT_MACHINE=<your name> bash …/interagent-monitor-poll.sh --once`.
  `--once` takes the pidfile lock too, so it will refuse while a monitor is
  armed — that is deliberate: two processes sharing one seen-file is the bug
  this lock exists to prevent (`GOTCHAS.md`
  §`expired-monitor-leaves-its-poller-running-and-orphans-steal-inbox-events`).
- Upgrading the poller in a live session: **stop → verify the pidfile is gone →
  start**. See the DEPLOY section of
  [README-interagent-push.md](../../hooks/README-interagent-push.md).
- Offline suite: `hooks/testdata/interagent-delivery-ack/run-tests.sh`.
