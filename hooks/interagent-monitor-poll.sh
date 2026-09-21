#!/usr/bin/env bash
# interagent-monitor-poll.sh — poll loop behind the `monitor interagent` command.
#
# WHAT ─────────────────────────────────────────────────────────────────────────
# Each poll is ONE SSH/psql round trip. It upserts the interagent_watchers
# heartbeat, stamps delivered_to/delivered_at for the ids the PREVIOUS poll
# actually wrote to a live reader, and returns inbox pending ∪ changed sent rows
# ∪ the watcher rows of our sent targets. Emits:
#   INTERAGENT new #id ...          (receiver pickup)
#   DELIVERED #id to <machine> at T (sender visibility)
#   CLAIMED #id by <machine>
#   COMPLETED #id by <machine>: <first ~200 chars of result>
#   UNDELIVERED #id to <target> for >M min — receiver not acking (old poller or
#     offline) [watcher: none|stale Ns|live Ns]
# Run by the agent's Monitor tool with persistent:true. This poller is the
# TRIGGER, not the worker — on wake the agent drains via interagent_call > inbox.
#
# DELIVERY IS ACKED ONLY FOR BYTES THAT LANDED ────────────────────────────────
# A stamp means "a live session received this line". process.js appends an id to
# the ack-file ONLY after fs.writeSync(1, …) returned without throwing; the NEXT
# poll's CTE stamps exactly those ids. An orphan writing into a dead pipe fails
# the write, so the id enters neither the seen-file nor the ack-file and is never
# stamped — the message stays visible and the sender's UNDELIVERED alarm stays
# armed. This is the whole point of the feature; do not move the stamp back into
# the same statement that returns the inbox.
#
# WHY NOT A HOOK ────────────────────────────────────────────────────────────────
# Hooks in this suite are local-only and cannot reach the gateway. This is NOT a
# hook — it's a Monitor-driven background process, so it MAY do network. It reads
# interagent_assignments over SSH (ssh deepthought -> pgvector).
#
# LOCK / LIFECYCLE ──────────────────────────────────────────────────────────────
# Pidfile: %LOCALAPPDATA%/claude-interagent/poller-<machine>-<project>.pid
# Created with `set -o noclobber` (atomic O_EXCL), holding "<pid> <token>". A
# second start reaps a pid that is dead or whose /proc/<pid>/cmdline is not this
# script (pid reuse), and CHALLENGES a genuine live holder with SIGUSR1: the
# holder proves its pipe with a real write and exits if that write fails. A live
# session therefore never ends up with zero pollers because an orphan held the
# lock, and two pollers never share one seen-file.
#
# READER-GONE DETECTION ON GIT-BASH/WINDOWS ───────────────────────────────────
# Measured on MSYS, not assumed (see run-tests.sh arm "probe"):
#   [ -e /proc/self/fd/1 ]  → TRUE even with the reader gone            USELESS
#   readlink /proc/self/fd/1 → reports "pipe:[…]" even for a plain file  USELESS
#   kill -0 $PPID           → PPID becomes 1 when the parent exits and
#                             `kill -0 1` fails                          WORKS (armed)
#   real 1-byte write       → the ONLY probe that fails on a dead pipe   WORKS (costs a byte)
# So: the PPID check runs every poll when it can be armed (PPID was a real live
# pid at startup, identity pinned by its cmdline against pid reuse). The write
# probe is exact but writes a byte into the Monitor stream, so it runs on demand
# (SIGUSR1 challenge) and on a timer only if INTERAGENT_PROBE_SECS > 0.
# Correctness does NOT depend on either probe — the ack-file gate above does.
#
# USAGE ──────────────────────────────────────────────────────────────────────────
#   bash interagent-monitor-poll.sh          # loop forever, 5s interval
#   bash interagent-monitor-poll.sh 30       # loop forever, 30s interval
#   bash interagent-monitor-poll.sh --once   # single pass (takes the lock too)
#
# ENV ────────────────────────────────────────────────────────────────────────────
#   INTERAGENT_MACHINE          agent inbox name (else .machine-id machine:)
#   INTERAGENT_PROJECT          project scope (else git-root basename / cwd)
#   INTERAGENT_UNDELIVERED_MIN  first undelivered alarm threshold (default 5)
#   INTERAGENT_SENT_HOURS       how far back to watch sent rows (default 72)
#   INTERAGENT_PROBE_SECS       periodic real-write pipe probe (default 0 = off)
#   INTERAGENT_PSQL_WRAPPER     optional cmd: SQL on stdin → JSON on stdout (tests)

