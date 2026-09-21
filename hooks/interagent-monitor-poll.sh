#!/usr/bin/env bash
# interagent-monitor-poll.sh — poll loop behind the `monitor interagent` command.
#
# WHAT ─────────────────────────────────────────────────────────────────────────
# Each poll (one SSH/psql round trip): upserts interagent_watchers heartbeat,
# stamps delivered_to/delivered_at on newly matched inbox rows, and returns
# inbox pending UNION sent-row state for this machine. Emits:
#   INTERAGENT new #id ...          (receiver pickup)
#   DELIVERED #id to <machine> at T (sender visibility)
#   CLAIMED #id by <machine>
#   COMPLETED #id by <machine>: <first ~200 chars of result>
#   UNDELIVERED #id to <target> for >M min — receiver not acking (old poller or offline)
# Run by the agent's Monitor tool with persistent:true. This poller is the
# TRIGGER, not the worker — on wake the agent drains via interagent_call > inbox.
#
# WHY NOT A HOOK ────────────────────────────────────────────────────────────────
# Hooks in this suite are local-only and cannot reach the gateway. This is NOT a
# hook — it's a Monitor-driven background process, so it MAY do network. It reads
# interagent_assignments over SSH (ssh deepthought -> pgvector).
#
# LOCK / LIFECYCLE ──────────────────────────────────────────────────────────────
# Pidfile: %LOCALAPPDATA%/claude-interagent/poller-<machine>-<project>.pid
# Second start replaces a dead pid, else refuses (never two live pollers on one
# seen-file). Broken stdout (pipe closed) → exit that loop. Git-Bash on Windows:
# pidfile + kill -0, not ps.
#
# USAGE ──────────────────────────────────────────────────────────────────────────
#   bash interagent-monitor-poll.sh          # loop forever, 5s interval
#   bash interagent-monitor-poll.sh 30       # loop forever, 30s interval
#   bash interagent-monitor-poll.sh --once   # single pass (for testing)
#
# ENV ────────────────────────────────────────────────────────────────────────────
#   INTERAGENT_MACHINE          agent inbox name (else .machine-id machine:)
#   INTERAGENT_PROJECT          project scope (else git-root basename / cwd)
#   INTERAGENT_UNDELIVERED_MIN  first undelivered alarm threshold (default 5)
#   INTERAGENT_SENT_HOURS       how far back to watch sent rows (default 72)
#   INTERAGENT_PSQL_WRAPPER     optional cmd: wrapper "$SQL" → JSON rows (tests)

set -uo pipefail

ARG="${1:-}"
ONCE=0
INTERVAL=5
case "$ARG" in
  --once)        ONCE=1 ;;
  ''|*[!0-9]*)   : ;;
  *)             INTERVAL="$ARG" ;;
esac

MACHINE="${INTERAGENT_MACHINE:-}"
[[ -z "$MACHINE" ]] && MACHINE=$(sed -n 's/^machine:[[:space:]]*//p' /c/dev/.machine-id 2>/dev/null | head -1)
MACHINE="${MACHINE:-unknown}"

PROJECT="${INTERAGENT_PROJECT:-}"
if [[ -z "$PROJECT" ]]; then
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$GIT_ROOT" ]]; then PROJECT=$(basename "$GIT_ROOT"); else PROJECT=$(basename "$(pwd)"); fi
fi

STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
mkdir -p "$STATE_DIR" 2>/dev/null
SEEN="$STATE_DIR/seen-${MACHINE}-${PROJECT}.txt"
PIDFILE="$STATE_DIR/poller-${MACHINE}-${PROJECT}.pid"
touch "$SEEN" 2>/dev/null

UNDELIVERED_MIN="${INTERAGENT_UNDELIVERED_MIN:-5}"
SENT_HOURS="${INTERAGENT_SENT_HOURS:-72}"
PROCESS_JS="$(cd "$(dirname "$0")" && pwd)/interagent-monitor-process.js"

sql_quote() { printf "%s" "$1" | sed "s/'/''/g"; }

M_SQL=$(sql_quote "$MACHINE")
P_SQL=$(sql_quote "$PROJECT")
PID_SQL=$$
# interval / thresholds are integers from env/args — coerce safely
INTERVAL_SQL=$((INTERVAL + 0))
UNDEL_SQL=$((UNDELIVERED_MIN + 0))
SENT_SQL=$((SENT_HOURS + 0))

