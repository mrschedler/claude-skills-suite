#!/usr/bin/env bash
# interagent-monitor-poll.sh — poll loop behind the `monitor interagent` command.
#
# WHAT ─────────────────────────────────────────────────────────────────────────
# Emits ONE stdout line per NEW pending interagent message routed to THIS session,
# then sleeps INTERVAL seconds and repeats. Run by the agent's Monitor tool with
# persistent:true — each emitted line becomes a chat event that wakes an otherwise
# idle session. On wake the agent drains/claims the message via
# interagent_call > inbox (MCP). This poller is the TRIGGER, not the worker.
# stdout is the event channel: nothing but event lines may ever go there.
#
# WHY NOT A HOOK ────────────────────────────────────────────────────────────────
# Hooks in this suite are local-only and cannot reach the gateway (and a shell
# hook can't call an MCP tool anyway). This is NOT a hook — it's a Monitor-driven
# background process, so it MAY do network. It reads the interagent_assignments
# table directly over SSH (ssh deepthought -> pgvector container), the simplest
# path that needs no gateway change. (interagent data lives in the homelab PG DB.)
#
# ROUTING (machine inbox -> per session) ─────────────────────────────────────────
# Emits messages with status=pending, not archived, to_target in (this machine,
# 'any'), not past TTL, that are tagged {type:"project", id:<this project>} OR
# carry NO project tag (broadcast). Messages tagged for ANOTHER project are skipped
# so they remain for that project's session. Same row set as the gateway's
# `interagent_call > inbox` (which also excludes archived rows). A message whose
# from_agent is this session's own name gets a `[self]` marker: it is emitted,
# never suppressed, because another session running under the same name may be
# its real addressee. Claiming is the agent's job, never the poller's.
#
# SEEN STATE IS PER SESSION ──────────────────────────────────────────────────────
# "New" = id not previously emitted BY THIS SESSION. The seen-file used to be keyed
# on machine+project only (seen-<machine>-<project>.txt), so two sessions under the
# same name in the same project (a director and its helper, both dell-xps in
# memory-system) shared it: whichever poller ran first recorded the id and the
# other session never woke (lived 2026-09-25, #636). The file is now
#   <state>/seen/<machine>-<project>-<sessionkey>.txt
# and the session key is, in order of preference:
#   1. $INTERAGENT_SESSION                 explicit override (tests, helpers,
#                                          in-process teammates sharing one id)
#   2. $CLAUDE_CODE_SESSION_ID             set by Claude Code in every child shell
#                                          (also $CLAUDE_SESSION_ID, if present);
#                                          stable across Monitor re-arms
#   3. ppid-<pid>-<start>                  the watched parent (see ORPHAN GUARD)
#                                          plus its start tick; unique per ARM, so
#                                          each re-arm re-emits pending mail once
# A new session's file is seeded ONCE from the legacy machine+project file if that
# exists (one-release migration, so upgrading does not re-announce the backlog).
# Per-session files untouched for 7 days are pruned at startup; a live loop
# touches its own file hourly so it is never pruned out from under itself.
#
# ORPHAN GUARD ───────────────────────────────────────────────────────────────────
# The Monitor tool launches this script from a wrapper shell. When the monitor
# expires (~30 min) that wrapper is killed, but this loop used to survive it —
# and an orphaned poller keeps CLAIMING new interagent mail into its seen-file,
# so the live monitor never emits it. Lived 2026-09-21/22: ~40 orphan pollers had
# piled up at the 30-min monitor cadence, all eating events. The loop now watches
# a parent pid and exits silently once it is gone (see PARENT below). Orphans of
# the SAME session still share its seen-file, so this guard still matters.
#
# ROBUSTNESS ─────────────────────────────────────────────────────────────────────
# A failed SSH/psql query never kills the monitor, but it is no longer silent:
# it emits ONE line `INTERAGENT poller ERROR: <reason>`, at most once per 10
# minutes per session (stamp file next to the seen-file). `--once` ignores the
# rate limit because it is a diagnostic. BatchMode + ConnectTimeout mean a dead
# link fails fast instead of hanging. Poll interval defaults to 5s (a single SSH
# round-trip is ~0.3s, so the DB cost is negligible).
#
# USAGE ──────────────────────────────────────────────────────────────────────────
#   bash interagent-monitor-poll.sh          # loop forever, 5s interval
#   bash interagent-monitor-poll.sh 30       # loop forever, 30s interval
#   bash interagent-monitor-poll.sh --once   # single pass (for testing)
#   bash interagent-monitor-poll.sh --status # seen-file in use + id counts; no poll
#
# TEST HOOKS (tests/interagent-monitor-poll.test.sh) ─────────────────────────────
#   INTERAGENT_POLL_STUB=<file>   read the query's JSON from <file> instead of SSH
#                                 (missing file = simulated query failure)
#   INTERAGENT_ERR_INTERVAL=<s>   error-line rate limit, default 600

