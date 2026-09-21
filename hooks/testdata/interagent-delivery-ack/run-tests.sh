#!/usr/bin/env bash
# Offline tests for interagent delivery-ack.
#
# Uses fake-db.js — NEVER touches live pgvector / interagent_assignments, never
# opens a network connection, never applies the migration.
#
# Two phases:
#   PHASE 1  every arm runs against the real source and must pass.
#   PHASE 2  each mutant is a deliberately broken COPY of the source; the arm
#            that owns it must FAIL, cleanly (rc=1) and inside the timeout. A
#            mutant that survives, or that only hangs, fails the suite — a hang
#            is not a test result.
#
# Every arm is invoked by the runner (ARMS below is the single source of truth)
# and each runs in its own process under `timeout`, so no arm can wedge the run.
#
#   bash run-tests.sh                 # full suite
#   bash run-tests.sh --arm <name>    # one arm (what the mutant phase calls)
#   bash run-tests.sh --list          # arm names

set -uo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
SUITE=$(cd "$DIR/../../.." && pwd)
WRAPPER="$DIR/fake-psql.sh"
POLLER="${POLLER:-$SUITE/hooks/interagent-monitor-poll.sh}"
PROCESS="${PROCESS:-$SUITE/hooks/interagent-monitor-process.js}"
ARM_TIMEOUT="${ARM_TIMEOUT:-150}"

PASS=0
FAIL=0

# ── assertions ───────────────────────────────────────────────────────────────
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1)); echo "  PASS  $name"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL  $name"
    echo "        expected: [$expected]"
    echo "        actual:   [$actual]"
  fi
}

assert_contains() {
  local name="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -F -q -- "$needle"; then
    PASS=$((PASS + 1)); echo "  PASS  $name"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL  $name (missing: $needle)"
    echo "        haystack: $(printf '%s' "$hay" | head -c 600)"
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -F -q -- "$needle"; then
    FAIL=$((FAIL + 1)); echo "  FAIL  $name (unexpected: $needle)"
    echo "        haystack: $(printf '%s' "$hay" | head -c 600)"
  else
    PASS=$((PASS + 1)); echo "  PASS  $name"
  fi
}

# ── harness helpers ──────────────────────────────────────────────────────────
iso_ago() { node -e "process.stdout.write(new Date(Date.now()-Number(process.argv[1])*60000).toISOString())" "$1"; }
iso_now() { node -e "process.stdout.write(new Date().toISOString())"; }

TMP=""; STATE=""; SEEN_F=""; ACK_F=""; PID_F=""

setup_env() {          # $1 = machine, $2 = full|legacy (default full)
  TMP=$(mktemp -d)
  export LOCALAPPDATA="$TMP"
  export INTERAGENT_MACHINE="$1"
  export INTERAGENT_FAKE_SCHEMA="${2:-full}"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$TMP/state.json"
  export INTERAGENT_PROJECT="${INTERAGENT_PROJECT:-proj}"
  mkdir -p "$TMP/proj" && cd "$TMP/proj" || exit 1
  STATE="$TMP/claude-interagent"
  SEEN_F="$STATE/seen-${1}-${INTERAGENT_PROJECT}.txt"
  ACK_F="$STATE/ack-${1}-${INTERAGENT_PROJECT}.txt"
  PID_F="$STATE/poller-${1}-${INTERAGENT_PROJECT}.pid"
}

db_write() { printf '%s\n' "$1" > "$INTERAGENT_FAKE_DB"; }

db_field() {           # $1 = id, $2 = field
  node -e '
    const fs=require("fs");
    const s=JSON.parse(fs.readFileSync(process.env.INTERAGENT_FAKE_DB,"utf8"));
    const a=(s.assignments||[]).find(x=>String(x.id)===process.argv[1]);
    process.stdout.write(String(a && a[process.argv[2]] != null ? a[process.argv[2]] : "null"));
  ' "$1" "$2"
}

file_lines() { awk 'NF{n++} END{print n+0}' "$1" 2>/dev/null || echo 0; }

# Wait for a CONDITION, never for a fixed number of seconds. One poll costs an
# ssh-wrapper plus a node start, so on a loaded Windows box a sleep that is
# generous today is short tomorrow — and an arm that samples early reports a
# false PASS. These return non-zero on timeout and let the assertion say so.
WAIT_MAX="${WAIT_MAX:-45}"

wait_for_file() {      # $1 = path, $2 = seconds
  local deadline=$((SECONDS + ${2:-$WAIT_MAX}))
  while (( SECONDS < deadline )); do
    [[ -s "$1" ]] && return 0
    sleep 0.5
  done
  return 1
}

wait_for_line() {      # $1 = file, $2 = needle, $3 = seconds
  local deadline=$((SECONDS + ${3:-$WAIT_MAX}))
  while (( SECONDS < deadline )); do
    grep -F -q -- "$2" "$1" 2>/dev/null && return 0
    sleep 0.5
  done
  return 1
}

wait_until_gone() {    # $1 = pid, $2 = seconds
  local deadline=$((SECONDS + ${2:-$WAIT_MAX}))
  while (( SECONDS < deadline )); do
    kill -0 "$1" 2>/dev/null || return 0
    sleep 0.5
  done
  return 1
}

wait_for_db() {        # $1 = id, $2 = field, $3 = expected, $4 = seconds
  local deadline=$((SECONDS + ${4:-$WAIT_MAX}))
  while (( SECONDS < deadline )); do
    [[ "$(db_field "$1" "$2")" == "$3" ]] && return 0
    sleep 0.5
  done
  return 1
}

kill_pidfile() {
  local p; p=$(head -n1 "$PID_F" 2>/dev/null | awk '{print $1}')
  [[ -n "$p" ]] && kill -9 "$p" 2>/dev/null
  return 0
}

