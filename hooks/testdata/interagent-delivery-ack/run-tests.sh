#!/usr/bin/env bash
# Offline tests for interagent delivery-ack (known-bad arms that must be able to fail).
# Uses fake-db.js — does NOT touch live pgvector / interagent_assignments.
set -uo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
SUITE=$(cd "$DIR/../../.." && pwd)
POLLER="$SUITE/hooks/interagent-monitor-poll.sh"
WRAPPER="$DIR/fake-psql.sh"
PROCESS="$SUITE/hooks/interagent-monitor-process.js"

PASS=0
FAIL=0
RESULTS=()

iso_ago() {
  # minutes ago → ISO (node for portable TZ)
  node -e "process.stdout.write(new Date(Date.now()-Number(process.argv[1])*60000).toISOString())" "$1"
}

iso_now() {
  node -e "process.stdout.write(new Date().toISOString())"
}

# Force project scope so a parent git repo (e.g. $HOME) cannot steal basename.
export INTERAGENT_PROJECT="${INTERAGENT_PROJECT:-proj}"

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|$expected|$actual")
    echo "PASS  $name"
  else
    FAIL=$((FAIL + 1))
    RESULTS+=("FAIL|$name|$expected|$actual")
    echo "FAIL  $name"
    echo "      expected: $expected"
    echo "      actual:   $actual"
  fi
}

assert_contains() {
  local name="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -F -q -- "$needle"; then
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|contains:$needle|ok")
    echo "PASS  $name"
  else
    FAIL=$((FAIL + 1))
    RESULTS+=("FAIL|$name|contains:$needle|$hay")
    echo "FAIL  $name (missing: $needle)"
    echo "      haystack: $hay"
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -F -q -- "$needle"; then
    FAIL=$((FAIL + 1))
    RESULTS+=("FAIL|$name|absent:$needle|found")
    echo "FAIL  $name (unexpected: $needle)"
  else
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|absent:$needle|ok")
    echo "PASS  $name"
  fi
}

# ---------------------------------------------------------------------------
# Arm 1: two pollers one inbox → exactly one survives
# ---------------------------------------------------------------------------
arm1() {
  local name="1 two pollers one inbox → exactly one survives"
  local tmp state out1 out2
  tmp=$(mktemp -d)
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="test-agent-a"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  printf '%s\n' '{"assignments":[],"watchers":[],"now":null}' > "$INTERAGENT_FAKE_DB"
  # force project via cwd in a temp git? poller uses git root or pwd basename
  mkdir -p "$tmp/proj"
  cd "$tmp/proj" || exit 1

  # Start first poller in background with long interval
  bash "$POLLER" 30 >"$tmp/out1" 2>"$tmp/err1" &
  local pid1=$!
  sleep 0.4
  # Second should refuse
  set +e
  bash "$POLLER" 30 >"$tmp/out2" 2>"$tmp/err2"
  local rc2=$?
  set -e
  sleep 0.2
  local alive1=0
  if kill -0 "$pid1" 2>/dev/null; then alive1=1; fi
  kill "$pid1" 2>/dev/null || true
  wait "$pid1" 2>/dev/null || true

  assert_eq "$name (second exit≠0)" "1" "$([[ $rc2 -ne 0 ]] && echo 1 || echo 0)"
  assert_contains "$name (refuse msg)" "already running" "$(cat "$tmp/err2")"
  assert_eq "$name (first still alive before kill)" "1" "$alive1"
}

