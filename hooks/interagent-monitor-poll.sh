#!/usr/bin/env bash
# interagent-monitor-poll.sh — poll loop behind the `monitor interagent` command.
#
# WHAT ─────────────────────────────────────────────────────────────────────────
# Emits ONE stdout line per NEW pending interagent message routed to THIS session,
# then sleeps INTERVAL seconds and repeats. Run by the agent's Monitor tool with
# persistent:true — each emitted line becomes a chat event that wakes an otherwise
# idle session. On wake the agent drains/claims the message via
# interagent_call > inbox (MCP). This poller is the TRIGGER, not the worker.
#
# WHY NOT A HOOK ────────────────────────────────────────────────────────────────
# Hooks in this suite are local-only and cannot reach the gateway (and a shell
# hook can't call an MCP tool anyway). This is NOT a hook — it's a Monitor-driven
# background process, so it MAY do network. It reads the interagent_assignments
# table directly over SSH (ssh deepthought -> pgvector container), the simplest
# path that needs no gateway change. (interagent data lives in the homelab PG DB.)
#
# ROUTING (machine inbox -> per session) ─────────────────────────────────────────
# Emits messages with status=pending, to_target in (this machine,'any'), not past
# TTL, that are tagged {type:"project", id:<this project>} OR carry NO project tag
# (broadcast). Messages tagged for ANOTHER project are skipped so they remain for
# that project's session. "New" = id not previously emitted, tracked in a
# non-synced seen-file under LOCALAPPDATA (per machine+project).
#
# ORPHAN GUARD ───────────────────────────────────────────────────────────────────
# The Monitor tool launches this script from a wrapper shell. When the monitor
# expires (~30 min) that wrapper is killed, but this loop used to survive it —
# and an orphaned poller keeps CLAIMING new interagent mail into its seen-file,
# so the live monitor never emits it. Lived 2026-09-21/22: ~40 orphan pollers had
# piled up at the 30-min monitor cadence, all eating events. The loop now watches
# a parent pid and exits silently once it is gone (see PARENT below).
#
# ROBUSTNESS ─────────────────────────────────────────────────────────────────────
# Every SSH/psql failure is swallowed so one transient error never kills the
# monitor. BatchMode + ConnectTimeout mean it fails fast instead of hanging.
# Poll interval defaults to 5s — fast enough for live multi-session coordination
# (a single SSH round-trip is ~0.3s, so the DB cost is negligible). Pass a larger
# number for a gentler cadence on long idle watches.
#
# USAGE ──────────────────────────────────────────────────────────────────────────
#   bash interagent-monitor-poll.sh          # loop forever, 5s interval
#   bash interagent-monitor-poll.sh 30       # loop forever, 30s interval
#   bash interagent-monitor-poll.sh --once   # single pass (for testing)

set -uo pipefail

ARG="${1:-}"
ONCE=0
INTERVAL=5
case "$ARG" in
  --once)        ONCE=1 ;;
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

STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
mkdir -p "$STATE_DIR" 2>/dev/null
SEEN="$STATE_DIR/seen-${MACHINE}-${PROJECT}.txt"
touch "$SEEN" 2>/dev/null

# Project filtering happens in node (below), so the project string never enters
# the SQL/SSH quoting. MACHINE comes from INTERAGENT_MACHINE or the controlled .machine-id file.
# Todos are durable: ttl_hours IS NULL. `created_at > now() - make_interval(hours => NULL)`
# is UNKNOWN, so a bare TTL predicate silently drops every todo (lived 2026-09-20:
# Grok TUI saw #265 msg and missed #262/#263/#266/#268). Match interagent-dispatch.sh.
SQL="SELECT coalesce(json_agg(json_build_object('id',id,'title',title,'from',from_agent,'refs',context_refs)),'[]') FROM interagent_assignments WHERE status='pending' AND (to_target='${MACHINE}' OR to_target='any') AND (ttl_hours IS NULL OR created_at > now() - make_interval(hours => ttl_hours));"

poll_once() {
  local json
  json=$(ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
    "docker exec pgvector psql -U postgres homelab -At -c \"$SQL\"" 2>/dev/null || true)
  [[ -z "$json" ]] && return 0
  printf '%s' "$json" | PROJECT="$PROJECT" SEEN="$SEEN" node -e '
    const fs=require("fs");
    let b=""; process.stdin.on("data",c=>b+=c); process.stdin.on("end",()=>{
      let rows; try{ rows=JSON.parse(b||"[]") }catch(e){ return }
      if(!Array.isArray(rows)) return;
      const project=process.env.PROJECT, seenFile=process.env.SEEN;
      let seen=new Set();
      try{ seen=new Set(fs.readFileSync(seenFile,"utf8").split(/\r?\n/).filter(Boolean)) }catch(e){}
      const fresh=[];
      for(const r of rows){
        const id=String(r.id);
        if(seen.has(id)) continue;                       // already emitted
        const refs=Array.isArray(r.refs)?r.refs:[];
        const proj=refs.filter(x=>x&&x.type==="project");
        const mine = proj.length===0 || proj.some(x=>String(x.id)===project);
        if(!mine) continue;                              // tagged for another project
        const tag = proj.length===0 ? "broadcast" : "project="+project;
        console.log("INTERAGENT new #"+id+" ["+tag+"] from "+(r.from||"?")+": "+(r.title||"")+
                    "  -> check interagent to read + claim");
        fresh.push(id);
      }
      if(fresh.length){ try{ fs.appendFileSync(seenFile, fresh.join("\n")+"\n") }catch(e){} }
    });
  ' || true
}

if [[ "$ONCE" -eq 1 ]]; then
  poll_once
  exit 0
fi

while true; do
  parent_alive || exit 0                # orphaned: the monitor that owns us is gone
  poll_once
  sleep "$INTERVAL"
done