set -uo pipefail

ARG="${1:-}"
ONCE=0
STATUS=0
INTERVAL=5
case "$ARG" in
  --once)        ONCE=1 ;;
  --status)      STATUS=1 ;;
  ''|*[!0-9]*)   : ;;                 # empty or non-numeric -> keep default
  *)             INTERVAL="$ARG" ;;
esac

# Parent to watch, for the orphan guard described above.
#
# MSYS nuance: this script's WINDOWS parent is a short-lived spawn stub that dies
# immediately (which is why "parent dead" alone is not a usable orphan test from
# PowerShell). Inside MSYS, $PPID is the real launching shell. Walk up the MSYS
# ancestry via /proc/<pid>/ppid and keep the OUTERMOST ancestor that still carries
# this script in its command line — that is the wrapper the monitor owns, so it is
# the one whose death means "the monitor is gone". Git Bash provides both
# /proc/<pid>/ppid and /proc/<pid>/cmdline; if either is missing we fall back to
# the immediate $PPID, which is still the launching shell and still correct for a
# monitor launch — just less precise when the monitor nests extra shells.
SELF_NAME=$(basename "$0")
PARENT=$PPID
if [[ -r "/proc/$PPID/ppid" ]]; then
  probe=$PPID
  for _ in 1 2 3 4 5 6; do
    [[ -r "/proc/$probe/cmdline" ]] || break
    # CONTIGUOUS run only: climb while each ancestor still names this script, and
    # stop at the first one that does not. Climbing past that gap is what makes
    # this fragile — any unrelated outer shell whose command line merely MENTIONS
    # the script (a harness, an editor, another agent's launcher) would be adopted
    # as the parent, and since it outlives the monitor the guard would never fire.
    # Erring inward is safe (we exit a little early at worst); erring outward
    # silently restores the orphan bug, so the loop breaks rather than continues.
    tr '\0' ' ' < "/proc/$probe/cmdline" 2>/dev/null | grep -qF "$SELF_NAME" || break
    PARENT=$probe
    next=$(cat "/proc/$probe/ppid" 2>/dev/null)
    [[ "$next" =~ ^[0-9]+$ ]] || break
    (( next > 1 )) || break            # re-parented to init: top of the MSYS tree
    probe=$next
  done
fi
# If the parent is already gone or unknowable at start, disable the guard rather
# than exiting instantly — a detached/manual launch must still run.
kill -0 "$PARENT" 2>/dev/null || PARENT=""

# Cheap: one kill(2) probe per iteration, no fork.
parent_alive() { [[ -z "$PARENT" ]] || kill -0 "$PARENT" 2>/dev/null; }

# INTERAGENT_MACHINE override (set by per-profile launchers such as claude-work),
# else the non-synced .machine-id.
MACHINE="${INTERAGENT_MACHINE:-}"
[[ -z "$MACHINE" ]] && MACHINE=$(sed -n 's/^machine:[[:space:]]*//p' /c/dev/.machine-id 2>/dev/null | head -1)
MACHINE="${MACHINE:-unknown}"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$GIT_ROOT" ]]; then PROJECT=$(basename "$GIT_ROOT"); else PROJECT=$(basename "$(pwd)"); fi