pidfile_alive() {
  local p; p=$(head -n1 "$PID_F" 2>/dev/null | awk '{print $1}')
  [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null && echo 1 || echo 0
}

feed_process() {       # $1 = json payload; uses SEEN_F/ACK_F; prints stdout
  printf '%s' "$1" | PROJECT="$INTERAGENT_PROJECT" SEEN="$SEEN_F" ACK_FILE="$ACK_F" \
    SINCE_FILE="$STATE/since-test.txt" \
    MACHINE="$INTERAGENT_MACHINE" UNDELIVERED_MIN=5 INTERVAL_SECS=5 node "$PROCESS" 2>/dev/null
}

# The since-file must carry the SERVER clock, not ours.
arm_since_is_server_clock() {
  setup_env "since-m"
  mkdir -p "$STATE"; : > "$SEEN_F"; : > "$ACK_F"
  feed_process '{"schema":"full","now":"2001-02-03T04:05:06.000Z","stamped":[],"watchers":[],"rows":[]}' >/dev/null
  assert_eq "since: process.js persists the server clock verbatim" \
    "2001-02-03T04:05:06.000Z" "$(cat "$STATE/since-test.txt" 2>/dev/null)"
}

# ── arms ─────────────────────────────────────────────────────────────────────

# The platform experiment, kept as a permanent test: it is the evidence for
# which reader-gone probe the poller is allowed to rely on under Git-Bash/MSYS.
arm_probe() {
  local t; t=$(mktemp -d)
  cat > "$t/p.sh" <<'EOF'
exec 9>&1
printf 'fd1exists=%s\n' "$([ -e /proc/self/fd/1 ] && echo YES || echo NO)" >> "$LOG"
if ( trap '' PIPE; printf 'X' >&9 ) 2>/dev/null; then printf 'write=OK\n' >> "$LOG"; else printf 'write=FAIL\n' >> "$LOG"; fi
if ( printf '' >&9 ) 2>/dev/null; then printf 'zerobyte=OK\n' >> "$LOG"; else printf 'zerobyte=FAIL\n' >> "$LOG"; fi
EOF
  LOG="$t/dead.log" bash "$t/p.sh" | head -n 0
  LOG="$t/live.log" bash "$t/p.sh" | cat > /dev/null

  # Documented platform facts. If any of these flip, the poller's probe choice
  # has to be revisited — that is why they are asserted, not commented.
  assert_contains "probe: /proc/self/fd/1 still 'exists' with the reader gone (so it is useless)" \
    "fd1exists=YES" "$(cat "$t/dead.log")"
  assert_contains "probe: a zero-byte write does NOT detect a dead reader (Grok's bug)" \
    "zerobyte=OK" "$(cat "$t/dead.log")"
  assert_contains "probe: a real 1-byte write DOES detect a dead reader" \
    "write=FAIL" "$(cat "$t/dead.log")"
  assert_contains "probe: a real 1-byte write succeeds with a live reader" \
    "write=OK" "$(cat "$t/live.log")"

  # And the poller must not have regressed to the probes that do not work.
  assert_not_contains "probe: poller does not use the no-op zero-byte write" \
    "printf '' >&1" "$(cat "$POLLER")"
  assert_contains "probe: poller has a real-write probe" "write_probe()" "$(cat "$POLLER")"
  rm -rf "$t"
}

# BLOCK-1: a poller whose reader is gone must stamp nothing and see nothing.
arm_no_stamp_on_failed_write() {
  setup_env "rcvr-ns"
  db_write '{"assignments":[{"id":801,"title":"lost","from_agent":"s","to_target":"rcvr-ns","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  ( bash "$POLLER" 1 2>/dev/null | head -n 0 ) & local orph=$!
  # Wait for the poller to take the lock, then for it to DIE on the failed write.
  # Waiting on its exit is what makes the absence assertions below trustworthy:
  # every write it was ever going to make has happened by then.
  wait_for_file "$PID_F" 30
  local orph_pid; orph_pid=$(head -n1 "$PID_F" 2>/dev/null | awk '{print $1}')
  assert_eq "no-stamp: the poller with a dead reader exits on its own" "0" \
    "$([[ -n "$orph_pid" ]] && wait_until_gone "$orph_pid" 40 && echo 0 || echo 1)"
  kill_pidfile; kill "$orph" 2>/dev/null; wait "$orph" 2>/dev/null

  assert_eq "no-stamp: delivered_at stays NULL after a failed write" "null" "$(db_field 801 delivered_at)"
  assert_eq "no-stamp: delivered_to stays NULL after a failed write" "null" "$(db_field 801 delivered_to)"
  assert_eq "no-stamp: id never enters the seen-file" "0" "$(file_lines "$SEEN_F")"
  assert_eq "no-stamp: id never enters the ack-file" "0" "$(file_lines "$ACK_F")"
}

# The stamp is deferred to the poll AFTER the line actually landed.
arm_stamp_next_poll() {
  setup_env "rcvr-sn"
  db_write '{"assignments":[{"id":802,"title":"ok","from_agent":"s","to_target":"rcvr-sn","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  local out1 out2 rc1 rc2
  out1=$(bash "$POLLER" --once 2>"$TMP/p1.err"); rc1=$?
  assert_eq "stamp: poll 1 actually ran (rc=0)" "0|" "$rc1|$(grep -F 'already running' "$TMP/p1.err" || true)"
  assert_contains "stamp: poll 1 emits the inbox line" "INTERAGENT new #802" "$out1"
  assert_eq "stamp: poll 1 does NOT stamp (the write only just happened)" "null" "$(db_field 802 delivered_at)"
  assert_eq "stamp: poll 1 queues the id for acking" "1" "$(file_lines "$ACK_F")"

  out2=$(bash "$POLLER" --once 2>"$TMP/p2.err"); rc2=$?
  assert_eq "stamp: poll 2 actually ran (rc=0)" "0|" "$rc2|$(grep -F 'already running' "$TMP/p2.err" || true)"
  assert_eq "stamp: poll 2 stamps delivered_to" "rcvr-sn" "$(db_field 802 delivered_to)"
  assert_not_contains "stamp: poll 2 does not re-emit the line" "INTERAGENT new #802" "$out2"
  assert_eq "stamp: ack-file is drained after the stamp" "0" "$(file_lines "$ACK_F")"
}

# The verifier's end-to-end repro, kept permanently: an orphan on a dead pipe
# must not lock the live session out and must not poison the row.
arm_orphan_e2e() {
  setup_env "rcvr-e2e"
  db_write '{"assignments":[],"watchers":[]}'
  ( bash "$POLLER" 1 2>/dev/null | head -n 0 ) & local orph=$!
  wait_for_file "$PID_F" 30
  local orph_pid; orph_pid=$(head -n1 "$PID_F" 2>/dev/null | awk '{print $1}')
  assert_eq "orphan-e2e: orphan is alive and holds the lock" "1" "$(pidfile_alive)"

  # The live session arms its own poller — it must win the lock.
  local live_out="$TMP/live.out"
  bash "$POLLER" 1 >"$live_out" 2>"$TMP/live.err" & local live=$!
  assert_eq "orphan-e2e: the orphan gives the lock up when challenged" "0" \
    "$(wait_until_gone "$orph_pid" 40 && echo 0 || echo 1)"
  assert_eq "orphan-e2e: the live poller is running (session is NOT left with zero pollers)" \
    "1" "$(kill -0 "$live" 2>/dev/null && echo 1 || echo "0 — live poller stderr: [$(tr '\n' ';' < "$TMP/live.err" 2>/dev/null)]")"

  # Now the message arrives. Only the live poller should see and ack it.
  node -e '
    const fs=require("fs"), p=process.env.INTERAGENT_FAKE_DB;
    const s=JSON.parse(fs.readFileSync(p,"utf8"));
    s.assignments.push({id:901,title:"URGENT",from_agent:"sender",to_target:"rcvr-e2e",
      status:"pending",context_refs:[],created_at:new Date().toISOString()});
    fs.writeFileSync(p,JSON.stringify(s,null,2));'
  wait_for_line "$live_out" "INTERAGENT new #901" 40
  wait_for_db 901 delivered_to "rcvr-e2e" 40
  kill "$live" 2>/dev/null; kill_pidfile; wait "$live" 2>/dev/null
  kill "$orph" 2>/dev/null; wait "$orph" 2>/dev/null
  # Belt and braces: a surviving orphan spins with a node start per second and
  # would slow every later arm down enough to make them flaky.
  [[ -n "$orph_pid" ]] && kill -9 "$orph_pid" 2>/dev/null

  assert_contains "orphan-e2e: the LIVE session received the message" "INTERAGENT new #901" "$(cat "$live_out")"
  assert_eq "orphan-e2e: delivered_to names the machine that actually received it" \
    "rcvr-e2e" "$(db_field 901 delivered_to)"
  assert_eq "orphan-e2e: the id is recorded once, not raced twice" \
    "1" "$(grep -c '^901$' "$SEEN_F" 2>/dev/null || echo 0)"
}

# BLOCK-2 / spec C: a genuine LIVE poller is respected.
arm_lock_refuses_live() {
  setup_env "lock-live"
  db_write '{"assignments":[],"watchers":[]}'
  bash "$POLLER" 2 >"$TMP/a.out" 2>"$TMP/a.err" & local first=$!
  sleep 2
  # Bounded: if the lock ever stops checking liveness the second poller starts a
  # loop of its own and would otherwise hang the suite. rc=124 is then a clean
  # FAIL of this assertion, not a hang.
  local rc2
  timeout 15 bash "$POLLER" 2 >"$TMP/b.out" 2>"$TMP/b.err"; rc2=$?
  [[ $rc2 -eq 124 ]] && kill_pidfile
  local alive1; alive1=$(kill -0 "$first" 2>/dev/null && echo 1 || echo 0)
  # The holder answers the challenge on its next loop tick, which can land after
  # the newcomer has already given up and exited — so wait for the line, do not
  # assume it is there the instant the newcomer returns.
  wait_for_line "$TMP/a.out" "INTERAGENT poller alive" 30
  kill "$first" 2>/dev/null; kill_pidfile; wait "$first" 2>/dev/null

  assert_eq "lock: the second poller refuses (rc=1)" "1" "$rc2"
  assert_contains "lock: it says why" "already running" "$(cat "$TMP/b.err")"
  assert_eq "lock: the live holder survives the challenge" "1" "$alive1"
  assert_contains "lock: the challenged holder proved its pipe with a real write" \
    "INTERAGENT poller alive" "$(cat "$TMP/a.out")"
}

# A pid that is alive but is NOT this script (MSYS pid reuse) must be reaped.
arm_lock_reaps_foreign() {
  setup_env "lock-foreign"
  db_write '{"assignments":[],"watchers":[]}'
  mkdir -p "$STATE"
  sleep 30 & local foreign=$!
  printf '%s %s\n' "$foreign" "interagent-monitor-poll:lock-foreign:proj" > "$PID_F"
  local out rc
  out=$(bash "$POLLER" --once 2>&1); rc=$?
  kill "$foreign" 2>/dev/null; wait "$foreign" 2>/dev/null

  assert_eq "lock: a live FOREIGN pid does not lock the session out (rc=0)" "0" "$rc"
  assert_contains "lock: the reap is logged, not silent" "reaping stale/foreign pidfile" "$out"
}

arm_lock_reaps_dead() {
  setup_env "lock-dead"
  db_write '{"assignments":[],"watchers":[]}'
  mkdir -p "$STATE"
  printf '%s %s\n' "999999" "interagent-monitor-poll:lock-dead:proj" > "$PID_F"
  local out rc
  out=$(bash "$POLLER" --once 2>&1); rc=$?
  assert_eq "lock: a dead pid is reaped (rc=0)" "0" "$rc"
  assert_contains "lock: the reap is logged" "reaping stale/foreign pidfile" "$out"
}

# Spec C, the idle half: an orphan with no mail at all must still die.
arm_orphan_idle_exits() {
  setup_env "idle-orph"
  db_write '{"assignments":[],"watchers":[]}'
  # Parent lives long enough for the poller to pin its identity, then exits —
  # exactly what an expired Monitor task leaves behind.
  bash -c "bash '$POLLER' 1 >'$TMP/idle.out' 2>'$TMP/idle.err' & sleep 8" &
  local wrapper=$!
  wait_for_file "$PID_F" 30
  local pid; pid=$(head -n1 "$PID_F" 2>/dev/null | awk '{print $1}')
  assert_eq "idle-orphan: poller started under a live parent" "1" \
    "$([[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && echo 1 || echo 0)"
  wait "$wrapper" 2>/dev/null
  local still; still=$(wait_until_gone "$pid" 40 && echo 0 || echo 1)
  [[ "$still" == "1" ]] && kill -9 "$pid" 2>/dev/null
  assert_eq "idle-orphan: it exits once its reader's parent is gone" "0" "$still"
}

# Spec B: sender visibility.
arm_sender_delivered() {
  local shared; shared=$(mktemp -d)/state.json
  local created; created=$(iso_now)
  printf '%s\n' '{"assignments":[{"id":401,"title":"hello","from_agent":"sender-4","to_target":"recv-4","status":"pending","context_refs":[{"type":"project","id":"proj"}],"created_at":"'"$created"'"}],"watchers":[]}' > "$shared"

  setup_env "recv-4"; export INTERAGENT_FAKE_DB="$shared"
  local r1 r2
  r1=$(bash "$POLLER" --once 2>/dev/null)
  r2=$(bash "$POLLER" --once 2>/dev/null)   # second poll performs the stamp
  assert_contains "sender: receiver emits the inbox line" "INTERAGENT new #401" "$r1"

  setup_env "sender-4"; export INTERAGENT_FAKE_DB="$shared"
  local s1; s1=$(bash "$POLLER" --once 2>/dev/null)
  assert_contains "sender: DELIVERED reaches the sender" "DELIVERED #401 to recv-4" "$s1"
}

arm_undelivered_alarm() {
  setup_env "sender-3"
  db_write '{"assignments":[{"id":301,"title":"ping","from_agent":"sender-3","to_target":"missing-rcpt","status":"pending","context_refs":[],"created_at":"'"$(iso_ago 6)"'","delivered_at":null}],"watchers":[]}'
  local out; out=$(bash "$POLLER" --once 2>/dev/null)
  assert_contains "alarm: the required wording is used" \
    "UNDELIVERED #301 to missing-rcpt for >5 min — receiver not acking (old poller or offline)" "$out"
  assert_contains "alarm: with no watcher row it says so" "[watcher: none]" "$out"
}

# Spec D: the heartbeat has a reader, and it feeds the alarm wording.
arm_watcher_stale() {
  setup_env "sender-w"
  db_write '{"assignments":[{"id":505,"title":"x","from_agent":"sender-w","to_target":"old-recv","status":"pending","context_refs":[],"created_at":"'"$(iso_ago 20)"'","delivered_at":null}],"watchers":[{"machine":"old-recv","project":"proj","pid":1,"interval_secs":5,"last_poll_at":"'"$(iso_ago 9)"'"}]}'
  local out; out=$(bash "$POLLER" --once 2>/dev/null)
  assert_contains "watcher: a heartbeat older than 3 intervals reads as stale" "[watcher: stale" "$out"
  assert_not_contains "watcher: a stale heartbeat is not reported live" "[watcher: live" "$out"

  setup_env "sender-w2"
  db_write '{"assignments":[{"id":506,"title":"x","from_agent":"sender-w2","to_target":"fresh-recv","status":"pending","context_refs":[],"created_at":"'"$(iso_ago 20)"'","delivered_at":null}],"watchers":[{"machine":"fresh-recv","project":"proj","pid":1,"interval_secs":5,"last_poll_at":"'"$(iso_now)"'"}]}'
  out=$(bash "$POLLER" --once 2>/dev/null)
  assert_contains "watcher: a fresh heartbeat reads as live" "[watcher: live" "$out"
}

# A delivered row is never an alarm — the cry-wolf guard.
arm_no_alarm_when_delivered() {
  setup_env "sender-na"
  local old; old=$(iso_ago 70)
  db_write '{"assignments":[{"id":601,"title":"x","from_agent":"sender-na","to_target":"recv-na","status":"pending","context_refs":[],"created_at":"'"$old"'","delivered_to":"recv-na","delivered_at":"'"$old"'"}],"watchers":[]}'
  local out; out=$(bash "$POLLER" --once 2>/dev/null)
  assert_contains "no-alarm: the delivered row is reported as DELIVERED" "DELIVERED #601" "$out"
  assert_not_contains "no-alarm: a delivered row raises no UNDELIVERED" "UNDELIVERED" "$out"
}

# Spec B: COMPLETED carries the result and is emitted exactly once, ever.
arm_completed_once() {
  setup_env "sender-7"
  mkdir -p "$STATE"; : > "$SEEN_F"; : > "$ACK_F"
  local long; long=$(node -e "process.stdout.write('R'.repeat(250))")
  local payload
  payload=$(node -e '
    const long="R".repeat(250);
    process.stdout.write(JSON.stringify({schema:"full",now:new Date().toISOString(),
      stamped:[],watchers:[],rows:[{event:"sent",id:701,title:"done",from_agent:"sender-7",
      to_target:"recv-7",status:"completed",claimed_by:"recv-7",result:long.slice(0,200),
      refs:[],delivered_to:"recv-7",delivered_at:new Date().toISOString(),
      claimed_at:new Date().toISOString(),completed_at:new Date().toISOString(),
      created_at:new Date().toISOString()}]}));')
  local o1 o2 o3 total
  o1=$(feed_process "$payload")
  o2=$(feed_process "$payload")
  o3=$(feed_process "$payload")
  total=$(printf '%s\n%s\n%s\n' "$o1" "$o2" "$o3" | grep -c 'COMPLETED #701' || true)

  assert_contains "completed: the result reaches the sender" "COMPLETED #701 by recv-7: RRR" "$o1"
  assert_eq "completed: emitted exactly once across three polls" "1" "$total"
  assert_not_contains "completed: poll 2 is silent about it" "COMPLETED #701" "$o2"
  assert_not_contains "completed: poll 3 is silent about it" "COMPLETED #701" "$o3"
  local len
  len=$(printf '%s' "$o1" | grep 'COMPLETED #701' | sed 's/^COMPLETED #701 by recv-7: //' | tr -d '\n' | wc -c)
  assert_eq "completed: the result is projected to 200 chars" "1" "$([[ "$len" -le 200 ]] && echo 1 || echo 0)"
}

arm_dedupe() {
  setup_env "recv-6"
  db_write '{"assignments":[{"id":611,"title":"once","from_agent":"s","to_target":"recv-6","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  local o1 o2
  o1=$(bash "$POLLER" --once 2>/dev/null)
  o2=$(bash "$POLLER" --once 2>/dev/null)
  assert_contains "dedupe: first poll emits" "INTERAGENT new #611" "$o1"
  assert_not_contains "dedupe: second poll does not" "INTERAGENT new #611" "$o2"
}

# BLOCK-3: a new poller on an OLD schema degrades loudly, never silently.
arm_old_schema_warns() {
  setup_env "legacy-rcvr" legacy
  db_write '{"assignments":[{"id":950,"title":"still works","from_agent":"s","to_target":"legacy-rcvr","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  bash "$POLLER" 1 >"$TMP/legacy.out" 2>"$TMP/legacy.err" & local p=$!
  wait_for_line "$TMP/legacy.out" "WARN: interagent schema not migrated" 40
  wait_for_line "$TMP/legacy.out" "INTERAGENT new #950" 40
  # Let it poll a few more times so "emitted once, not every poll" is a real test.
  sleep 6
  kill "$p" 2>/dev/null; kill_pidfile; wait "$p" 2>/dev/null
  local out; out=$(cat "$TMP/legacy.out")

  assert_contains "old-schema: one VISIBLE warning on stdout, not a silent blackout" \
    "WARN: interagent schema not migrated" "$out"
  assert_eq "old-schema: the warning is emitted once, not every poll" \
    "1" "$(printf '%s' "$out" | grep -c 'schema not migrated' || true)"
  assert_contains "old-schema: inbox delivery still works" "INTERAGENT new #950" "$out"
  assert_not_contains "old-schema: no sender lines are invented without the columns" "DELIVERED" "$out"
}

# F4: MACHINE / PROJECT are safe against quotes, backticks and $( ).
arm_injection() {
  # Backtick, $( ) and a single quote. No double quote: it is illegal in an NTFS
  # filename and the state files are named after these values.
  local nasty='proj`id`$(whoami)'"'"'x'
  TMP=$(mktemp -d)
  export LOCALAPPDATA="$TMP"
  export INTERAGENT_MACHINE="$nasty"
  export INTERAGENT_PROJECT="$nasty"
  export INTERAGENT_FAKE_SCHEMA=full
  export INTERAGENT_FAKE_DB="$TMP/state.json"
  # A wrapper that records the exact SQL the poller produced, then delegates.
  cat > "$TMP/spy.sh" <<EOF
tee "$TMP/sql.txt" | bash "$WRAPPER"
EOF
  export INTERAGENT_PSQL_WRAPPER="$TMP/spy.sh"
  mkdir -p "$TMP/proj" && cd "$TMP/proj" || exit 1
  db_write '{"assignments":[{"id":999,"title":"inj","from_agent":"s","to_target":"'"$nasty"'","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  local out; out=$(bash "$POLLER" --once 2>/dev/null)

  assert_contains "injection: the literal survives intact end to end" "INTERAGENT new #999" "$out"
  assert_contains "injection: the SQL carries the raw backticks, un-expanded" '`id`' "$(cat "$TMP/sql.txt")"
  assert_contains "injection: the SQL carries \$( ) un-expanded" 'whoami' "$(cat "$TMP/sql.txt")"
  assert_contains "injection: the single quote is SQL-escaped by doubling" "''" "$(cat "$TMP/sql.txt")"
  assert_not_contains "injection: the remote command is never built by interpolation" \
    'psql -U postgres homelab -At -c' "$(cat "$POLLER")"
}

# T3: launched through a login shell the cwd is $HOME, so an inferred project
# becomes the home directory's basename and the poller watches nothing, healthily.
arm_project_scope_guard() {
  TMP=$(mktemp -d)
  export LOCALAPPDATA="$TMP"
  export INTERAGENT_MACHINE="scope-m"
  export INTERAGENT_FAKE_SCHEMA=full
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$TMP/state.json"
  db_write '{"assignments":[],"watchers":[]}'
  local out
  # cwd = $HOME with no INTERAGENT_PROJECT: exactly what `bash -lc` gives you.
  out=$(cd "$HOME" && env -u INTERAGENT_PROJECT bash "$POLLER" --once 2>&1)
  assert_contains "scope: an inferred home-directory project is called out" \
    "interagent project scope inferred as" "$out"
  assert_contains "scope: it names the remedy" "Set INTERAGENT_PROJECT" "$out"

  export INTERAGENT_PROJECT=proj
  mkdir -p "$TMP/proj" && cd "$TMP/proj" || exit 1
  out=$(bash "$POLLER" --once 2>&1)
  assert_not_contains "scope: an explicit INTERAGENT_PROJECT warns about nothing" \
    "project scope inferred" "$out"
}

# T4: a poller started with the wrong INTERAGENT_MACHINE drains another session's
# inbox. It must at least never write "delivered to me" onto that mail.
arm_wrong_machine_never_stamps() {
  setup_env "wrong-m"
  db_write '{"assignments":[{"id":770,"title":"not yours","from_agent":"s","to_target":"someone-else","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  mkdir -p "$STATE"
  # An ack-file carried over from a renamed profile: the id is queued for
  # stamping even though the row is addressed to somebody else.
  printf '770\n' > "$ACK_F"
  bash "$POLLER" --once >/dev/null 2>&1
  assert_eq "wrong-machine: a row addressed elsewhere is never stamped" "null" "$(db_field 770 delivered_to)"
  assert_eq "wrong-machine: delivered_at stays NULL too" "null" "$(db_field 770 delivered_at)"

  # Control: the same flow DOES stamp a row that really is ours.
  setup_env "right-m"
  db_write '{"assignments":[{"id":771,"title":"yours","from_agent":"s","to_target":"right-m","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}'
  mkdir -p "$STATE"; printf '771\n' > "$ACK_F"
  bash "$POLLER" --once >/dev/null 2>&1
  assert_eq "wrong-machine: control — a row addressed to us IS stamped" "right-m" "$(db_field 771 delivered_to)"
}

# T5: the SSH hop to deepthought drops roughly every 30 min. A failed query must
# never be mistaken for an empty inbox.
arm_hop_failure_is_not_empty_poll() {
  local mark

  # $1 = label, $2 = machine, $3 = wrapper body. Fresh state each time, with an
  # id queued for stamping and a known since/seen, so "nothing durable moved" is
  # checkable rather than vacuous.
  hop_case() {
    local label="$1" m="$2" body="$3"
    setup_env "$m"
    mark=$(iso_now)
    db_write '{"assignments":[{"id":880,"title":"waiting","from_agent":"'"$m"'","to_target":"'"$m"'","status":"pending","context_refs":[],"created_at":"'"$(iso_ago 90)"'","delivered_at":null}],"watchers":[]}'
    mkdir -p "$STATE"
    printf '880\n' > "$ACK_F"
    printf '%s' "$mark" > "$STATE/since-${m}-proj.txt"
    printf 'PRE-EXISTING\n' > "$SEEN_F"
    printf '%s\n' "$body" > "$TMP/hop.sh"
    export INTERAGENT_PSQL_WRAPPER="$TMP/hop.sh"
    local out; out=$(bash "$POLLER" --once 2>"$TMP/hop.err")

    assert_not_contains "hop[$label]: no inbox lines" "INTERAGENT new" "$out"
    assert_contains "hop[$label]: the failure is reported" "interagent poll failed" "$(cat "$TMP/hop.err")"
    assert_eq "hop[$label]: the ack-file is NOT drained" "880" "$(tr -d '\n\r' < "$ACK_F")"
    assert_eq "hop[$label]: the since high-water is NOT advanced" "$mark" "$(cat "$STATE/since-${m}-proj.txt")"
    assert_eq "hop[$label]: the seen-file is NOT appended to" "1" "$(file_lines "$SEEN_F")"
    assert_eq "hop[$label]: nothing is stamped" "null" "$(db_field 880 delivered_at)"
  }

  # (a) the hop is down for everything, including the schema probe.
  hop_case "hop down" "hop-a" 'cat > /dev/null
echo "ssh: connect to host deepthought port 22: Connection timed out" >&2
exit 255'

  # (b) the probe answers, then the hop drops under the real query — this is the
  #     case the sentinel check exists for, and the one a poller meets after
  #     ~30 min of healthy polling.
  hop_case "drops after the probe" "hop-b" 'in=$(cat)
case "$in" in
  *information_schema.columns*) echo full ;;
  *) echo "ssh: connection closed by remote host" >&2; exit 255 ;;
esac'

  # (c) exit 0 with output that is not an envelope: a truncated or interleaved
  #     reply must not be mistaken for an empty inbox either.
  hop_case "truncated reply, exit 0" "hop-c" 'in=$(cat)
case "$in" in
  *information_schema.columns*) echo full ;;
  *) echo "psql: server closed the connection unexpectedly" ;;
