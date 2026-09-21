#!/usr/bin/env bash
# interagent-monitor-poll.sh — poll loop behind the `monitor interagent` command.
#
# WHAT ─────────────────────────────────────────────────────────────────────────
# One SSH/psql round trip per poll. Emits stdout lines that the agent's Monitor
# tool turns into chat events waking an otherwise idle session:
#
#   INBOX side (mail routed to this machine+project, pending and UNCLAIMED)
#     INTERAGENT new #id [tag] from <who>: <title>  -> claim it, then work
#
#   SENDER side (mail this machine sent in the last INTERAGENT_SENT_HOURS)
#     CLAIMED #id by <who> after <n> s
#     COMPLETED #id: <first 200 chars of result>
#     UNCLAIMED #id <title> - 5 min (receiver has not claimed: not watching,
#                                    busy, or offline)          [also 15 and 60]
#
# This poller is the TRIGGER, not the worker. On wake the agent drains and
# CLAIMS via interagent_call (MCP).
#
# THE CLAIM IS THE ACKNOWLEDGEMENT ─────────────────────────────────────────────
# This poller stamps NOTHING. Two earlier builds tried to make the poller prove
# delivery and both were refuted: on MSYS/Git-Bash a write into a pipe whose
# read end is held open but never read SUCCEEDS for 65,536 bytes, so no local
# probe — fd test, 1-byte write, SIGUSR1 challenge — can prove a live reader.
# An orphan poller would therefore stamp a false DELIVERED. The acknowledgement
# that actually means something is the receiving AGENT's `claim`, which already
# exists in the schema (status / claimed_by / claimed_at / completed_at /
# result). There is no migration, no ack column, no pidfile lock, no challenge.
# Do not reintroduce any of them.
#
# NO SHARED STATE → ORPHANS ARE HARMLESS ──────────────────────────────────────
# All dedupe state lives in a PER-PROCESS directory keyed by this poller's own
# pid, deleted on exit (stale ones older than a day are swept at start). Two
# pollers therefore never share state and an orphan can steal nothing: whatever
# it "sees" is invisible to the live poller, which re-announces it. A freshly
# armed poller re-announcing still-unclaimed mail is INTENDED — a message the
# agent never claimed SHOULD come back. The one exception is untagged broadcasts
# (to_target 'any', no project ref), which agents deliberately never claim: those
# are announced only while younger than INTERAGENT_BROADCAST_HOURS (24) so old
# broadcasts do not replay on every re-arm.
#
# ORPHAN TERMINATION ──────────────────────────────────────────────────────────
#   - per-poll `kill -0 $PPID` (PPID becomes 1 when the parent exits, and
#     `kill -0 1` fails), with the parent's identity pinned by its cmdline so a
#     recycled MSYS pid does not keep a dead parent "alive";
#   - INTERAGENT_MAX_LIFETIME_S (default 0 = unlimited). The Claude Code arm
#     command passes 2100 because the Monitor tool caps at 30 min and leaves its
#     poller running. At expiry: one line `poller lifetime reached - re-arm`,
#     exit 0.
# Correctness does not depend on either: an orphan owns no shared state.
#
# A BROKEN HOP IS NEVER AN EMPTY POLL ─────────────────────────────────────────
# If ssh/psql fails, nothing is marked seen and no alarm state advances. One
# warning line on the FIRST failure, then at most one every
# INTERAGENT_ERR_QUIET_S (600), and one `recovered` line when it comes back.
#
# WHY NOT A HOOK ───────────────────────────────────────────────────────────────
# Hooks in this suite are local-only and cannot reach the gateway. This is NOT a
# hook — it's a Monitor-driven background process, so it MAY do network. It
# reads interagent_assignments over SSH (ssh deepthought -> pgvector).
#
# USAGE ────────────────────────────────────────────────────────────────────────
#   bash interagent-monitor-poll.sh          # loop forever, 5s interval
#   bash interagent-monitor-poll.sh 30       # loop forever, 30s interval
#   bash interagent-monitor-poll.sh --once   # single pass (for testing)
#
# ENV ──────────────────────────────────────────────────────────────────────────
#   INTERAGENT_MACHINE          agent inbox name (else .machine-id `machine:`)
#   INTERAGENT_PROJECT          project tag     (else git root / cwd basename)
#   INTERAGENT_MAX_LIFETIME_S   0 = unlimited (default); 2100 for Claude Code
#   INTERAGENT_SENT_HOURS       sender-side window, default 72
#   INTERAGENT_UNCLAIMED_MINS   alarm thresholds, default "5,15,60"
#   INTERAGENT_BROADCAST_HOURS  untagged-broadcast announce window, default 24
#   INTERAGENT_ERR_QUIET_S      min seconds between hop-failure warnings, 600
#   INTERAGENT_STATE_DIR        override the state root (tests)
#   INTERAGENT_PSQL_WRAPPER     replaces the ssh hop; reads SQL on stdin (tests)

