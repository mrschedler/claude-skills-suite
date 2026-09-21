#!/usr/bin/env bash
# interagent-dispatch.sh — unattended pickup of mail addressed to dell-xps-grok.
#
# NOT an agent. Polls the interagent table over SSH, then launches one
# `grok -p` worker per NEW id. Interactive grok-agent sessions should use the
# Monitor tool + hooks/interagent-monitor-poll.sh instead, and should NOT run
# this at the same time (they would race on claim).
#
# Only to_target=dell-xps-grok (never `any` broadcasts). Other agents assign
# work by sending to 'dell-xps-grok' with a thread_id and a project context_ref.
#
# USAGE
#   bash interagent-dispatch.sh           # loop, 5s
#   bash interagent-dispatch.sh 30        # loop, 30s
#   bash interagent-dispatch.sh --once    # one poll; launch any new jobs; wait
#   bash interagent-dispatch.sh --stop    # kill the running dispatcher
#   bash interagent-dispatch.sh --status  # pid + last log lines

set -uo pipefail

SUITE="/c/dev/claude-skills-suite"
FILTER="$SUITE/config/grok/interagent-dispatch-filter.js"
WORKER_RULES="$SUITE/config/grok/worker-interagent.md"
export INTERAGENT_MACHINE="${INTERAGENT_MACHINE:-dell-xps-grok}"
GROK="${GROK:-}"
if [[ -z "$GROK" ]]; then
  if command -v grok >/dev/null 2>&1; then
    GROK=$(command -v grok)
  elif [[ -x /c/Users/matts/.grok/bin/grok.exe ]]; then
    GROK="/c/Users/matts/.grok/bin/grok.exe"
  else
    echo "grok not on PATH" >&2
    exit 1
  fi
fi

ARG="${1:-}"
ONCE=0
INTERVAL=5
case "$ARG" in
  --once)   ONCE=1 ;;
  --stop)   STOP=1 ;;
  --status) STATUS=1 ;;
  ''|*[!0-9]*) : ;;
  *)        INTERVAL="$ARG" ;;
esac

STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/grok-interagent" | tr '\\' '/')
mkdir -p "$STATE_DIR/logs" 2>/dev/null
PIDFILE="$STATE_DIR/dispatch.pid"
SEEN="$STATE_DIR/seen-${INTERAGENT_MACHINE}.txt"
LOG="$STATE_DIR/logs/dispatch.log"
touch "$SEEN" 2>/dev/null

log() { printf '%s %s\n' "$(date -Iseconds 2>/dev/null || date)" "$*" | tee -a "$LOG"; }

if [[ "${STATUS:-0}" == "1" ]]; then
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    echo "running pid=$(cat "$PIDFILE") machine=$INTERAGENT_MACHINE interval_file=$PIDFILE"
  else
    echo "not running"
  fi
  tail -n 20 "$LOG" 2>/dev/null || true
  exit 0
fi

if [[ "${STOP:-0}" == "1" ]]; then
  if [[ -f "$PIDFILE" ]]; then
    pid=$(cat "$PIDFILE" 2>/dev/null || true)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      echo "stopped pid=$pid"
    else
      echo "stale pidfile (pid=$pid)"
    fi
    rm -f "$PIDFILE"
  else
    echo "not running"
  fi
  exit 0
fi

if [[ "$ONCE" -ne 1 ]]; then
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    echo "already running pid=$(cat "$PIDFILE") — $0 --stop first" >&2
    exit 1
  fi
  echo $$ > "$PIDFILE"
  trap 'rm -f "$PIDFILE"' EXIT
fi

resolve_cwd() {
  local p="${1:-}"
  local d
  if [[ -n "$p" && "$p" != "-" ]]; then
    for d in "/c/dev/$p" "/c/Dev/$p" "/c/DEV/$p"; do
      if [[ -d "$d" ]]; then
        printf '%s' "$d"
        return
      fi
    done
  fi
  printf '%s' "/c/dev/claude-skills-suite"
}

# Todos have ttl_hours NULL; include those. Same TTL predicate as the monitor poller.
# Delivery-ack stamps (delivered_to/at, watchers CTE) are owned by
# hooks/interagent-monitor-poll.sh — this dispatcher does not share that SQL.
# Skip our own outbound mail (a self-reply would otherwise recurse).
SQL="SELECT coalesce(json_agg(json_build_object('id',id,'title',title,'from',from_agent,'refs',context_refs)),'[]') FROM interagent_assignments WHERE status='pending' AND to_target='${INTERAGENT_MACHINE}' AND from_agent <> '${INTERAGENT_MACHINE}' AND (ttl_hours IS NULL OR created_at > now() - make_interval(hours => ttl_hours));"

poll_once() {
  local json lines line id project from title cwd win_cwd joblog rules prompt
  json=$(ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
    "docker exec pgvector psql -U postgres homelab -At -c \"$SQL\"" 2>/dev/null || true)
  [[ -z "$json" ]] && return 0
  lines=$(printf '%s' "$json" | SEEN="$SEEN" node "$FILTER" || true)
  [[ -z "$lines" ]] && return 0
  while IFS=$'\t' read -r id project from title; do
    [[ -z "$id" ]] && continue
    cwd=$(resolve_cwd "$project")
    if command -v cygpath >/dev/null 2>&1; then
      win_cwd=$(cygpath -w "$cwd")
    else
      win_cwd="$cwd"
    fi
    joblog="$STATE_DIR/logs/job-${id}-$(date +%Y%m%dT%H%M%S).log"
    rules=$(cat "$WORKER_RULES" 2>/dev/null || true)
    prompt="HEADLESS INTERAGENT JOB. You are dell-xps-grok. Message #${id} is yours.
get it, claim it as dell-xps-grok, do the work, reply on its thread to the sender (from=${from}), then complete it with a one-paragraph result.
Skip janitor and full rehydrate. Project tag=${project}. Sender=${from}. Title=${title}."
    log "LAUNCH id=$id project=$project from=$from cwd=$win_cwd log=$joblog"
    INTERAGENT_MACHINE="$INTERAGENT_MACHINE" "$GROK" -p "$prompt" \
      --cwd "$win_cwd" \
      --max-turns 40 \
      --always-approve \
      --permission-mode auto \
      --no-subagents \
      --output-format json \
      --rules "$rules" \
      >"$joblog" 2>&1 || log "WORKER_FAIL id=$id (see $joblog)"
    log "DONE id=$id"
  done <<< "$lines"
}

if [[ "$ONCE" -eq 1 ]]; then
  poll_once
  exit 0
fi

log "START machine=$INTERAGENT_MACHINE interval=${INTERVAL}s pid=$$"
while true; do
  poll_once
  sleep "$INTERVAL"
done
