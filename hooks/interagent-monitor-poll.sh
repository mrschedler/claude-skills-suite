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
# ROBUSTNESS ─────────────────────────────────────────────────────────────────────
# Every SSH/psql failure is swallowed so one transient error never kills the
# monitor. BatchMode + ConnectTimeout mean it fails fast instead of hanging.
# Remote poll interval defaults to 30s (be gentle on the DB).
#
# USAGE ──────────────────────────────────────────────────────────────────────────
#   bash interagent-monitor-poll.sh          # loop forever, 30s interval
#   bash interagent-monitor-poll.sh 45       # loop forever, 45s interval
#   bash interagent-monitor-poll.sh --once   # single pass (for testing)

set -uo pipefail

ARG="${1:-}"
ONCE=0
INTERVAL=30
case "$ARG" in
  --once)        ONCE=1 ;;
  ''|*[!0-9]*)   : ;;                 # empty or non-numeric -> keep default
  *)             INTERVAL="$ARG" ;;
esac

MACHINE=$(sed -n 's/^machine:[[:space:]]*//p' /c/dev/.machine-id 2>/dev/null | head -1)
MACHINE="${MACHINE:-unknown}"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$GIT_ROOT" ]]; then PROJECT=$(basename "$GIT_ROOT"); else PROJECT=$(basename "$(pwd)"); fi

STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
mkdir -p "$STATE_DIR" 2>/dev/null
SEEN="$STATE_DIR/seen-${MACHINE}-${PROJECT}.txt"
touch "$SEEN" 2>/dev/null

# Project filtering happens in node (below), so the project string never enters
# the SQL/SSH quoting. MACHINE comes from the controlled .machine-id file.
SQL="SELECT coalesce(json_agg(json_build_object('id',id,'title',title,'from',from_agent,'refs',context_refs)),'[]') FROM interagent_assignments WHERE status='pending' AND (to_target='${MACHINE}' OR to_target='any') AND created_at > now() - make_interval(hours => ttl_hours);"

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
  poll_once
  sleep "$INTERVAL"
done
