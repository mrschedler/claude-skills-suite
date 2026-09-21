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

# The pidfile holds "<pid> <token>"; everything that uses it wants field 1.
pidfile_pid() { head -n 1 "$PIDFILE" 2>/dev/null | awk '{print $1}'; }

if [[ "${STATUS:-0}" == "1" ]]; then
  # The pidfile carries "<pid> <token>" (the token lets the monitor poller tell a
  # real dispatcher from a recycled pid), so always read the FIRST FIELD.
  if [[ -f "$PIDFILE" ]] && kill -0 "$(pidfile_pid)" 2>/dev/null; then
    echo "running pid=$(pidfile_pid) machine=$INTERAGENT_MACHINE interval_file=$PIDFILE"
  else
    echo "not running"
  fi
  tail -n 20 "$LOG" 2>/dev/null || true
  exit 0
fi

if [[ "${STOP:-0}" == "1" ]]; then
  if [[ -f "$PIDFILE" ]]; then
    pid=$(pidfile_pid)
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

# T7: an interactive TUI session may already have armed
# hooks/interagent-monitor-poll.sh on this same machine inbox. The two keep
# separate state directories, so neither pidfile sees the other — but they race
# to claim the same mail and both would stamp delivery. Refuse, naming the pid
# and the cmdline, so the operator knows exactly what to stop.
refuse_if_monitor_poller_running() {
  local dir f pid cmd
  dir=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
  for f in "$dir"/poller-"$INTERAGENT_MACHINE"-*.pid; do
    [[ -e "$f" ]] || continue
    pid=$(head -n 1 "$f" 2>/dev/null | awk '{print $1}')
    [[ -n "$pid" ]] || continue
    kill -0 "$pid" 2>/dev/null || continue
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
    case "$cmd" in *interagent-monitor-poll.sh*) ;; *) continue ;; esac
    echo "interagent-dispatch: refusing — an interactive monitor poller is already watching $INTERAGENT_MACHINE." >&2
    echo "  pid=$pid  cmdline=$cmd" >&2
    echo "  pidfile=$f" >&2
    echo "  They would race on claim and both stamp delivery. Disarm it in that session (/monitor-interagent stop), or do not run this dispatcher." >&2
    exit 1
  done
  return 0
}

# Applies to --once too: a single pass still LAUNCHES workers, so it races an
# interactive poller exactly the same way. (--stop and --status have already
# returned above; they must never be blocked.)
refuse_if_monitor_poller_running

if [[ "$ONCE" -ne 1 ]]; then
  if [[ -f "$PIDFILE" ]] && kill -0 "$(pidfile_pid)" 2>/dev/null; then
    echo "already running pid=$(pidfile_pid) — $0 --stop first" >&2
    exit 1
  fi
  printf '%s interagent-dispatch:%s\n' "$$" "$INTERAGENT_MACHINE" > "$PIDFILE"
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
# Skip our own outbound mail (a self-reply would otherwise recurse).
#
# DELIVERY ACK — spec E, "the dispatcher must stamp delivery or be exempt by design".
# It stamps. The dispatcher IS a live receiver: launching a `grok -p` worker for
# an id is a real pickup, indistinguishable to the sender from a Monitor session
# emitting the line. If it did not stamp, the sender's poller would raise
# UNDELIVERED at 5, 15 and 60 minutes for every message the dispatcher in fact
# handled — a false-alarm storm on the exact path this feature exists to make
# trustworthy. The stamp happens immediately BEFORE the launch, for the same
# reason the monitor poller stamps only what it wrote: nothing is acked until the
# work is actually being handed over. The watcher heartbeat is NOT upserted here —
# the dispatcher is not a poller a sender can wait on, so no heartbeat is better
# than a heartbeat that outlives the jobs.
SQL_QUOTE_M=$(printf '%s' "$INTERAGENT_MACHINE" | tr -d '\000-\037' | sed "s/'/''/g")
SQL="SELECT coalesce(json_agg(json_build_object('id',id,'title',title,'from',from_agent,'refs',context_refs)),'[]') FROM interagent_assignments WHERE status='pending' AND to_target='${SQL_QUOTE_M}' AND from_agent <> '${SQL_QUOTE_M}' AND (ttl_hours IS NULL OR created_at > now() - make_interval(hours => ttl_hours));"

# SQL always travels on psql's stdin; the remote command string is a fixed
# literal, so no remote shell ever expands a machine name containing a backtick,
# a quote or $( ). Same rule as hooks/interagent-monitor-poll.sh.
run_sql() {
  printf '%s' "$1" | ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
    'docker exec -i pgvector psql -U postgres homelab -At -q -v ON_ERROR_STOP=1 -f -' 2>/dev/null
}

# Best effort: an old schema has no delivered_to, and a failed stamp must never
# stop the job from being dispatched.
stamp_delivered() {
  local id="$1"
  [[ "$id" =~ ^[0-9]+$ ]] || return 0
  run_sql "UPDATE interagent_assignments SET delivered_to = '${SQL_QUOTE_M}', delivered_at = now() WHERE id = ${id} AND delivered_at IS NULL;" >/dev/null 2>&1 \
    || log "STAMP_SKIPPED id=$id (schema not migrated?)"
  return 0
}

poll_once() {
  local json lines line id project from title cwd win_cwd joblog rules prompt
  json=$(run_sql "$SQL" || true)
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
    stamp_delivered "$id"
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