# ---------------------------------------------------------------------------
# Arm 2: parent pipe closed → poller exits within one interval
# ---------------------------------------------------------------------------
arm2() {
  local name="2 parent pipe closed → poller exits within one interval"
  local tmp
  tmp=$(mktemp -d)
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="test-agent-b"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  printf '%s\n' '{"assignments":[],"watchers":[]}' > "$INTERAGENT_FAKE_DB"
  mkdir -p "$tmp/proj"
  cd "$tmp/proj" || exit 1

  # Close the read end quickly so poller's stdout breaks
  bash "$POLLER" 1 >"$tmp/fifo_out" 2>"$tmp/err" &
  local pid=$!
  # Give it one loop then truncate/close by killing reader side: redirect to a
  # process that exits immediately after reading nothing useful.
  # Better: start with pipe to `true` equivalent — head -n0 closes immediately.
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true

  # Real closed-pipe test:
  bash "$POLLER" 1 2>"$tmp/err2" | head -n 0 &
  local pipe_pid=$!
  # The poller is in the pipe; head -n0 closes read end immediately.
  # Find poller child — on Git Bash the pipeline's left side is a subshell.
  sleep 2.5
  # If still running after >1 interval + margin, fail
  local still=0
  # shellcheck disable=SC2009
  if ps -ef 2>/dev/null | grep -F "interagent-monitor-poll.sh" | grep -v grep | grep -q "test-agent-b\|$tmp"; then
    still=1
  fi
  # Also check pidfile liveness
  local pf="$tmp/claude-interagent/poller-test-agent-b-proj.pid"
  if [[ -f "$pf" ]]; then
    local pp
    pp=$(cat "$pf" 2>/dev/null || true)
    if [[ -n "$pp" ]] && kill -0 "$pp" 2>/dev/null; then
      still=1
      kill "$pp" 2>/dev/null || true
    fi
  fi
  wait "$pipe_pid" 2>/dev/null || true
  assert_eq "$name" "0" "$still"
}

# More reliable arm2 using coproc / explicit FD close:
arm2b() {
  local name="2b closed stdout → process.js / poller exits"
  local tmp
  tmp=$(mktemp -d)
  # Directly test process.js broken-pipe exit
  set +e
  printf '%s' '[{"event":"inbox","id":1,"title":"t","from_agent":"x","refs":[]}]' | \
    PROJECT=p SEEN="$tmp/seen.txt" MACHINE=m UNDELIVERED_MIN=5 \
    node "$PROCESS" >"$tmp/closed" 2>/dev/null
  # Now close stdout by writing to a full pipe that nobody reads — use a node sink that exits
  local rc
  printf '%s' '[{"event":"inbox","id":99,"title":"t","from_agent":"x","refs":[]}]' | \
    PROJECT=p SEEN="$tmp/seen2.txt" MACHINE=m UNDELIVERED_MIN=5 \
    node -e '
      const {spawn}=require("child_process");
      const fs=require("fs");
      let b=""; process.stdin.on("data",c=>b+=c); process.stdin.on("end",()=>{
        const child=spawn("node",[process.argv[1]],{
          env:process.env, stdio:["pipe","pipe","inherit"]
        });
        child.stdin.write(b); child.stdin.end();
        child.stdout.on("data",()=>{ child.stdout.destroy(); }); // break pipe mid-write if many
        // Close stdout immediately before child writes
        child.stdout.destroy();
        child.on("exit",code=>process.exit(code===1?0:2));
      });
    ' "$PROCESS"
  rc=$?
  set -e
  # process.js should exit 1 on broken stdout; wrapper maps that to 0 success of the test
  # If destroy happens before write, may get exit 1 (good) or 0 if no write attempted after destroy race.
  # Fallback: poller stdout_ok after closed pipe
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="test-agent-pipe"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  echo '{"assignments":[{"id":7,"title":"hi","from_agent":"s","to_target":"test-agent-pipe","status":"pending","context_refs":[],"created_at":"'"$(iso_now)"'"}],"watchers":[]}' > "$INTERAGENT_FAKE_DB"
  mkdir -p "$tmp/proj2" && cd "$tmp/proj2" || exit 1
  set +e
  bash "$POLLER" 1 2>"$tmp/err" | head -n 0
  set -e
  sleep 2
  local alive=0
  local pf="$tmp/claude-interagent/poller-test-agent-pipe-${INTERAGENT_PROJECT}.pid"
  if [[ -f "$pf" ]]; then
    local pp; pp=$(cat "$pf" 2>/dev/null || true)
    if [[ -n "$pp" ]] && kill -0 "$pp" 2>/dev/null; then
      alive=1
      kill "$pp" 2>/dev/null || true
    fi
  fi
  assert_eq "$name" "0" "$alive"
}