esac'

  # And after BLIND_AFTER consecutive failures the session is told, once.
  setup_env "hop-m"
  db_write '{"assignments":[],"watchers":[]}'
  cat > "$TMP/deadhop.sh" <<'EOF'
cat > /dev/null
echo "ssh: connect to host deepthought port 22: Connection timed out" >&2
exit 255
EOF
  export INTERAGENT_PSQL_WRAPPER="$TMP/deadhop.sh"
  export INTERAGENT_BLIND_AFTER=2
  bash "$POLLER" 1 >"$TMP/blind.out" 2>/dev/null & local p=$!
  wait_for_line "$TMP/blind.out" "watch is BLIND" 40
  sleep 5    # keep polling, so "told once" is a real test
  kill "$p" 2>/dev/null; kill_pidfile; wait "$p" 2>/dev/null
  assert_contains "hop: the session is told its watch is BLIND" \
    "WARN: interagent watch is BLIND" "$(cat "$TMP/blind.out")"
  assert_eq "hop: told once, not every poll" "1" \
    "$(grep -c 'watch is BLIND' "$TMP/blind.out" || true)"
}

# T7: the Grok dispatcher and an interactive poller are both live watchers of one
# machine inbox, with separate state dirs. Each must refuse while the other runs.
arm_dispatcher_tui_conflict() {
  setup_env "pair-m"
  db_write '{"assignments":[],"watchers":[]}'
  mkdir -p "$TMP/grok-interagent"
  # A live process whose /proc/<pid>/cmdline genuinely names the dispatcher, so
  # the identity check has something true to find. A stub rather than the real
  # script: production code does not get a test-only flag.
  printf 'sleep 45\n' > "$TMP/interagent-dispatch.sh"
  bash "$TMP/interagent-dispatch.sh" &
  local fake=$!
  sleep 1
  printf '%s interagent-dispatch:pair-m\n' "$fake" > "$TMP/grok-interagent/dispatch.pid"
  local out rc
  out=$(bash "$POLLER" --once 2>&1); rc=$?
  kill "$fake" 2>/dev/null; wait "$fake" 2>/dev/null

  assert_eq "pair: the poller refuses while the dispatcher is live (rc=1)" "1" "$rc"
  assert_contains "pair: it names the dispatcher" "Grok dispatcher is already watching" "$out"
  assert_contains "pair: it prints the pid" "pid=$fake" "$out"
  assert_contains "pair: it prints the cmdline" "interagent-dispatch.sh" "$out"
  assert_contains "pair: it says how to resolve it" "--stop" "$out"

  # A stale dispatch.pid over a dead pid must NOT lock the poller out.
  printf '999999 interagent-dispatch:pair-m\n' > "$TMP/grok-interagent/dispatch.pid"
  out=$(bash "$POLLER" --once 2>&1); rc=$?
  assert_eq "pair: a dead dispatcher pid does not lock the poller out" "0" "$rc"

  # The other direction: the real dispatcher must refuse while an interactive
  # poller holds its pidfile.
  rm -f "$TMP/grok-interagent/dispatch.pid"
  mkdir -p "$STATE"
  printf 'sleep 45\n' > "$TMP/interagent-monitor-poll.sh"
  bash "$TMP/interagent-monitor-poll.sh" & local stub=$!
  sleep 1
  printf '%s interagent-monitor-poll:pair-m:proj\n' "$stub" > "$PID_F"
  out=$(LOCALAPPDATA="$TMP" INTERAGENT_MACHINE=pair-m \
        bash "$SUITE/config/grok/interagent-dispatch.sh" 5 2>&1); rc=$?
  assert_eq "pair: the dispatcher refuses while a poller is live (rc=1)" "1" "$rc"
  assert_contains "pair: it names the poller" "interactive monitor poller is already watching" "$out"
  assert_contains "pair: it prints the poller's pid" "pid=$stub" "$out"

  # A recycled pid is not a poller: a foreign live pid must not block it.
  printf 'sleep 45\n' > "$TMP/foreign.sh"
  bash "$TMP/foreign.sh" & local foreign=$!
  sleep 1
  printf '%s interagent-monitor-poll:pair-m:proj\n' "$foreign" > "$PID_F"
  out=$(LOCALAPPDATA="$TMP" INTERAGENT_MACHINE=pair-m \
        bash "$SUITE/config/grok/interagent-dispatch.sh" --status 2>&1) || true
  assert_not_contains "pair: a foreign pid in the poller pidfile is ignored" \
    "interactive monitor poller is already watching" "$out"
  kill "$stub" "$foreign" 2>/dev/null
  rm -f "$PID_F"
}

