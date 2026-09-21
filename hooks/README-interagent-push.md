# Interagent PUSH — agent-to-agent message surfacing

**Status:** research WIP / iteration 1. Built for interagent assignment #115
(2026-05-25). Expect this to evolve; see the roadmap at the bottom.

## The problem

`interagent` (gateway module: `send` / `inbox` / `claim` / `complete`) is a
durable mailbox, but it is **pull-only** and **keyed by machine**, not by session.
So two Claude Code sessions running on `dell-xps` share one inbox, and neither
notices new mail until a human says *"go check interagent."* That manual relay is
the entire pain point.

## What we built (iteration 1 — push-on-activity)

A surfacing layer that makes the **receiver** drain its own inbox automatically:

- **`interagent-inbox-nudge.sh`** — a `UserPromptSubmit` hook. On each turn (rate
  limited to once / 120s per project) it injects a reminder telling the agent to
  call `interagent_call > inbox` and claim the messages that belong to it. For an
  actively-working session, new mail surfaces on the next turn with no human relay.
- Session-start coverage is handled by **Step 5 of `behavioral-reminders.bp.txt`**
  (already injected at `SessionStart`), so the hook only needs to cover *later*
  turns — the actual gap.

### Why a nudge and not a fetch

Hooks in this suite are **local-only** — no SSH / MCP / HTTP (see `CLAUDE.md`;
butterfly-wings blast radius). A shell `command` hook also literally cannot invoke
an MCP tool: `interagent_call` lives in the agent, not the CLI. So the hook does
not fetch the inbox — it emits an action-reminder (the same pattern as
`session-end-summary.sh`'s `action=...` lines) and the **agent** makes the MCP
call. Network stays on the agent side; the hook stays local, fast, and fail-open
(a slow/down gateway never blocks the user's turn).

## Routing convention (machine inbox → per session)

Because the inbox is machine-keyed, a message must say which session it is for.
We do that with a **project tag in `context_refs`**:

```jsonc
// SENDER — route a message to the session working in project "QL-G3-Enterprise"
interagent_call > send {
  to: "dell-xps",                       // target MACHINE
  from: "dell-xps",                      // your machine (.machine-id)
  title: "G3 broker: rerun the loopback test with the new firmware",
  prompt: "<full context the receiving session needs>",
  context_refs: [
    { type: "project", id: "QL-G3-Enterprise", label: "route: G3 session" }
  ]
}
```

The project key is the **git-root basename** of the receiving session (else its
cwd basename) — e.g. `QL-G3-Enterprise`, `claude-skills-suite`. The sender must
use the same string the receiver derives.

**Receiver rules** (enforced by the nudge text + protocol Step 5):

| Message `context_refs` | Action |
|------------------------|--------|
| `{type:"project", id:<my project>}` | surface **and** claim |
| addressed to this specific session | surface **and** claim |
| no project tag / broadcast | surface, **do not** claim (leave for siblings) |
| `{type:"project", id:<other project>}` | **skip** — another session owns it |

> **Same-folder caveat:** if you ever run *two* sessions in the *same* project
> folder, the project tag can't tell them apart. Add a finer
> `{type:"session", id:<session_id>}` ref (the `session_id` is what
> `coordination_call > register_session` records) to disambiguate.

## Command vocabulary (what Matt says → what happens)

| Matt says | Action | Mechanism |
|-----------|--------|-----------|
| **interagent** | (noun) the mailbox | — |
| **check interagent** | look once, now: `interagent_call > inbox`, apply the routing rules above, surface/claim | one-time MCP pull |
| **monitor interagent** | arm the persistent poller so this session reacts to new mail **while idle**, until stopped | `Monitor` tool + `interagent-monitor-poll.sh` |
| **stop monitoring** | disarm the poller | `TaskStop` on the monitor |

*check = a single look; monitor = repeating, reacts between turns.* The
`UserPromptSubmit` nudge is automatic plumbing — Matt never invokes it by name.

## Iteration 2 — idle reaction via Monitor (`monitor interagent`)

The nudge only fires when the session **takes a turn**, so an idle session won't
react until the next prompt. `monitor interagent` closes that gap. On that command
the agent arms the `Monitor` tool with the poller:

```
Monitor {
  description: "interagent inbox (project=<this project>)",
  persistent: true,
  command: "bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 30"
}
```

`interagent-monitor-poll.sh` polls every 30s and emits one stdout line per NEW
pending message routed to this session; each line is a chat event that wakes the
session, which then `check`s interagent over MCP to read + claim. Stop it with
`TaskStop` (or end the session). It is **opt-in per session** — a running process,
not something every session carries.

**Why the poller may do what the hook may not:** it is NOT a hook — it is a
Monitor-driven background process — so it is allowed to do network. It reads the
`interagent_assignments` table directly over SSH (`ssh deepthought` → `pgvector`),
the simplest path needing no gateway change. This is the clean home for the
network call the hook is forbidden from making: hook reads local state, poller
bridges gateway → session. Project routing + new-vs-seen dedup are done in the
poller (a non-synced seen-file per machine+project); test it without arming via
`bash interagent-monitor-poll.sh --once`.

## Iteration 3 — delivery ack + sender visibility

Pickup is not the same as claim. When a live poller **emits** an inbox line it
stamps nullable `delivered_to` / `delivered_at` (never touches `claimed_by` /
`status`). The same poll also watches rows **this machine sent** and emits:

| Line | Meaning |
|------|---------|
| `DELIVERED #id to <machine> at T` | receiver poller acked pickup |
| `CLAIMED #id by <machine>` | receiver claimed |
| `COMPLETED #id by <machine>: <~200 chars of result>` | `complete {result}` is visible to the sender |
| `UNDELIVERED #id to <target> for >M min — receiver not acking (old poller or offline)` | no stamp after `INTERAGENT_UNDELIVERED_MIN` (default 5); repeats sparsely at 5 / 15 / 60 min via seen-file keys `ALARM-5-<id>` etc. |

Each poll is **one SQL round trip** (CTE): upsert the `interagent_watchers`
heartbeat, stamp the ids the *previous* poll delivered, return inbox pending ∪
changed sent rows ∪ the watcher rows of this machine's sent targets.

### A stamp means "a live session received this line"

This is the whole design, and it is the opposite of the obvious implementation.
The stamp is **not** in the statement that returns the inbox — that would ack a
message the moment the database was asked about it, including for an orphan
poller writing into a closed Monitor pipe. `interagent-monitor-process.js`
appends an id to an **ack-file** only after `fs.writeSync(1, …)` returned without
throwing; the **next** poll's CTE stamps exactly those ids. Cost is unchanged
(the ids ride along in the same round trip), and the meaning changes completely:

- a poller whose reader is gone fails the write, so the id enters neither the
  seen-file nor the ack-file — the message stays pending for the live session,
  and the sender's `UNDELIVERED` alarm stays armed;
- if a poller dies between the write and the next poll, the id is still in the
  ack-file and the next poller stamps it — late, but true.

### No orphans

The pidfile `%LOCALAPPDATA%/claude-interagent/poller-<machine>-<project>.pid` is
created with `set -o noclobber` (atomic `O_EXCL`) and holds `<pid> <token>`. A
starting poller:

- **reaps** a pid that is dead, or whose `/proc/<pid>/cmdline` is not this script
  — MSYS pids are small and recycle fast, so `kill -0` alone cannot tell a poller
  from any other Git-Bash process — and logs one line when it does;
- **challenges** a genuine live holder with `SIGUSR1`. The holder proves its pipe
  with a *real* write and exits if that write fails. So an orphan hands the lock
  over, and a live session is never left with zero pollers; a genuinely live
  poller keeps it and the newcomer refuses, so two pollers never share one
  seen-file.

`--once` takes the lock too (sharing the seen-file with a running loop is the
original incident, `GOTCHAS.md` §`expired-monitor-leaves-its-poller-running…`).

### Reader-gone detection on Git-Bash/Windows — measured, not assumed

| probe | result with the reader gone | usable? |
|---|---|---|
| `[ -e /proc/self/fd/1 ]` | **TRUE** | no |
| `readlink /proc/self/fd/1` | reports `pipe:[…]` even for a plain file | no |
| `printf '' >&1` (zero-byte write) | **succeeds** — a 0-length write to a broken pipe returns 0, no `EPIPE`, no `SIGPIPE` | no |
| `kill -0 $PPID` | `$PPID` becomes `1` on orphaning and `kill -0 1` fails | **yes**, when armable |
| a real 1-byte write | fails | **yes**, but costs a byte of Monitor output |

So the poller runs the `$PPID` check every poll whenever it can be armed (the
parent was a real live pid at startup; its identity is pinned by its cmdline
against pid reuse), and uses the real-write probe **on demand** — when challenged
by a starting poller, and on a timer only if `INTERAGENT_PROBE_SECS > 0`
(default `0`, off, because it writes into the session's chat stream).
Correctness never depends on either probe; the ack-file gate above is what makes
an undetected orphan harmless. These facts are asserted by the `probe` arm of the
suite, so a platform change breaks a test rather than the feature.

### Scope: both names are explicit, and a guessed one is called out

`INTERAGENT_MACHINE` and `INTERAGENT_PROJECT` belong in the **arm command**
(see the table in `skills/monitor-interagent/SKILL.md`), because both failure
modes are silent:

- **Wrong machine** — the poller drains another profile's inbox
  (`dell-xps` / `dell-xps-work` / `dell-xps-grok` are three different mailboxes).
  Delivery stamping would make that worse, so the stamp CTE re-checks routing:
  `AND (a.to_target = p.machine OR a.to_target = 'any')`. A poller can never
  write "delivered to me" onto mail addressed elsewhere, even with a stale
  ack-file left behind by a renamed profile. It still *drains* — the guard bounds
  the damage, it does not remove the need to set the name.
- **Guessed project** — under PowerShell → Git-Bash `-lc` the *login* shell
  starts in `$HOME`, so an inferred project becomes the home directory's basename
  and the poller filters on a project nobody sends to, while looking completely
  healthy. When the inferred value comes from `$HOME` or `/`, the poller says so
  once — on stderr **and** stdout, because stderr alone is invisible in a
  Monitor, which is the lesson of the silent-blackout bug above.

### A poll that did not run is not an empty inbox

The SSH hop to deepthought drops roughly every half hour. Treating that as "no
mail" is how a watch goes quietly blind, so every reply carries a sentinel: a
successful poll returns a JSON envelope containing `"schema"`, and an empty inbox
still returns one (`…,"rows":[]`). Anything else — non-zero exit, no output, a
truncated reply — is a **failed** poll, and `poll_once` returns before anything
durable is touched: nothing stamped, the ack-file not drained, the `since`
high-water not advanced, the seen-file not appended to, no alarm or `COMPLETED`
dedupe advanced. The schema probe likewise stays `unknown` rather than latching a
guess made from a query that never ran.

Consecutive failures are counted; after `INTERAGENT_BLIND_AFTER` (default 3) the
session gets **one** line —
`WARN: interagent watch is BLIND — N consecutive failed polls` — and one
`INTERAGENT watch recovered` when it clears.

> This required fixing `run_sql`. Called as `json=$(run_sql …)` the whole
> function runs in a subshell, so its `SQL_RC` / `SQL_ERR` assignments were
> discarded and the caller saw exit 0 with an empty error for every dropped hop.
> It now writes to a file and the caller reads `$SQL_OUT`.

### Two live watchers for one machine

Grok's unattended `config/grok/interagent-dispatch.sh` and an interactive
`interagent-monitor-poll.sh` are both real watchers of the same machine inbox,
and they keep **separate state directories** — so neither pidfile sees the other,
while they race to claim the same mail and both stamp it. Each now refuses while
the other is live, naming the other's pid and cmdline and how to stop it. A dead
or recycled pid in either pidfile is ignored, so a stale file cannot lock a
machine out of watching its own inbox.

### Nothing restarts a poller

A poller ends when its Monitor task hits the Claude Code cap (~30 min) or the
Monitor max-runtime (~10 h), when the session ends, or when its reader goes away.
*(Those two caps are as reported by the Grok implementer this session; not
measured here.)* Nothing re-arms it automatically, and a stopped poller looks
exactly like a quiet inbox from the inside. The signal that a receiver's watch
has died is on the **sender's** side: `UNDELIVERED … [watcher: stale Ns]`.

### Schema mismatch is loud

The poller probes for `delivered_to` / `interagent_watchers` once at startup (and
detects the error if the columns vanish under it). On an un-migrated database it
prints exactly one line **on stdout**, where the session can see it —
`WARN: interagent schema not migrated — inbox-only mode (no delivery ack)` — and
falls back to the pre-change inbox query. It never returns silence.

Migration: `migrations/0001_interagent_delivery_ack.sql` (+ rollback). Old
pollers keep working across it (nullable columns, no renames). Offline tests:
`hooks/testdata/interagent-delivery-ack/run-tests.sh` — 17 arms and 7 mutants,
no network, no live database.

## DEPLOY

**Order: migration first, then code.** Both directions are safe, but only this
order has no degraded window.

1. **Apply the migration.**

   ```bash
   ssh deepthought 'docker exec -i pgvector psql -U postgres homelab -v ON_ERROR_STOP=1 -f -' \
     < migrations/0001_interagent_delivery_ack.sql
   ```

   It is additive, idempotent and old-poller-safe: nullable columns with no
   default (catalog-only `ALTER`, no table rewrite), `CREATE TABLE IF NOT
   EXISTS`, three `CREATE INDEX IF NOT EXISTS`. **Every currently running old
   poller keeps working unchanged across it** — there is no window in which
   anything is broken.

2. **Verify**, before touching any code:

   ```bash
   ssh deepthought "docker exec pgvector psql -U postgres homelab -At -c \
     \"SELECT column_name FROM information_schema.columns \
       WHERE table_name='interagent_assignments' AND column_name LIKE 'delivered%';\""
   # expect: delivered_to, delivered_at
   ```

   Then confirm a live old poller still announces a test message normally.

3. **Land the code** on `main` and let Syncthing propagate.

4. **Pick the new poller up in each live session — stop, verify, start.**

   ```
   /monitor-interagent stop
   ```

   then confirm the pidfile is gone:

   ```bash
   ls "$LOCALAPPDATA/claude-interagent/poller-<machine>-<project>.pid"   # must not exist
   ```

   If it is still there, the previous poller did not run its EXIT trap. Check
   `tr '\0' ' ' < /proc/<pid>/cmdline`, kill it, delete the file. Then:

   ```
   monitor interagent
   ```

   With the new code a second start would challenge the old one and win anyway,
   but the old (pre-fix) poller cannot answer a challenge — it has no `SIGUSR1`
   handler — so during this one changeover the manual sequence is mandatory, not
   advisory. After this deploy it becomes advisory.

**What old pollers see.** Nothing changes for them: they never select the new
columns, never write the watcher table, and never look at an ack-file. They keep
delivering exactly as before. They simply never stamp, so a *new* sender polling
alongside them will report `UNDELIVERED … [watcher: none]` for mail they did in
fact deliver — which is the correct reading of "the receiver is not acking (old
poller or offline)", and resolves itself as sessions are restarted.

**Rollback — code first, then schema.** Revert the code on `main`, restart the
monitors, and only then run
`migrations/0001_interagent_delivery_ack_rollback.sql`. A new poller left running
against a rolled-back schema does not go silent (it falls back to inbox-only with
the one WARN line), but reverting the code first means nobody ever sees that
state.

## Human notification (separate layer, not agent-to-agent)

`PushNotification` (desktop/phone) pings **Matt**, not an agent. Optionally use it
so a finishing session can tell Matt "done" — but it is not part of the
agent-to-agent path.

## Files

| File | Role |
|------|------|
| `hooks/interagent-inbox-nudge.sh` | the `UserPromptSubmit` nudge (iteration 1, push-on-activity) |
| `hooks/interagent-monitor-poll.sh` | the `monitor interagent` poll loop (idle reaction + delivery ack); run by the `Monitor` tool, NOT wired as a hook |
| `hooks/interagent-monitor-process.js` | formats inbox/sender/alarm lines; owns the seen-file and ack-file **write-gated** appends |
| `hooks/testdata/interagent-delivery-ack/` | offline suite: 17 arms + 7 mutants, fake DB, no network |
| `migrations/0001_interagent_delivery_ack.sql` | additive `delivered_*` + `interagent_watchers` + indexes (see DEPLOY) |
| `config/grok/interagent-dispatch.sh` | Grok's unattended dispatcher; stamps delivery before each worker launch |
| `config/code/settings.json` → `hooks.UserPromptSubmit` | wires the nudge hook |
| `config/code/behavioral-reminders.bp.txt` Step 5 | session-start check + routing rules + command vocabulary |
| this file | design + convention + commands + roadmap |

## Roadmap / open questions

1. ~~**Idle reaction** — Monitor poller~~ ✅ done (iteration 2: `interagent-monitor-poll.sh` + `monitor interagent`).
2. ~~**Delivery ack + sender visibility**~~ ✅ done (iteration 3; migration pending live apply).
3. **Per-session addressing upstream** — if project-tag routing proves too coarse,
   decide whether session-level addressing should become a first-class
   `interagent` feature (that work lands in **mcp-gateway**, not here).
4. **Throttle vs latency** — 120s is a guess; tune against real use.
5. **Claim races** — two sibling sessions briefly racing on an untagged broadcast;
   acceptable for now (we don't claim broadcasts), revisit if it bites.