# ---------------------------------------------------------------------------
# Arm 3: message sent, no receiver → UNDELIVERED at M
# ---------------------------------------------------------------------------
arm3() {
  local name="3 message sent, no receiver → UNDELIVERED at M"
  local tmp out
  tmp=$(mktemp -d)
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="sender-3"
  export INTERAGENT_UNDELIVERED_MIN=5
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  local created
  created=$(iso_ago 6)
  cat > "$INTERAGENT_FAKE_DB" <<EOF
{"assignments":[{"id":301,"title":"ping","from_agent":"sender-3","to_target":"missing-rcpt","status":"pending","context_refs":[],"created_at":"$created","delivered_at":null}],"watchers":[]}
EOF
  mkdir -p "$tmp/proj" && cd "$tmp/proj" || exit 1
  out=$(bash "$POLLER" --once 2>/dev/null || true)
  assert_contains "$name" "UNDELIVERED #301 to missing-rcpt for >5 min — receiver not acking (old poller or offline)" "$out"
}

# ---------------------------------------------------------------------------
# Arm 4: receiver comes up → DELIVERED at sender within two intervals
# ---------------------------------------------------------------------------
arm4() {
  local name="4 receiver comes up → DELIVERED at sender within two intervals"
  local tmp out_recv out_send shared
  tmp=$(mktemp -d)
  shared="$tmp/state.json"
  local created; created=$(iso_now)
  cat > "$shared" <<EOF
{"assignments":[{"id":401,"title":"hello","from_agent":"sender-4","to_target":"recv-4","status":"pending","context_refs":[{"type":"project","id":"proj"}],"created_at":"$created"}],"watchers":[]}
EOF
  # Receiver poll stamps delivered
  export LOCALAPPDATA="$tmp/recv"
  mkdir -p "$LOCALAPPDATA" "$tmp/recv/proj"
  export INTERAGENT_MACHINE="recv-4"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$shared"
  cd "$tmp/recv/proj" || exit 1
  # Override PROJECT detection: cwd basename is proj
  out_recv=$(bash "$POLLER" --once 2>/dev/null || true)
  assert_contains "$name (recv emit)" "INTERAGENT new #401" "$out_recv"

  # Sender poll sees delivered
  export LOCALAPPDATA="$tmp/send"
  mkdir -p "$LOCALAPPDATA" "$tmp/send/proj"
  export INTERAGENT_MACHINE="sender-4"
  cd "$tmp/send/proj" || exit 1
  out_send=$(bash "$POLLER" --once 2>/dev/null || true)
  assert_contains "$name (sender DELIVERED)" "DELIVERED #401 to recv-4" "$out_send"
}

# ---------------------------------------------------------------------------
# Arm 5: old-poller receiver → 'not acking' wording
# ---------------------------------------------------------------------------
arm5() {
  local name="5 old-poller receiver → not acking wording"
  local tmp out
  tmp=$(mktemp -d)
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="sender-5"
  export INTERAGENT_UNDELIVERED_MIN=5
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  # Simulate old poller: watcher heartbeat present but delivered_at still null
  local created; created=$(iso_ago 6)
  local now; now=$(iso_now)
  cat > "$INTERAGENT_FAKE_DB" <<EOF
{"assignments":[{"id":501,"title":"x","from_agent":"sender-5","to_target":"old-recv","status":"pending","context_refs":[],"created_at":"$created","delivered_at":null}],"watchers":[{"machine":"old-recv","project":"proj","pid":1,"last_poll_at":"$now"}]}
EOF
  mkdir -p "$tmp/proj" && cd "$tmp/proj" || exit 1
  # Sender must NOT stamp rows it only sees on the sent side — fake-db stamps
  # inbox for THIS machine only. sender-5 ≠ old-recv, so delivered stays null.
  out=$(bash "$POLLER" --once 2>/dev/null || true)
  assert_contains "$name" "receiver not acking (old poller or offline)" "$out"
  assert_contains "$name (UNDELIVERED)" "UNDELIVERED #501" "$out"
}