# Proves the assertion helpers can actually fail.
arm_known_bad() {
  local before=$FAIL
  assert_eq "known-bad (this one is SUPPOSED to fail)" "yes" "no"
  if [[ $FAIL -gt $before ]]; then
    FAIL=$((FAIL - 1)); PASS=$((PASS + 1))
    echo "  PASS  known-bad: the assert infrastructure detected the mismatch"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  known-bad: the assert did not fire — every result above is worthless"
  fi
}

ARMS="probe no_stamp_on_failed_write stamp_next_poll orphan_e2e lock_refuses_live \
lock_reaps_foreign lock_reaps_dead orphan_idle_exits sender_delivered undelivered_alarm \
watcher_stale no_alarm_when_delivered completed_once dedupe old_schema_warns injection \
since_is_server_clock project_scope_guard wrong_machine_never_stamps \
hop_failure_is_not_empty_poll dispatcher_tui_conflict known_bad"

# ── single-arm mode ──────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' $ARMS
  exit 0
fi

if [[ "${1:-}" == "--arm" ]]; then
  arm="${2:?--arm needs a name}"
  if ! declare -F "arm_$arm" >/dev/null; then
    echo "no such arm: $arm" >&2; exit 2
  fi
  # No arm may leak a live poller into the next one. A leaked loop poller spins a
  # node start per second (slowing everything after it) and its pid can be
  # recycled onto a later arm's pidfile, where the identity check correctly sees
  # "a genuine live poller" and refuses that arm's poll. That is a real property
  # of the lock, so the fix belongs here, not in the poller.
  trap 'p=$(jobs -p 2>/dev/null); [[ -n "$p" ]] && kill $p 2>/dev/null; exit' EXIT
  "arm_$arm"
  echo "  [$arm] $PASS passed, $FAIL failed"
  [[ $FAIL -gt 0 ]] && exit 1
  exit 0
