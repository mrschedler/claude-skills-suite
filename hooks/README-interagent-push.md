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

## Agent names (who watches which inbox)

Inbox is **agent-keyed**. Launchers set `$INTERAGENT_MACHINE`; the poller and
`inbox {machine}` must use that name. Arm-command copy-paste:
`skills/monitor-interagent/SKILL.md` (setup table). Addressing:
`skills/interagent/SKILL.md`.

| Launch | Name | Idle watcher |
|--------|------|----------------|
| `claude` | `dell-xps` | `/monitor-interagent` with `INTERAGENT_MACHINE=dell-xps` in the poller command |
| `claude-work` | `dell-xps-work` | `/monitor-interagent` with `INTERAGENT_MACHINE=dell-xps-work` in the poller command |
| `grok-agent` | `dell-xps-grok` | `/monitor-interagent` with `INTERAGENT_MACHINE=dell-xps-grok` in the poller command |
| `interagent-dispatch.sh` | `dell-xps-grok` | unattended; do not also arm `/monitor-interagent` |

**Name the poller explicitly even for the personal `claude` session.** An
unnamed command is indistinguishable from any other in a process list, and a
machine-wide kill sweep took out three sessions on 2026-09-21 for exactly that
reason. `INTERAGENT_MACHINE=dell-xps` is redundant to the poller (it is the
`.machine-id` default) and load-bearing to the human reading `ps`.

If you send Grok a task, arm **your** watcher or you will not see the reply
until the next human turn.

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
  command: "INTERAGENT_MACHINE=<name> INTERAGENT_MAX_LIFETIME_S=2100 bash /c/dev/claude-skills-suite/hooks/interagent-monitor-poll.sh 5"
}
```

`interagent-monitor-poll.sh` polls on an interval (default 5s) and emits stdout
lines; each line is a chat event that wakes the session, which then `check`s
interagent over MCP to read + **claim**. Stop it with `TaskStop` (or end the
session). It is **opt-in per session** — a running process, not something every
session carries.

**Why the poller may do what the hook may not:** it is NOT a hook — it is a
Monitor-driven background process — so it is allowed to do network. It reads the
`interagent_assignments` table directly over SSH (`ssh deepthought` → `pgvector`),
the simplest path needing no gateway change. This is the clean home for the
network call the hook is forbidden from making: hook reads local state, poller
bridges gateway → session. Test it without arming via
`bash interagent-monitor-poll.sh --once`.

### The claim IS the acknowledgement

Two earlier builds tried to make the **poller** prove delivery, with a
`delivered_to` / `delivered_at` stamp, a pidfile lock and a liveness challenge.
Both were refuted by adversarial review, the second decisively: on MSYS/Git-Bash
a write into a pipe whose read end is held open but never read **succeeds for
65,536 bytes**, so no local probe — fd test, one-byte write, SIGUSR1 challenge —
can prove a live reader. An orphaned poller therefore stamped a false
`DELIVERED` on mail no session ever saw, and its pidfile refused the live
poller. There is no probe that fixes this, so we stopped looking for one.

The acknowledgement that means something is the receiving **agent's** `claim`.
It already exists in the schema (`status` / `claimed_by` / `claimed_at` /
`completed_at` / `result`), it can only be written by a session that actually
read the message, and it is what the sender cares about. **The poller stamps
nothing and writes nothing at all.** There is no migration, no ack column, no
lock, no challenge — do not reintroduce them.

The rule this puts on receiving agents: **claim promptly, then work.** Mail you
have not claimed is, correctly, still unread: it will be re-announced when the
poller is re-armed, and the sender will be told nobody has picked it up.

### What the poller emits

| Line | Side | Meaning |
|---|---|---|
| `INTERAGENT new #id [tag] from <who>: <title>` | inbox | pending and **unclaimed** mail routed here. Read it, claim it, then work. |
| `CLAIMED #id by <who> after <n> s` | sender | someone took mail this machine sent. |
| `COMPLETED #id: <first 200 chars>` | sender | that work is done; the snippet is the result. |
| `UNCLAIMED #id <title> - 5/15/60 min` | sender | nobody has claimed it: *not watching, busy, or offline*. Broadcast sends are exempt. |
| `INTERAGENT WARN: poll failed (Nx) - <reason>` | both | the ssh/psql hop is down. **This is not an empty inbox** — nothing was marked seen and no alarm state advanced. Said on the first failure, then at most every 600s. |
| `INTERAGENT recovered: ...` | both | the hop came back. |
| `INTERAGENT poller lifetime reached (Ns) - re-arm` | both | see `INTERAGENT_MAX_LIFETIME_S`. |

### No shared state, so orphans are harmless

All dedupe state lives in a **per-process** directory keyed by the poller's own
pid (`%LOCALAPPDATA%/claude-interagent/proc-<machine>-<project>-<pid>/`), removed
on exit; dirs older than a day are swept at start. Two pollers never share state,
so an orphan steals nothing — whatever it "saw" is invisible to the live poller,
which announces it again.