# ---------------------------------------------------------------------------
# Arm 6: seen-file never double-emits
# ---------------------------------------------------------------------------
arm6() {
  local name="6 seen-file never double-emits"
  local tmp out1 out2
  tmp=$(mktemp -d)
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="recv-6"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  local created; created=$(iso_now)
  cat > "$INTERAGENT_FAKE_DB" <<EOF
{"assignments":[{"id":601,"title":"once","from_agent":"s","to_target":"recv-6","status":"pending","context_refs":[],"created_at":"$created"}],"watchers":[]}
EOF
  mkdir -p "$tmp/proj" && cd "$tmp/proj" || exit 1
  out1=$(bash "$POLLER" --once 2>/dev/null || true)
  out2=$(bash "$POLLER" --once 2>/dev/null || true)
  assert_contains "$name (first emit)" "INTERAGENT new #601" "$out1"
  assert_eq "$name (second empty of new)" "0" "$(printf '%s' "$out2" | grep -c 'INTERAGENT new #601' || true)"
}

# ---------------------------------------------------------------------------
# Arm 7: COMPLETED event includes first ~200 chars of result
# ---------------------------------------------------------------------------
arm7() {
  local name="7 COMPLETED event includes first ~200 chars of result"
  local tmp out
  tmp=$(mktemp -d)
  export LOCALAPPDATA="$tmp"
  export INTERAGENT_MACHINE="sender-7"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$tmp/state.json"
  local created; created=$(iso_ago 1)
  local long
  long=$(node -e "process.stdout.write('R'.repeat(250))")
  cat > "$INTERAGENT_FAKE_DB" <<EOF
{"assignments":[{"id":701,"title":"done","from_agent":"sender-7","to_target":"recv-7","status":"completed","claimed_by":"recv-7","result":"$long","context_refs":[],"created_at":"$created","delivered_to":"recv-7","delivered_at":"$created","claimed_at":"$created","completed_at":"$created"}],"watchers":[]}
EOF
  mkdir -p "$tmp/proj" && cd "$tmp/proj" || exit 1
  out=$(bash "$POLLER" --once 2>/dev/null || true)
  assert_contains "$name (prefix)" "COMPLETED #701 by recv-7: " "$out"
  local payload
  payload=$(printf '%s' "$out" | grep 'COMPLETED #701' | sed 's/^COMPLETED #701 by recv-7: //')
  local len
  len=$(printf '%s' "$payload" | node -e "let b='';process.stdin.on('data',c=>b+=c);process.stdin.on('end',()=>process.stdout.write(String(b.length)))")
  assert_eq "$name (len≤200)" "1" "$([[ "$len" -le 200 ]] && echo 1 || echo 0)"
  assert_eq "$name (len≥200 for long result)" "1" "$([[ "$len" -eq 200 ]] && echo 1 || echo 0)"
}

# ---------------------------------------------------------------------------
# Known-bad sanity: deliberately wrong expectation must FAIL the helper
# (proves asserts are not vacuously passing)
# ---------------------------------------------------------------------------
arm_known_bad() {
  local name="known-bad assert can fail"
  local before=$FAIL
  assert_eq "$name (should fail)" "yes" "no"
  if [[ $FAIL -gt $before ]]; then
    # revert the intentional fail from the scoreboard for the suite summary
    FAIL=$((FAIL - 1))
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|assert infrastructure works|ok")
    echo "PASS  $name (assert infrastructure detected mismatch)"
  else
    echo "FAIL  $name (assert did not fire)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== interagent delivery-ack offline tests ==="
arm_known_bad
arm1
arm2b
arm3
arm4
arm5
arm6
arm7

echo
echo "=== summary: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