# One round-trip CTE: heartbeat, stamp undelivered matching inbox rows, return
# inbox pending + sent rows (node turns sent state into transition/alarm lines).
build_sql() {
  cat <<EOF
WITH params AS (
  SELECT
    '${M_SQL}'::text AS machine,
    '${P_SQL}'::text AS project,
    ${PID_SQL}::int AS pid,
    ${INTERVAL_SQL}::int AS interval_secs,
    ${UNDEL_SQL}::int AS undelivered_min,
    ${SENT_SQL}::int AS sent_hours
),
upsert_watcher AS (
  INSERT INTO interagent_watchers (machine, project, pid, last_poll_at)
  SELECT machine, project, pid, now() FROM params
  ON CONFLICT (machine, project) DO UPDATE
    SET pid = EXCLUDED.pid, last_poll_at = now()
  RETURNING machine
),
stamp_delivered AS (
  UPDATE interagent_assignments a
  SET delivered_to = p.machine,
      delivered_at = now()
  FROM params p
  WHERE a.status = 'pending'
    AND (a.to_target = p.machine OR a.to_target = 'any')
    AND (a.ttl_hours IS NULL OR a.created_at > now() - make_interval(hours => a.ttl_hours))
    AND a.delivered_at IS NULL
    AND COALESCE(a.archived, false) = false
    AND (
      NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.context_refs, '[]'::jsonb)) r
        WHERE r->>'type' = 'project'
      )
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.context_refs, '[]'::jsonb)) r
        WHERE r->>'type' = 'project' AND r->>'id' = p.project
      )
    )
  RETURNING a.id
),
side_effects AS (
  SELECT count(*)::int AS n FROM (
    SELECT 1 FROM upsert_watcher
    UNION ALL
    SELECT 1 FROM stamp_delivered
  ) s
),
inbox AS (
  SELECT
    'inbox'::text AS event,
    a.id,
    a.title,
    a.from_agent,
    a.to_target,
    a.status,
    a.claimed_by,
    a.result,
    a.context_refs AS refs,
    a.delivered_to,
    a.delivered_at,
    a.claimed_at,
    a.completed_at,
    a.created_at
  FROM interagent_assignments a, params p, side_effects se
  WHERE a.status = 'pending'
    AND (a.to_target = p.machine OR a.to_target = 'any')
    AND (a.ttl_hours IS NULL OR a.created_at > now() - make_interval(hours => a.ttl_hours))
    AND COALESCE(a.archived, false) = false
    AND (
      NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.context_refs, '[]'::jsonb)) r
        WHERE r->>'type' = 'project'
      )
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.context_refs, '[]'::jsonb)) r
        WHERE r->>'type' = 'project' AND r->>'id' = p.project
      )
    )
    AND se.n >= 0
),
sent AS (
  SELECT
    'sent'::text AS event,
    a.id,
    a.title,
    a.from_agent,
    a.to_target,
    a.status,
    a.claimed_by,
    a.result,
    a.context_refs AS refs,
    a.delivered_to,
    a.delivered_at,
    a.claimed_at,
    a.completed_at,
    a.created_at
  FROM interagent_assignments a, params p, side_effects se
  WHERE a.from_agent = p.machine
    AND a.created_at > now() - make_interval(hours => p.sent_hours)
    AND COALESCE(a.archived, false) = false
    AND se.n >= 0
)
SELECT coalesce(json_agg(row_to_json(u)), '[]'::json)
FROM (
  SELECT * FROM inbox
  UNION ALL
  SELECT * FROM sent
) u;
EOF
}

run_sql() {
  local sql="$1"
  if [[ -n "${INTERAGENT_PSQL_WRAPPER:-}" ]]; then
    # Wrapper receives SQL on stdin, prints JSON array on stdout.
    printf '%s' "$sql" | bash "$INTERAGENT_PSQL_WRAPPER" 2>/dev/null || true
  else
    # Collapse to one line for remote -c; keep it simple.
    local oneline
    oneline=$(printf '%s' "$sql" | tr '\n' ' ' | sed 's/  */ /g')
    ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
      "docker exec pgvector psql -U postgres homelab -At -c \"$oneline\"" 2>/dev/null || true
  fi
}

stdout_ok() {
  # Detect broken pipe without killing the shell via SIGPIPE.
  if ! (printf '' >&1) 2>/dev/null; then
    return 1
  fi
  return 0
}

acquire_pidfile() {
  if [[ -f "$PIDFILE" ]]; then
    local old
    old=$(cat "$PIDFILE" 2>/dev/null || true)
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
      echo "interagent-monitor-poll: already running pid=$old ($PIDFILE)" >&2
      exit 1
    fi
  fi
  echo $$ > "$PIDFILE"
  trap 'rm -f "$PIDFILE"' EXIT
}

poll_once() {
  if ! stdout_ok; then
    exit 0
  fi
  local json
  json=$(run_sql "$(build_sql)")
  [[ -z "$json" ]] && return 0
  if ! printf '%s' "$json" | \
      PROJECT="$PROJECT" SEEN="$SEEN" MACHINE="$MACHINE" \
      UNDELIVERED_MIN="$UNDELIVERED_MIN" \
      node "$PROCESS_JS"; then
    # process.js exits 1 on broken stdout — end the poller
    exit 0
  fi
  if ! stdout_ok; then
    exit 0
  fi
}

# Ignore SIGPIPE so a closed Monitor pipe becomes a clean exit via stdout_ok.
trap 'exit 0' PIPE

if [[ "$ONCE" -eq 1 ]]; then
  poll_once
  exit 0
fi

acquire_pidfile
while true; do
  poll_once
  sleep "$INTERVAL"
done