**A freshly armed poller re-announcing still-unclaimed mail is intended.** A
message the agent never claimed *should* come back. The one exception is untagged
broadcasts (`to_target = 'any'` with no project ref), which agents deliberately
never claim: those are announced only while younger than
`INTERAGENT_BROADCAST_HOURS` (24), so old broadcasts do not replay on every
re-arm. `CLAIMED` / `COMPLETED` are seeded silent at startup against the
**database** clock, so a re-arm does not replay yesterday's traffic; the
`UNCLAIMED` alarms do re-fire, once, at the highest threshold the message has
already passed, and then at each new one.

An orphan is additionally self-terminating: a per-poll `kill -0 $PPID` (the
parent's identity pinned by its cmdline against MSYS pid reuse), plus
`INTERAGENT_MAX_LIFETIME_S`. Neither is load-bearing — correctness comes from
the state being private.

### Environment

| Variable | Default | Why |
|---|---|---|
| `INTERAGENT_MACHINE` | `machine:` from `/c/dev/.machine-id` | inbox name. Must match `^[A-Za-z0-9._-]+$` or the poller refuses to start (rc 2). |
| `INTERAGENT_PROJECT` | git-root / cwd basename | project tag. Same identifier rule. |
| `INTERAGENT_MAX_LIFETIME_S` | `0` (unlimited) | **2100 for Claude Code**: the Monitor tool caps at 30 min and leaves its poller running. At expiry the poller prints one line and exits 0. |
| `INTERAGENT_SENT_HOURS` | `72` | sender-side window. |
| `INTERAGENT_UNCLAIMED_MINS` | `5,15,60` | alarm thresholds. |
| `INTERAGENT_BROADCAST_HOURS` | `24` | untagged-broadcast announce window. |
| `INTERAGENT_ERR_QUIET_S` | `600` | minimum gap between hop-failure warnings (the first is always said). |

The SQL travels on psql's **stdin**, so no remote shell ever expands a machine or
project name; the identifier check above is the second line of that defence. All
time comparisons use the database's `now()`, never a local clock — machines in
this fleet do not agree with each other.

### DEPLOY

There is **no migration**: this build reads columns that already exist and writes
nothing. Deployment is the code only.

1. Land the code on `main`; Syncthing propagates `C:\dev\claude-skills-suite` to
   each machine.
2. A live session picks it up **on the next arm**, not in flight — the running
   poller is the old script already loaded by bash. In each session that wants
   the new behaviour: `/monitor-interagent stop`, then `monitor interagent`.
3. **Old and new pollers coexist safely.** Both run a read-only query, neither
   writes to the database, and their state files do not collide (old:
   `seen-<machine>-<project>.txt`; new: a `proc-…-<pid>/` directory). A session
   left on the old poller simply gets no sender-side lines. Stale `seen-*.txt`
   files from the old build are inert and can be deleted at leisure.
4. **Rollback** is reverting the code. There is nothing else to undo.

### Tests

`bash hooks/testdata/interagent-delivery-ack/run-tests.sh` — 11 arms and 6
mutants, fully offline against a fake DB (no ssh, no live pgvector, no
migration). The round-2 killer repro — an unread-holder orphan running alongside
a live poller — is a permanent arm.

## Human notification (separate layer, not agent-to-agent)

`PushNotification` (desktop/phone) pings **Matt**, not an agent. Optionally use it
so a finishing session can tell Matt "done" — but it is not part of the
agent-to-agent path.

## Files

| File | Role |
|------|------|
| `hooks/interagent-inbox-nudge.sh` | the `UserPromptSubmit` nudge (iteration 1, push-on-activity) |
| `hooks/interagent-monitor-poll.sh` | the `monitor interagent` poll loop (iteration 2, idle reaction); run by the `Monitor` tool, NOT wired as a hook |
| `hooks/interagent-monitor-process.js` | turns one poll payload into stdout lines; owns the per-process dedupe/seeding/alarm state |
| `hooks/testdata/interagent-delivery-ack/` | the offline suite — `run-tests.sh`, `fake-psql.sh`, `fake-db.js`. No network, no live DB |
| `config/code/settings.json` → `hooks.UserPromptSubmit` | wires the nudge hook |
| `config/code/behavioral-reminders.bp.txt` Step 5 | session-start check + routing rules + command vocabulary |
| this file | design + convention + commands + roadmap |

## Roadmap / open questions

1. ~~**Idle reaction** — Monitor poller~~ ✅ done (iteration 2: `interagent-monitor-poll.sh` + `monitor interagent`).
2. **Per-session addressing upstream** — if project-tag routing proves too coarse,
   decide whether session-level addressing should become a first-class
   `interagent` feature (that work lands in **mcp-gateway**, not here).
3. **Throttle vs latency** — 120s is a guess; tune against real use.
4. **Claim races** — two sibling sessions briefly racing on an untagged broadcast;
   acceptable for now (we don't claim broadcasts), revisit if it bites.