set -uo pipefail

ARG="${1:-}"
ONCE=0
INTERVAL=5
case "$ARG" in
  --once)        ONCE=1 ;;
  ''|*[!0-9]*)   : ;;                 # empty or non-numeric -> keep default
  *)             INTERVAL="$ARG" ;;
esac

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROCESS_JS="${INTERAGENT_PROCESS_JS:-$SELF_DIR/interagent-monitor-process.js}"

MACHINE="${INTERAGENT_MACHINE:-}"
if [[ -z "$MACHINE" ]]; then
  MACHINE=$(sed -n 's/^machine:[[:space:]]*//p' /c/dev/.machine-id 2>/dev/null | head -1)
fi
MACHINE="${MACHINE:-unknown}"

PROJECT="${INTERAGENT_PROJECT:-}"
if [[ -z "$PROJECT" ]]; then
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$GIT_ROOT" ]]; then PROJECT=$(basename "$GIT_ROOT"); else PROJECT=$(basename "$(pwd)"); fi
fi

# The SQL travels on psql's stdin, so no remote shell ever sees these values —
# but they are also interpolated into SQL string literals, and a name is an
# identifier, not free text. Refuse anything that is not one.
IDENT_RE='^[A-Za-z0-9._-]+$'
if ! [[ "$MACHINE" =~ $IDENT_RE ]]; then
  echo "interagent-monitor-poll: refusing machine name [$MACHINE] - must match $IDENT_RE" >&2
  exit 2
fi
if ! [[ "$PROJECT" =~ $IDENT_RE ]]; then
  echo "interagent-monitor-poll: refusing project name [$PROJECT] - must match $IDENT_RE" >&2
  exit 2
fi

SENT_HOURS="${INTERAGENT_SENT_HOURS:-72}"
UNCLAIMED_MINS="${INTERAGENT_UNCLAIMED_MINS:-5,15,60}"
BROADCAST_HOURS="${INTERAGENT_BROADCAST_HOURS:-24}"
ERR_QUIET_S="${INTERAGENT_ERR_QUIET_S:-600}"
MAX_LIFETIME_S="${INTERAGENT_MAX_LIFETIME_S:-0}"
[[ "$SENT_HOURS"      =~ ^[0-9]+$ ]] || SENT_HOURS=72
[[ "$BROADCAST_HOURS" =~ ^[0-9]+$ ]] || BROADCAST_HOURS=24
[[ "$ERR_QUIET_S"     =~ ^[0-9]+$ ]] || ERR_QUIET_S=600
[[ "$MAX_LIFETIME_S"  =~ ^[0-9]+$ ]] || MAX_LIFETIME_S=0

# ── per-process state ────────────────────────────────────────────────────────
STATE_ROOT="${INTERAGENT_STATE_DIR:-}"
if [[ -z "$STATE_ROOT" ]]; then
  STATE_ROOT=$(printf '%s' "${LOCALAPPDATA:-${TEMP:-/tmp}}/claude-interagent" | tr '\\' '/')