# Session key (see SEEN STATE IS PER SESSION). Start tick = field 22 of
# /proc/<pid>/stat, which disambiguates a recycled pid.
start_tick() { awk '{print $22}' "/proc/$1/stat" 2>/dev/null; }
SESSION_SRC=INTERAGENT_SESSION
SESSION_KEY="${INTERAGENT_SESSION:-}"
if [[ -z "$SESSION_KEY" && -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
  SESSION_KEY="$CLAUDE_CODE_SESSION_ID"; SESSION_SRC=CLAUDE_CODE_SESSION_ID
fi
if [[ -z "$SESSION_KEY" && -n "${CLAUDE_SESSION_ID:-}" ]]; then
  SESSION_KEY="$CLAUDE_SESSION_ID"; SESSION_SRC=CLAUDE_SESSION_ID
fi
if [[ -z "$SESSION_KEY" ]]; then
  anchor="${PARENT:-$$}"
  SESSION_KEY="ppid-${anchor}-$(start_tick "$anchor")"; SESSION_SRC=ppid
fi
SESSION_KEY=$(printf '%s' "$SESSION_KEY" | tr -c 'A-Za-z0-9._-' '_')

STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
SEEN_DIR="$STATE_DIR/seen"
LEGACY_SEEN="$STATE_DIR/seen-${MACHINE}-${PROJECT}.txt"
SEEN="$SEEN_DIR/${MACHINE}-${PROJECT}-${SESSION_KEY}.txt"
ERR_STAMP="${SEEN%.txt}.err"
ERR_INTERVAL="${INTERAGENT_ERR_INTERVAL:-600}"

count_ids() { local n; n=$(grep -c . "$1" 2>/dev/null); echo "${n:-0}"; }

if [[ "$STATUS" -eq 1 ]]; then
  # Read-only: no migration, no prune, no poll. Under the ppid fallback the key
  # is per invocation, so --status from another shell cannot name a monitor's file.
  echo "machine=$MACHINE project=$PROJECT"
  echo "session_key=$SESSION_KEY (source: $SESSION_SRC)"
  if [[ -f "$SEEN" ]]; then echo "seen_file=$SEEN ids=$(count_ids "$SEEN")"
  else echo "seen_file=$SEEN (not created yet; first poll seeds it)"; fi
  if [[ -f "$LEGACY_SEEN" ]]; then
    echo "legacy_file=$LEGACY_SEEN ids=$(count_ids "$LEGACY_SEEN") (seeds new sessions once; no longer written)"
  fi
  echo "other sessions for ${MACHINE}-${PROJECT}:"
  found=0
  for f in "$SEEN_DIR/${MACHINE}-${PROJECT}-"*.txt; do
    # The name prefix also matches a project whose name extends this one; fine
    # for a diagnostic listing.
    [[ -f "$f" && "$f" != "$SEEN" ]] || continue
    echo "  $(basename "$f") ids=$(count_ids "$f")"; found=1
  done
  [[ "$found" -eq 1 ]] || echo "  (none)"
  exit 0
fi

mkdir -p "$SEEN_DIR" 2>/dev/null
# Prune other sessions' files (and their stamps) idle for 7+ days.
find "$SEEN_DIR" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.err' -o -name '*.stderr' \) \
  -mtime +7 -delete 2>/dev/null
# One-release migration: seed a brand-new session file from the legacy one.
if [[ ! -f "$SEEN" && -f "$LEGACY_SEEN" ]]; then cp "$LEGACY_SEEN" "$SEEN" 2>/dev/null; fi
touch "$SEEN" 2>/dev/null

# Project filtering happens in node (below), so the project string never enters
# the SQL/SSH quoting. MACHINE comes from INTERAGENT_MACHINE or the controlled .machine-id file.
# Todos are durable: ttl_hours IS NULL. `created_at > now() - make_interval(hours => NULL)`
# is UNKNOWN, so a bare TTL predicate silently drops every todo (lived 2026-09-20:
# Grok TUI saw #265 msg and missed #262/#263/#266/#268). Match interagent-dispatch.sh.
# `archived = false` matches the gateway inbox, which never shows archived rows.
SQL="SELECT coalesce(json_agg(json_build_object('id',id,'title',title,'from',from_agent,'refs',context_refs)),'[]') FROM interagent_assignments WHERE status='pending' AND archived = false AND (to_target='${MACHINE}' OR to_target='any') AND (ttl_hours IS NULL OR created_at > now() - make_interval(hours => ttl_hours));"

# Emit one ERROR line, at most once per ERR_INTERVAL (a --once pass always emits).
report_error() {
  local now last
  now=$(date +%s)
  last=$(cat "$ERR_STAMP" 2>/dev/null)
  if [[ "$ONCE" -ne 1 && "$last" =~ ^[0-9]+$ ]] && (( now - last < ERR_INTERVAL )); then
    return 0
  fi
  printf '%s' "$now" > "$ERR_STAMP" 2>/dev/null
  echo "INTERAGENT poller ERROR: $1"
}

run_query() {
  if [[ -n "${INTERAGENT_POLL_STUB:-}" ]]; then
    cat "$INTERAGENT_POLL_STUB"
    return
  fi
  ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
    "docker exec pgvector psql -U postgres homelab -At -c \"$SQL\""
}

poll_once() {
  local json rc errfile reason
  errfile="${SEEN%.txt}.stderr"
  json=$(run_query 2>"$errfile"); rc=$?
  if (( rc != 0 )); then
    reason=$(grep -m1 . "$errfile" 2>/dev/null | tr -d '\r' | cut -c1-200)
    report_error "query failed (exit $rc)${reason:+: $reason}"
    return 0
  fi
  if [[ -z "$json" ]]; then
    report_error "query returned no output"
    return 0
  fi
  printf '%s' "$json" | PROJECT="$PROJECT" SEEN="$SEEN" MACHINE="$MACHINE" node -e '
    const fs=require("fs");
    let b=""; process.stdin.on("data",c=>b+=c); process.stdin.on("end",()=>{
      let rows; try{ rows=JSON.parse(b||"[]") }catch(e){ process.exit(3) }
      if(!Array.isArray(rows)) process.exit(3);
      const project=process.env.PROJECT, seenFile=process.env.SEEN, me=process.env.MACHINE;
      let seen=new Set();
      try{ seen=new Set(fs.readFileSync(seenFile,"utf8").split(/\r?\n/).filter(Boolean)) }catch(e){}
      const fresh=[];
      for(const r of rows){
        const id=String(r.id);
        if(seen.has(id)) continue;                       // this session already emitted it
        const refs=Array.isArray(r.refs)?r.refs:[];
        const proj=refs.filter(x=>x&&x.type==="project");
        const mine = proj.length===0 || proj.some(x=>String(x.id)===project);
        if(!mine) continue;                              // tagged for another project
        const tag = proj.length===0 ? "broadcast" : "project="+project;
        const self = r.from===me ? " [self]" : "";      // posted under our own name
        console.log("INTERAGENT new #"+id+" ["+tag+"]"+self+" from "+(r.from||"?")+": "+(r.title||"")+
                    "  -> check interagent to read + claim");
        fresh.push(id);
      }
      if(fresh.length){ try{ fs.appendFileSync(seenFile, fresh.join("\n")+"\n") }catch(e){} }
    });
  '
  rc=$?
  if (( rc == 3 )); then
    report_error "unparseable query output: $(printf '%s' "$json" | head -c 120 | tr -d '\r\n')"
  elif (( rc != 0 )); then
    report_error "filter failed (node exit $rc)"
  fi
  return 0
}

if [[ "$ONCE" -eq 1 ]]; then
  poll_once
  exit 0
fi

last_touch=$SECONDS
while true; do
  parent_alive || exit 0                # orphaned: the monitor that owns us is gone
  poll_once
  if (( SECONDS - last_touch >= 3600 )); then touch "$SEEN" 2>/dev/null; last_touch=$SECONDS; fi
  sleep "$INTERVAL"
done
