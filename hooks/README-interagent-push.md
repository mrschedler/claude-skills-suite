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

## Human notification (separate layer, not agent-to-agent)

`PushNotification` (desktop/phone) pings **Matt**, not an agent. Optionally use it
so a finishing session can tell Matt "done" — but it is not part of the
agent-to-agent path.

## Files

| File | Role |
|------|------|
| `hooks/interagent-inbox-nudge.sh` | the `UserPromptSubmit` nudge (iteration 1, push-on-activity) |
| `hooks/interagent-monitor-poll.sh` | the `monitor interagent` poll loop (iteration 2, idle reaction); run by the `Monitor` tool, NOT wired as a hook |
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