fi
mkdir -p "$STATE_ROOT" 2>/dev/null

# Sweep per-process dirs left behind by pollers that were SIGKILLed (Monitor
# teardown) and never ran their EXIT trap. A day is well past any session.
find "$STATE_ROOT" -maxdepth 1 -type d -name 'proc-*' -mtime +0 -exec rm -rf {} + 2>/dev/null

MAIN_PID=$$
PROC_DIR="$STATE_ROOT/proc-${MACHINE}-${PROJECT}-${MAIN_PID}"
mkdir -p "$PROC_DIR" 2>/dev/null

cleanup_proc_dir() {
  # MSYS bash runs an inherited EXIT trap when a command-substitution subshell
  # exits, and $$ still reports the MAIN shell's pid there. BASHPID is
  # per-subshell and is the only safe discriminator.
  [[ "${BASHPID:-$$}" != "$MAIN_PID" ]] && return 0
  rm -rf "$PROC_DIR" 2>/dev/null
  return 0
}
trap cleanup_proc_dir EXIT

# ── stdout ───────────────────────────────────────────────────────────────────
# Operational lines go to STDOUT: only stdout becomes a Monitor chat event, and
# a warning the agent cannot see is not a warning. A failed write means the
# reader is gone, which is a reason to exit.
say() {
  ( trap '' PIPE; printf '%s\n' "$1" >&1 ) 2>/dev/null
}

# ── parent watch ─────────────────────────────────────────────────────────────
PPID0="$PPID"
PPID0_CMD=""
PPID_WATCH=0
if [[ "$PPID0" != "1" && "$PPID0" != "0" ]] && kill -0 "$PPID0" 2>/dev/null; then
  PPID0_CMD=$(tr '\0' ' ' < "/proc/$PPID0/cmdline" 2>/dev/null | head -c 200)
  [[ -n "$PPID0_CMD" ]] && PPID_WATCH=1
fi

parent_gone() {
  if [[ "$PPID_WATCH" == "1" ]]; then
    kill -0 "$PPID0" 2>/dev/null || return 0
    local now_cmd
    now_cmd=$(tr '\0' ' ' < "/proc/$PPID0/cmdline" 2>/dev/null | head -c 200)
    [[ "$now_cmd" != "$PPID0_CMD" ]] && return 0   # pid recycled onto something else
  fi
  return 1
}

# ── SQL ──────────────────────────────────────────────────────────────────────
# Constant for the life of the process (no ack ids, no cursor), so build it once.
sql_quote() { printf "%s" "$1" | sed "s/'/''/g"; }
M_SQL=$(sql_quote "$MACHINE")
P_SQL=$(sql_quote "$PROJECT")

SQL_FILE="$PROC_DIR/poll.sql"
cat > "$SQL_FILE" <<EOF
WITH params AS (
  SELECT '${M_SQL}'::text AS machine,
         '${P_SQL}'::text AS project,
         ${SENT_HOURS}::int AS sent_hours
),
inbox AS (
  SELECT 'inbox'::text AS event,
         a.id, a.title, a.from_agent, a.to_target, a.status, a.claimed_by,
         NULL::text AS result,
         a.context_refs AS refs,
         a.claimed_at, a.completed_at, a.created_at
  FROM interagent_assignments a, params p
  WHERE a.status = 'pending'
    AND a.claimed_by IS NULL
    AND (a.to_target = p.machine OR a.to_target = 'any')
    AND a.created_at > now() - make_interval(hours => a.ttl_hours)
    AND (
      NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.context_refs::jsonb, '[]'::jsonb)) r
        WHERE r->>'type' = 'project'
      )
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements(COALESCE(a.context_refs::jsonb, '[]'::jsonb)) r
        WHERE r->>'type' = 'project' AND r->>'id' = p.project
      )
    )
),
sent AS (
  SELECT 'sent'::text AS event,
         a.id, a.title, a.from_agent, a.to_target, a.status, a.claimed_by,
         left(a.result, 200) AS result,
         a.context_refs AS refs,
         a.claimed_at, a.completed_at, a.created_at
  FROM interagent_assignments a, params p
  WHERE a.from_agent = p.machine
    AND a.created_at > now() - make_interval(hours => p.sent_hours)
)
SELECT json_build_object(
         'now', now(),
         'rows', COALESCE(json_agg(t), '[]'::json)
       )
