# GOTCHAS — claude-skills-suite

Traps that cost real time. Newest first. Each entry names what it supersedes.

## interagent-poller-seen-state-is-per-session: two sessions under one name no longer steal each other's wake events

**Supersedes** the "orphans share one seen-file with the live monitor" wording in
`QL-G3-Enterprise/GOTCHAS.md` (`expired-monitor-leaves-its-poller-running-and-orphans-steal-inbox-events`)
and the workaround in Qdrant `d585a370` / `9b1ee6ef` (a private `LOCALAPPDATA` or a
made-up `INTERAGENT_MACHINE` name per helper session). Neither is needed any more.

**Symptom (before the fix):** a director and its supervised helper, both `dell-xps` in
`memory-system`, each armed `/monitor-interagent`. The director posted todo #636 to `any`.
The director's poller announced it and the helper's never did, so Matt relayed it by
hand (2026-09-25, reported in #637).

**Cause:** `hooks/interagent-monitor-poll.sh` keyed its seen-file on machine+project
only (`%LOCALAPPDATA%/claude-interagent/seen-<machine>-<project>.txt`). Whichever poller
ran first recorded the id, and every other poller for the same name and project then
treated it as already seen.

**Now:** the seen-file is `%LOCALAPPDATA%/claude-interagent/seen/<machine>-<project>-<sessionkey>.txt`.

- The key is `$INTERAGENT_SESSION`, else `$CLAUDE_CODE_SESSION_ID`, else `ppid-<pid>-<start tick>`.
  Claude Code exports `CLAUDE_CODE_SESSION_ID` to Monitor commands (checked 2026-09-25), so
  Claude sessions need nothing extra and the key survives the 30-minute Monitor re-arm.
- Every session whose routing matches gets its own event. Claiming stays in the agent.
- Mail sent under the session's own name is emitted with a `[self]` marker, not suppressed.
  Ignore it only if this session posted it; a same-name sibling may be the real addressee.
- A failed SSH/psql query emits `INTERAGENT poller ERROR: <reason>`, at most once per
  10 minutes, instead of silence. A quiet watch with no ERROR line now means the query
  is succeeding and nothing new is routed here.
- `--status` shows the key and the file in use.

**Still true:**

- In-process teammates share their lead's `CLAUDE_CODE_SESSION_ID`. A teammate that arms
  its own monitor must set `INTERAGENT_SESSION=<unique>` or it shares the lead's file.
- Orphan pollers of the SAME session still share its file. The parent-pid orphan guard
  (commit 462fa32) is what keeps them from eating events, and the rule to sweep only your
  own `INTERAGENT_MACHINE=<name>` (Qdrant `31695acf`) still applies to any manual sweep.
- A `--once` run from the same Claude session uses the same file as its armed monitor and
  consumes its events. Add `INTERAGENT_SESSION=test-<x>` for a throwaway check.
- An expired Monitor leaves NO poller. Nothing announces that; re-arm on the expiry notice.
- Results written with `interagent_call > complete {result}` are still invisible to the
  poller (Qdrant `5b46cfae`). Reply with a new `send`.

**Evidence:** `tests/interagent-monitor-poll.test.sh` (two session keys against one stubbed
row set both emit the same ids; re-runs emit nothing; `[self]` tagging; error rate limit).
Live `--once` as `dell-xps` in `memory-system` on 2026-09-25 emitted exactly the gateway
inbox rows not tagged for another project.