set -uo pipefail

MAIN_PID=$$

ARG="${1:-}"
ONCE=0
INTERVAL=5
case "$ARG" in
  --once)        ONCE=1 ;;
  ''|*[!0-9]*)   : ;;
  *)             INTERVAL="$ARG" ;;
esac
[[ "$INTERVAL" -lt 1 ]] 2>/dev/null && INTERVAL=1

MACHINE="${INTERAGENT_MACHINE:-}"
[[ -z "$MACHINE" ]] && MACHINE=$(sed -n 's/^machine:[[:space:]]*//p' /c/dev/.machine-id 2>/dev/null | head -1)
MACHINE="${MACHINE:-unknown}"

# PROJECT scope. Launched as PowerShell -> Git-Bash `-lc`, the LOGIN shell starts
# in $HOME, so an inferred project silently becomes the home directory's basename
# and the poller then watches a project nobody sends to — a blind watch that
# looks perfectly healthy. INTERAGENT_PROJECT is therefore the documented way to
# set it (see skills/monitor-interagent/SKILL.md), and an inferred value that
# smells like $HOME or the filesystem root is called out once instead of being
# used in silence.
# `git rev-parse --show-toplevel` answers in Windows form (C:/Users/matts) while
# $HOME and `pwd` are in MSYS form (/c/Users/matts), so the two never compare
# equal as strings. Normalise before deciding anything — the un-normalised
# version of this check silently failed to fire on the one machine it was
# written for.
norm_path() {
  local p="${1:-}"
  [[ -z "$p" ]] && return 0
  if command -v cygpath >/dev/null 2>&1; then
    p=$(cygpath -u "$p" 2>/dev/null) || p="$1"
  fi
  printf '%s' "${p%/}"
}