fi

# ── phase 1: the real source ─────────────────────────────────────────────────
echo "=== interagent delivery-ack — offline suite (no network, no live DB) ==="
echo
echo "--- phase 1: arms against the real source ---"
ARM_PASS=0
ARM_FAIL=0
FAILED_ARMS=""
for a in $ARMS; do
  echo "ARM $a"
  if timeout "$ARM_TIMEOUT" bash "$0" --arm "$a"; then
    ARM_PASS=$((ARM_PASS + 1))
  else
    rc=$?
    if [[ $rc -eq 124 ]]; then echo "  TIMEOUT after ${ARM_TIMEOUT}s"; fi
    ARM_FAIL=$((ARM_FAIL + 1)); FAILED_ARMS="$FAILED_ARMS $a"
  fi
done

# ── phase 2: mutants ─────────────────────────────────────────────────────────
# name | arm that owns it | file | sed expression
MUTANTS=(
  "stamp-on-failed-write|no_stamp_on_failed_write|process|s/if (delivered \&\& !r.delivered_at) freshAck.push(id);/if (!r.delivered_at) freshAck.push(id);/"
  "lock-skips-liveness|lock_refuses_live|poller|s|^  \[\[ \"\$cmd\" == \*interagent-monitor-poll.sh\* \]\]|  false|"
  "alarm-fires-for-a-delivered-row|no_alarm_when_delivered|process|s/^    if (!r.delivered_at) {/    if (true) {/"
  "COMPLETED-emitted-every-poll|completed_once|process|s/'COMPLETED-' + id/'COMPLETED-' + id + Math.random()/"
  "watcher-never-goes-stale|watcher_stale|process|s/^    ? w.stale\$/    ? false/"
  "reader-gone-check-removed|orphan_idle_exits|poller|s/^  if \[\[ \"\$PPID_WATCH\" == \"1\" \]\]; then\$/  if false; then/"
  "new-poller-on-old-schema-silent|old_schema_warns|poller|s/^  say \"\$msg\"\$/  :/"
  "hop-failure-treated-as-empty-poll|hop_failure_is_not_empty_poll|poller|s/^  if ! sql_reply_is_real; then\$/  if false; then/"
  # Range-addressed so it touches ONLY the stamp CTE's routing guard, not the
  # identical predicate in the inbox CTEs. "." stands in for the quote character
  # so the expression itself needs no nested quoting.
  "stamp-ignores-routing|wrong_machine_never_stamps|poller|/^stamp_delivered AS (/,/^  RETURNING a.id\$/ s/^    AND (a.to_target = p.machine OR a.to_target = .any.)\$/    AND true/"
  "project-scope-guess-is-silent|project_scope_guard|poller|s/^warn_project_once() {\$/warn_project_once() { return 0;/"
)