FROM (SELECT * FROM inbox UNION ALL SELECT * FROM sent) t;
EOF

ERR_FILE="$PROC_DIR/psql.err"

# ── poll ─────────────────────────────────────────────────────────────────────
ERR_STREAK=0
LAST_ERR_AT=-1          # -1, not 0: at SECONDS=0 the FIRST failure must warn

# 0 = a payload was handled, 1 = hop failure, 9 = stdout is gone
poll_once() {
  local out rc
  : > "$ERR_FILE"
  if [[ -n "${INTERAGENT_PSQL_WRAPPER:-}" ]]; then
    out=$(bash "$INTERAGENT_PSQL_WRAPPER" < "$SQL_FILE" 2>"$ERR_FILE"); rc=$?
  else
    out=$(ssh -o ConnectTimeout=8 -o BatchMode=yes deepthought \
            "docker exec -i pgvector psql -U postgres homelab -At -f -" \
            < "$SQL_FILE" 2>"$ERR_FILE"); rc=$?
  fi

  # An empty body is a FAILURE, not an empty inbox: the query always returns
  # exactly one json_build_object row, even when nothing matches.
  local hop_bad=0
  [[ $rc -ne 0 || -z "$out" ]] && hop_bad=1
  if [[ $hop_bad -eq 1 ]]; then
    hop_failed "$rc"
    return 1
  fi

  hop_recovered

  printf '%s' "$out" | \
    MACHINE="$MACHINE" PROJECT="$PROJECT" PROC_DIR="$PROC_DIR" \
    UNCLAIMED_MINS="$UNCLAIMED_MINS" BROADCAST_HOURS="$BROADCAST_HOURS" \
    node "$PROCESS_JS"
  rc=$?
  [[ $rc -eq 9 ]] && return 9        # process.js saw EPIPE: the reader is gone
  if [[ $rc -ne 0 ]]; then
    hop_failed "$rc"                 # malformed payload — same "never silent" rule
    return 1
  fi
  return 0
}

hop_failed() {
  local rc="$1" detail
  ERR_STREAK=$((ERR_STREAK + 1))
  if [[ $LAST_ERR_AT -lt 0 ]] || (( SECONDS - LAST_ERR_AT >= ERR_QUIET_S )); then
    LAST_ERR_AT=$SECONDS
    detail=$(tr -d '\r' < "$ERR_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' | head -1)
    [[ -z "$detail" ]] && detail="no output (rc=$rc)"
    say "INTERAGENT WARN: poll failed (${ERR_STREAK}x) - $detail  [inbox NOT checked; nothing marked seen]"
  fi
}

hop_recovered() {
  if [[ $ERR_STREAK -gt 0 ]]; then
    say "INTERAGENT recovered: poll succeeded after ${ERR_STREAK} failure(s)"
    ERR_STREAK=0
    LAST_ERR_AT=-1
  fi
}

if [[ "$ONCE" -eq 1 ]]; then
  poll_once
  exit 0
fi

while true; do
  if parent_gone; then
    exit 0
  fi
  if [[ "$MAX_LIFETIME_S" -gt 0 ]] && (( SECONDS >= MAX_LIFETIME_S )); then
    say "INTERAGENT poller lifetime reached (${MAX_LIFETIME_S}s) - re-arm with: monitor interagent"
    exit 0
  fi
  poll_once
  [[ $? -eq 9 ]] && exit 0
  sleep "$INTERVAL"
done