PROJECT="${INTERAGENT_PROJECT:-}"
PROJECT_SOURCE="INTERAGENT_PROJECT"
PROJECT_SUSPECT=""
if [[ -z "$PROJECT" ]]; then
  HOME_N=$(norm_path "${HOME:-}")
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$GIT_ROOT" ]]; then
    PROJECT=$(basename "$GIT_ROOT")
    PROJECT_SOURCE="git root $GIT_ROOT"
    GIT_ROOT_N=$(norm_path "$GIT_ROOT")
    if [[ -n "$HOME_N" && "$GIT_ROOT_N" == "$HOME_N" ]]; then
      PROJECT_SUSPECT="that git root IS your home directory"
    elif [[ -n "$HOME_N" && "$HOME_N" == "$GIT_ROOT_N"/* ]]; then
      PROJECT_SUSPECT="your home directory sits inside that git root, so it is not a project scope"
    fi
  else
    PWD_N=$(norm_path "$(pwd)")
    PROJECT=$(basename "$(pwd)")
    PROJECT_SOURCE="cwd $(pwd)"
    if [[ -n "$HOME_N" && "$PWD_N" == "$HOME_N" ]]; then
      PROJECT_SUSPECT="the working directory IS your home directory (a login shell starts there)"
    elif [[ "$PWD_N" == "" || "$PWD_N" == "/" ]]; then
      PROJECT_SUSPECT="the working directory is the filesystem root"
    fi
  fi
fi
[[ -z "$PROJECT" ]] && { PROJECT="unknown"; PROJECT_SUSPECT="nothing usable to infer it from"; }

STATE_DIR=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
mkdir -p "$STATE_DIR" 2>/dev/null
SEEN="$STATE_DIR/seen-${MACHINE}-${PROJECT}.txt"
PIDFILE="$STATE_DIR/poller-${MACHINE}-${PROJECT}.pid"
ACK_FILE="$STATE_DIR/ack-${MACHINE}-${PROJECT}.txt"
SINCE_FILE="$STATE_DIR/since-${MACHINE}-${PROJECT}.txt"
touch "$SEEN" "$ACK_FILE" 2>/dev/null

UNDELIVERED_MIN="${INTERAGENT_UNDELIVERED_MIN:-5}"
SENT_HOURS="${INTERAGENT_SENT_HOURS:-72}"
PROBE_SECS="${INTERAGENT_PROBE_SECS:-0}"
PROCESS_JS="$(cd "$(dirname "$0")" && pwd)/interagent-monitor-process.js"
LOCK_TOKEN="interagent-monitor-poll:${MACHINE}:${PROJECT}"

# SQL literal quoting. The SQL is delivered on psql's STDIN and the remote
# command string is a fixed single-quoted literal, so no shell — remote or
# local — ever expands these. Doubling ' is therefore sufficient under
# standard_conforming_strings; control characters are dropped so a name can
# never break the statement onto a new line.
sql_quote() { printf '%s' "$1" | tr -d '\000-\037' | sed "s/'/''/g"; }

M_SQL=$(sql_quote "$MACHINE")
P_SQL=$(sql_quote "$PROJECT")
PID_SQL=$$
INTERVAL_SQL=$((INTERVAL + 0))
UNDEL_SQL=$((UNDELIVERED_MIN + 0))
SENT_SQL=$((SENT_HOURS + 0))

SCHEMA_MODE="unknown"     # full | legacy
WARNED_LEGACY=0
WARNED_PROJECT=0
WARNED_BLIND=0
SQL_FAILS=0
SQL_RC=0
SQL_ERR=""
CHALLENGED=0

# ── transport ────────────────────────────────────────────────────────────────
# SQL always goes over stdin. The remote command carries no interpolated data,
# which is what makes MACHINE / PROJECT safe against quotes, backticks and $( ).
#
# The result goes to a FILE and the caller reads SQL_OUT, rather than
# `json=$(run_sql …)`. In a command substitution the whole function runs in a
# subshell, so SQL_RC and SQL_ERR would be assigned there and lost — the caller
# would see the initial 0 and an empty error string for every failed hop. That
# is precisely the "a dropped SSH hop looks like an empty inbox" failure.
SQL_OUT=""
run_sql() {
  local sql="$1" err_file out_file
  err_file="$STATE_DIR/.sqlerr-$$"
  out_file="$STATE_DIR/.sqlout-$$"
  if [[ -n "${INTERAGENT_PSQL_WRAPPER:-}" ]]; then
    printf '%s' "$sql" | bash "$INTERAGENT_PSQL_WRAPPER" >"$out_file" 2>"$err_file"
    SQL_RC=$?
  else
    printf '%s' "$sql" | ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
      'docker exec -i pgvector psql -U postgres homelab -At -q -v ON_ERROR_STOP=1 -f -' \
      >"$out_file" 2>"$err_file"
    SQL_RC=$?
  fi
  SQL_ERR=$(head -c 2000 "$err_file" 2>/dev/null)
  SQL_OUT=$(cat "$out_file" 2>/dev/null)
  rm -f "$err_file" "$out_file"
  return "$SQL_RC"
}

# Every successful reply is a JSON envelope carrying "schema" — that key IS the
# sentinel. An empty inbox still produces one ({"schema":…,"rows":[]}), so
# "no rows" and "the query never ran" are distinguishable without a second
# round trip. Anything else is a failed poll, however it exited.
sql_reply_is_real() {
  [[ $SQL_RC -eq 0 ]] || return 1
  [[ -n "$SQL_OUT" ]] || return 1
  case "$SQL_OUT" in *'"schema"'*) return 0 ;; esac
  return 1
}

# ── reader-gone detection ────────────────────────────────────────────────────
PPID0=$PPID
PPID0_CMD=""
PPID_WATCH=0
if [[ "$PPID0" != "1" && "$PPID0" != "0" ]] && kill -0 "$PPID0" 2>/dev/null; then
  PPID0_CMD=$(tr '\0' ' ' < "/proc/$PPID0/cmdline" 2>/dev/null | head -c 200)
  [[ -n "$PPID0_CMD" ]] && PPID_WATCH=1
fi

# Real write to stdout. Returns 0 if the byte landed, 1 if the reader is gone.
# The PIPE trap is cleared inside the subshell so a broken pipe surfaces as a
# non-zero status instead of killing us.
write_probe() {
  local payload="${1:-}"
  ( trap '' PIPE; printf '%s' "$payload" >&1 ) 2>/dev/null
}

reader_gone() {
  if [[ "$PPID_WATCH" == "1" ]]; then
    if ! kill -0 "$PPID0" 2>/dev/null; then
      return 0
    fi
    local now_cmd
    now_cmd=$(tr '\0' ' ' < "/proc/$PPID0/cmdline" 2>/dev/null | head -c 200)
    if [[ "$now_cmd" != "$PPID0_CMD" ]]; then
      return 0   # pid recycled onto a different process — our parent is gone
    fi
  fi
  if [[ "$PROBE_SECS" -gt 0 ]]; then
    local now_s=$((SECONDS))
    if (( now_s - LAST_PROBE_AT >= PROBE_SECS )); then
      LAST_PROBE_AT=$now_s
      if ! write_probe $'\n'; then
        return 0
      fi
    fi
  fi
  return 1
}
LAST_PROBE_AT=0

# ── pidfile ──────────────────────────────────────────────────────────────────
pidfile_owner() { head -n 1 "$PIDFILE" 2>/dev/null | awk '{print $1}'; }

# Is <pid> a live process that is genuinely THIS script (not a recycled pid)?
holder_is_genuine() {
  local pid="$1" cmd
  [[ -z "$pid" ]] && return 1
  kill -0 "$pid" 2>/dev/null || return 1
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
  [[ "$cmd" == *interagent-monitor-poll.sh* ]]
}

release_pidfile() {
  # MSYS bash runs an inherited EXIT trap when a command-substitution subshell
  # exits, and $$ still reports the MAIN shell's pid in that subshell — so an
  # unguarded release deletes the live pidfile on literally every $( ). BASHPID
  # is per-subshell and is the only safe discriminator.
  [[ "${BASHPID:-$$}" != "$MAIN_PID" ]] && return 0
  [[ "$(pidfile_owner)" == "$MAIN_PID" ]] && rm -f "$PIDFILE"
  return 0
}

# Atomic create via O_EXCL. Returns 0 if we now own the pidfile.
try_create_pidfile() {
  ( set -o noclobber; printf '%s %s\n' "$$" "$LOCK_TOKEN" > "$PIDFILE" ) 2>/dev/null
}

# T7: Grok's unattended dispatcher and an interactive TUI poller are BOTH live
# watchers for the same machine inbox. They keep separate state directories, so
# neither pidfile sees the other, yet they race to claim the same mail and both
# would stamp it. The pidfile rule has to span the pair, so each refuses while
# the other is running. Named, with the pid and the cmdline, because "already
# running" without saying what is running is what sends people hunting.
DISPATCH_PIDFILE=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/grok-interagent/dispatch.pid" | tr '\\' '/')

refuse_if_dispatcher_running() {
  local pid cmd
  pid=$(head -n 1 "$DISPATCH_PIDFILE" 2>/dev/null | awk '{print $1}')
  [[ -z "$pid" ]] && return 0
  kill -0 "$pid" 2>/dev/null || return 0
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
  case "$cmd" in
    *interagent-dispatch.sh*) ;;
    *) return 0 ;;                       # stale pidfile over a recycled pid
  esac
  echo "interagent-monitor-poll: refusing — the Grok dispatcher is already watching this machine's inbox." >&2
  echo "  pid=$pid  cmdline=$cmd" >&2
  echo "  They would race on claim and both stamp delivery. Stop one:" >&2
  echo "    bash /c/dev/claude-skills-suite/config/grok/interagent-dispatch.sh --stop" >&2
  exit 1
}

acquire_pidfile() {
  local old deadline
  refuse_if_dispatcher_running
  # Wall-clock bounded, not attempt bounded. A fixed number of attempts is not a
  # time budget on MSYS (spawning `sleep` costs ~0.5s), and — worse — contention
  # burns attempts that made progress: reaping a stale file and standing an
  # orphan down are both successes, and neither should count against the
  # session's chance of getting a poller. The ONLY fast refusal is a genuine live
  # holder that answered the challenge.
  local give_up=$((SECONDS + ${INTERAGENT_LOCK_WAIT:-45}))
  while (( SECONDS < give_up )); do
    if try_create_pidfile; then
      trap release_pidfile EXIT
      return 0
    fi
    old=$(pidfile_owner)
    if [[ -z "$old" || "$old" == "$MAIN_PID" ]]; then
      # Empty, or our OWN pid: a leftover from a previous process that happened
      # to have this pid. Challenging it would mean signalling ourselves and then
      # waiting for a pidfile that can never change — a self-inflicted deadlock.
      rm -f "$PIDFILE"
      continue
    fi
    if ! holder_is_genuine "$old"; then
      # Dead pid, or a pid recycled onto some unrelated MSYS process. Reap it —
      # a live session must never be locked out by a stale or foreign pid.
      echo "interagent-monitor-poll: reaping stale/foreign pidfile (pid=${old:-empty}) $PIDFILE" >&2
      rm -f "$PIDFILE"
      continue
    fi
    # A genuine poller holds the lock. It may still be an orphan on a dead pipe,
    # so challenge it: SIGUSR1 makes it prove its stdout with a real write and
    # exit if that write fails.
    echo "interagent-monitor-poll: challenging live holder pid=$old (SIGUSR1)" >&2
    kill -USR1 "$old" 2>/dev/null
    deadline=$((SECONDS + 5))
    while (( SECONDS < deadline )); do
      sleep 0.25
      [[ -f "$PIDFILE" ]] || break
      [[ "$(pidfile_owner)" == "$old" ]] || break
    done
    if [[ -f "$PIDFILE" ]] && [[ "$(pidfile_owner)" == "$old" ]]; then
      echo "interagent-monitor-poll: already running pid=$old ($PIDFILE) — holder answered the challenge, it is live" >&2
      exit 1
    fi
  done
  echo "interagent-monitor-poll: could not acquire $PIDFILE within ${INTERAGENT_LOCK_WAIT:-45}s — this session has NO poller" >&2
  exit 1
}

# ── SQL ──────────────────────────────────────────────────────────────────────
probe_schema_sql() {
  cat <<'EOF'
SELECT CASE WHEN
  EXISTS (SELECT 1 FROM information_schema.columns
           WHERE table_name = 'interagent_assignments' AND column_name = 'delivered_to')
  AND EXISTS (SELECT 1 FROM information_schema.columns
           WHERE table_name = 'interagent_assignments' AND column_name = 'delivered_at')
  AND EXISTS (SELECT 1 FROM information_schema.tables
           WHERE table_name = 'interagent_watchers')
THEN 'full' ELSE 'legacy' END;
EOF
}

# $1 = comma separated ack ids (may be empty), $2 = since timestamp (ISO or empty)
build_sql_full() {
  local ack_csv="$1" since="$2"
  local ack_arr since_expr
  if [[ -n "$ack_csv" ]]; then ack_arr="ARRAY[$ack_csv]::bigint[]"; else ack_arr="ARRAY[]::bigint[]"; fi
  if [[ -n "$since" ]]; then since_expr="'$(sql_quote "$since")'::timestamptz"; else since_expr="'-infinity'::timestamptz"; fi
  cat <<EOF
WITH params AS (
  SELECT
    '${M_SQL}'::text AS machine,
    '${P_SQL}'::text AS project,
    ${PID_SQL}::int AS pid,
    ${INTERVAL_SQL}::int AS interval_secs,
    ${UNDEL_SQL}::int AS undelivered_min,
    ${SENT_SQL}::int AS sent_hours,
    ${since_expr} AS since,
    ${ack_arr} AS ack_ids
),
upsert_watcher AS (
  INSERT INTO interagent_watchers (machine, project, pid, interval_secs, last_poll_at)
  SELECT machine, project, pid, interval_secs, now() FROM params
  ON CONFLICT (machine, project) DO UPDATE
    SET pid = EXCLUDED.pid,
        interval_secs = EXCLUDED.interval_secs,
        last_poll_at = now()
  RETURNING machine
),
-- Stamp ONLY ids the previous poll actually wrote to a live reader, AND only
-- rows actually addressed to this machine. The routing predicate is redundant
-- with how the ids got into the ack-file — and it stays anyway: an ack-file left
-- behind by a renamed profile, or a poller started with the wrong
-- INTERAGENT_MACHINE, must never be able to write "delivered to me" onto another
-- session's mail. delivered_to records which poller claimed the pickup.
stamp_delivered AS (
  UPDATE interagent_assignments a
  SET delivered_to = p.machine,
      delivered_at = now()
  FROM params p
  WHERE a.id = ANY (p.ack_ids)
    AND a.delivered_at IS NULL
    AND (a.to_target = p.machine OR a.to_target = 'any')
  RETURNING a.id
),
inbox AS (
  SELECT
    'inbox'::text AS event,
    a.id, a.title, a.from_agent, a.to_target, a.status, a.claimed_by,
    left(a.result, 200) AS result,
    a.context_refs AS refs,
    a.delivered_to, a.delivered_at, a.claimed_at, a.completed_at, a.created_at
  FROM interagent_assignments a, params p
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
),
-- Sent rows: only those whose state moved since the last poll, plus every row
-- still awaiting delivery (those must be re-evaluated each poll for the alarm
-- thresholds). GREATEST ignores NULLs in Postgres.
sent AS (
  SELECT
    'sent'::text AS event,
    a.id, a.title, a.from_agent, a.to_target, a.status, a.claimed_by,
    left(a.result, 200) AS result,
    a.context_refs AS refs,
    a.delivered_to, a.delivered_at, a.claimed_at, a.completed_at, a.created_at
  FROM interagent_assignments a, params p
  WHERE a.from_agent = p.machine
    AND a.created_at > now() - make_interval(hours => p.sent_hours)
    AND COALESCE(a.archived, false) = false
    AND (
      a.delivered_at IS NULL
      OR GREATEST(a.created_at, a.delivered_at, a.claimed_at, a.completed_at) >= p.since
    )
),
watchers_out AS (
  SELECT
    w.machine,
    EXTRACT(EPOCH FROM (now() - w.last_poll_at))::int AS idle_secs,
    (EXTRACT(EPOCH FROM (now() - w.last_poll_at))::int
       > 3 * GREATEST(COALESCE(w.interval_secs, p.interval_secs), 1)) AS stale
  FROM interagent_watchers w, params p
  WHERE w.machine IN (SELECT DISTINCT to_target FROM sent)
)
SELECT json_build_object(
  'schema', 'full',
  'now', now(),
  'stamped', (SELECT coalesce(json_agg(id), '[]'::json) FROM stamp_delivered),
  'watcher_upserts', (SELECT count(*) FROM upsert_watcher),
  'watchers', (SELECT coalesce(json_agg(row_to_json(w)), '[]'::json) FROM watchers_out w),
  'rows', (SELECT coalesce(json_agg(row_to_json(u)), '[]'::json)
             FROM (SELECT * FROM inbox UNION ALL SELECT * FROM sent) u)
)::text;
EOF
}

# Inbox-only fallback for an un-migrated database: no delivered_* columns, no
# watcher table, therefore no sender-side lines at all.
build_sql_legacy() {
  cat <<EOF
WITH params AS (
  SELECT '${M_SQL}'::text AS machine, '${P_SQL}'::text AS project
),
inbox AS (
  SELECT
    'inbox'::text AS event,
    a.id, a.title, a.from_agent, a.to_target, a.status, a.claimed_by,
    left(a.result, 200) AS result,
    a.context_refs AS refs,
    a.claimed_at, a.completed_at, a.created_at
  FROM interagent_assignments a, params p
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
)
SELECT json_build_object(
  'schema', 'legacy',
  'now', now(),
  'stamped', '[]'::json,
  'watchers', '[]'::json,
  'rows', (SELECT coalesce(json_agg(row_to_json(u)), '[]'::json) FROM inbox u)
)::text;
EOF
}

# ── diagnostics (never silent) ───────────────────────────────────────────────
say() { write_probe "$1"$'\n' || return 1; return 0; }

warn_legacy_once() {
  [[ "$WARNED_LEGACY" == "1" ]] && return 0
  WARNED_LEGACY=1
  local msg="WARN: interagent schema not migrated — inbox-only mode (no delivery ack). Apply migrations/0001_interagent_delivery_ack.sql, then restart this monitor."
  echo "$msg" >&2
  say "$msg"
}

warn_project_once() {
  [[ -z "$PROJECT_SUSPECT" ]] && return 0
  [[ "$WARNED_PROJECT" == "1" ]] && return 0
  WARNED_PROJECT=1
  local msg="WARN: interagent project scope inferred as '$PROJECT' from $PROJECT_SOURCE — $PROJECT_SUSPECT. Mail tagged for a real project will be ignored. Set INTERAGENT_PROJECT in the monitor command."
  echo "$msg" >&2
  say "$msg"
}

# The SSH hop to deepthought drops roughly every half hour. A dropped hop must
# never read as "your inbox is empty": on a failed poll nothing is stamped, the
# ack-file is not drained, the since high-water is not advanced, the seen-file is
# not appended to, and no alarm is cleared — poll_once returns before any of that
# happens. What is left is telling the session its watch has gone blind, once,
# after BLIND_AFTER consecutive failures, plus one all-clear when it recovers.
BLIND_AFTER="${INTERAGENT_BLIND_AFTER:-3}"
note_sql_failure() {
  SQL_FAILS=$((SQL_FAILS + 1))
  local first
  first=$(printf '%s' "$SQL_ERR" | tr '\n' ' ' | head -c 200)
  [[ -z "$first" ]] && first="psql exited $SQL_RC and returned no envelope (hop down?)"
  echo "interagent poll failed ($SQL_FAILS consecutive): $first" >&2
  if (( SQL_FAILS >= BLIND_AFTER )) && [[ "$WARNED_BLIND" != "1" ]]; then
    WARNED_BLIND=1
    say "WARN: interagent watch is BLIND — $SQL_FAILS consecutive failed polls (${first}). New mail will not be announced until this clears."
  fi
}

note_sql_success() {
  if [[ "$WARNED_BLIND" == "1" ]]; then
    WARNED_BLIND=0
    say "INTERAGENT watch recovered after $SQL_FAILS failed polls."
  fi
  SQL_FAILS=0
}

looks_like_missing_schema() {
  printf '%s' "$SQL_ERR" | grep -qiE 'delivered_to|delivered_at|interagent_watchers' &&
  printf '%s' "$SQL_ERR" | grep -qiE 'does not exist|undefined (column|table)'
}

detect_schema() {
  local out
  run_sql "$(probe_schema_sql)"
  out=$(printf '%s' "$SQL_OUT" | tr -d '\r' | head -n 1 | tr -d '[:space:]')
  case "$out" in
    full)   SCHEMA_MODE="full" ;;
    legacy) SCHEMA_MODE="legacy"; warn_legacy_once ;;
    *)
      # The probe itself did not run (hop down). Stay "unknown" so the NEXT poll
      # probes again — latching to a mode on the strength of a failed query is
      # how a transient hop drop turns into a permanently wrong schema guess.
      SCHEMA_MODE="unknown"
      note_sql_failure
      return 1
      ;;
  esac
  return 0
}

# ── ack bookkeeping ──────────────────────────────────────────────────────────
ack_snapshot() { sort -u "$ACK_FILE" 2>/dev/null | grep -E '^[0-9]+$' || true; }

ack_clear() {
  local sent_ids="$1"
  [[ -z "$sent_ids" ]] && return 0
  local done_f="$ACK_FILE.done.$$" tmp_f="$ACK_FILE.tmp.$$"
  printf '%s\n' "$sent_ids" > "$done_f"
  grep -v -x -F -f "$done_f" "$ACK_FILE" > "$tmp_f" 2>/dev/null
  mv -f "$tmp_f" "$ACK_FILE" 2>/dev/null
  rm -f "$done_f" "$tmp_f"
  return 0
}

read_since() { cat "$SINCE_FILE" 2>/dev/null | tr -d '\r\n'; }

# ── the poll ─────────────────────────────────────────────────────────────────
poll_once() {
  if reader_gone; then
    exit 0
  fi

  warn_project_once

  if [[ "$SCHEMA_MODE" == "unknown" ]]; then
    detect_schema || return 0
  fi

  local ack_ids ack_csv since json sql
  ack_ids=$(ack_snapshot)
  ack_csv=$(printf '%s' "$ack_ids" | tr '\n' ',' | sed 's/,$//')
  since=$(read_since)

  if [[ "$SCHEMA_MODE" == "legacy" ]]; then
    sql=$(build_sql_legacy)
  else
    sql=$(build_sql_full "$ack_csv" "$since")
  fi

  run_sql "$sql"

  # "Did the query RUN?" — not "did it return rows?". Everything below this
  # point mutates durable state, so a poll that did not demonstrably run must
  # leave every bit of it alone.
  if ! sql_reply_is_real; then
    if looks_like_missing_schema; then
      # The database lost the columns under a running poller (rollback applied).
      SCHEMA_MODE="legacy"
      warn_legacy_once
      return 0
    fi
    note_sql_failure
    return 0
  fi
  note_sql_success
  json="$SQL_OUT"

  # The round trip succeeded, so the ids we passed are now stamped (or were
  # already stamped). Drop them from the ack-file.
  [[ "$SCHEMA_MODE" == "full" ]] && ack_clear "$ack_ids"

  # process.js persists the server clock into SINCE_FILE itself. Parsing it here
  # would mean a second `node` start per poll, and a node start costs the better
  # part of a second on Windows — the poll budget is the scarce resource.
  if ! printf '%s' "$json" | \
      PROJECT="$PROJECT" SEEN="$SEEN" MACHINE="$MACHINE" \
      ACK_FILE="$ACK_FILE" SINCE_FILE="$SINCE_FILE" INTERVAL_SECS="$INTERVAL" \
      UNDELIVERED_MIN="$UNDELIVERED_MIN" \
      node "$PROCESS_JS"; then
    # process.js exits 1 when a write to stdout failed — the reader is gone.
    exit 0
  fi
}

# A challenge from a starting poller: prove the pipe with a REAL write. If the
# write fails we are an orphan — exit and hand the lock over.
answer_challenge() {
  CHALLENGED=0
  if ! say "INTERAGENT poller alive pid=$$ (machine=$MACHINE project=$PROJECT)"; then
    echo "interagent-monitor-poll: challenged, stdout is dead — exiting (pid=$$)" >&2
    exit 0
  fi
}

trap 'exit 0' PIPE
trap 'CHALLENGED=1' USR1

if [[ "$ONCE" -eq 1 ]]; then
  acquire_pidfile
  poll_once
  exit 0
fi

acquire_pidfile
while true; do
  poll_once
  # Background sleep + wait so SIGUSR1 interrupts immediately instead of after
  # a whole interval (verified on MSYS bash).
  sleep "$INTERVAL" & SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null
  kill "$SLEEP_PID" 2>/dev/null
  [[ "$CHALLENGED" == "1" ]] && answer_challenge
done