echo
echo "--- phase 2: mutants (each must be KILLED by its arm) ---"
MUT_ROWS=""
MUT_SURVIVED=0
for spec in "${MUTANTS[@]}"; do
  IFS='|' read -r mname marm mfile _ <<< "$spec"
  mexpr="${spec#*|*|*|}"
  mdir=$(mktemp -d)
  cp "$POLLER" "$mdir/interagent-monitor-poll.sh"
  cp "$PROCESS" "$mdir/interagent-monitor-process.js"
  target="$mdir/interagent-monitor-process.js"
  [[ "$mfile" == "poller" ]] && target="$mdir/interagent-monitor-poll.sh"

  before=$(md5sum "$target" | awk '{print $1}')
  sed -i "$mexpr" "$target"
  after=$(md5sum "$target" | awk '{print $1}')
  if [[ "$before" == "$after" ]]; then
    echo "  MUTANT $mname: SED DID NOT APPLY (the anchor moved) — treating as SURVIVED"
    MUT_ROWS="$MUT_ROWS\n| $mname | $marm | not applied | **NO** |"
    MUT_SURVIVED=$((MUT_SURVIVED + 1))
    rm -rf "$mdir"; continue
  fi

  set +e
  POLLER="$mdir/interagent-monitor-poll.sh" PROCESS="$mdir/interagent-monitor-process.js" \
    timeout "$ARM_TIMEOUT" bash "$0" --arm "$marm" > "$mdir/out.txt" 2>&1
  rc=$?
  set -e
  if [[ $rc -eq 1 ]]; then
    echo "  KILLED   $mname  (arm $marm failed cleanly, as it must)"
    MUT_ROWS="$MUT_ROWS\n| $mname | $marm | arm failed (rc=1) | **YES** |"
  elif [[ $rc -eq 124 ]]; then
    echo "  SURVIVED $mname  (arm $marm HUNG — a hang is not a test result)"
    MUT_ROWS="$MUT_ROWS\n| $mname | $marm | HUNG (rc=124) | **NO** |"
    MUT_SURVIVED=$((MUT_SURVIVED + 1))
  else
    echo "  SURVIVED $mname  (arm $marm still passed, rc=$rc)"
    MUT_ROWS="$MUT_ROWS\n| $mname | $marm | arm passed | **NO** |"
    MUT_SURVIVED=$((MUT_SURVIVED + 1))
  fi
  rm -rf "$mdir"
done

# ── report ───────────────────────────────────────────────────────────────────
echo
echo "=== mutant table ==="
echo "| mutant | owning arm | result | killed? |"
echo "|---|---|---|---|"
printf '%b\n' "$MUT_ROWS" | grep -v '^$'

echo
echo "=== summary ==="
echo "arms:    $ARM_PASS passed, $ARM_FAIL failed (of $((ARM_PASS + ARM_FAIL)))"
echo "mutants: $(( ${#MUTANTS[@]} - MUT_SURVIVED )) killed, $MUT_SURVIVED survived (of ${#MUTANTS[@]})"
[[ -n "$FAILED_ARMS" ]] && echo "failed arms:$FAILED_ARMS"

if [[ $ARM_FAIL -gt 0 || $MUT_SURVIVED -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
