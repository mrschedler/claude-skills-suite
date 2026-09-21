#!/usr/bin/env bash
# Offline tests for the interagent monitor poller (r3 — the claim is the ack).
#
# Uses fake-db.js. NEVER touches live pgvector, never opens a socket, never
# applies a migration (there is none).
#
# Two phases:
#   PHASE 1  every arm runs against the real source and must pass.
#   PHASE 2  each mutant is a deliberately broken COPY of the source; the arm
#            that owns it must FAIL, cleanly (rc=1) and inside the timeout. A
#            mutant that survives, or that only hangs, fails the suite — a hang
#            is not a test result.
#
# ARMS below is the single source of truth: every arm is invoked by the runner,
# each in its own process under `timeout`, so no arm can wedge the run.
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
    echo "        haystack: $(printf '%s' "$hay" | head -c 800)"
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -F -q -- "$needle"; then
    FAIL=$((FAIL + 1)); echo "  FAIL  $name (unexpected: $needle)"
    echo "        haystack: $(printf '%s' "$hay" | head -c 800)"
  else
    PASS=$((PASS + 1)); echo "  PASS  $name"
  fi
}

count_of() { printf '%s' "$2" | grep -F -c -- "$1" || true; }

# ── harness ──────────────────────────────────────────────────────────────────
# $1 = minutes offset from real now (may be negative — hence the env var: node
# reads a leading "-" argument as one of its own options).
iso_shift() {
  SHIFT_MIN="$1" node -e 'process.stdout.write(new Date(Date.now()+Number(process.env.SHIFT_MIN)*60000).toISOString())'
}

TMP=""; STATE=""

setup_env() {          # $1 = machine
  TMP=$(mktemp -d)
  STATE="$TMP/state"
  export INTERAGENT_MACHINE="$1"
  export INTERAGENT_PROJECT="${INTERAGENT_PROJECT:-proj}"
  export INTERAGENT_STATE_DIR="$STATE"
  export INTERAGENT_PSQL_WRAPPER="$WRAPPER"
  export INTERAGENT_FAKE_DB="$TMP/db.json"
  export INTERAGENT_PROCESS_JS="$PROCESS"
  export INTERAGENT_MAX_LIFETIME_S=0
  export INTERAGENT_ERR_QUIET_S=600
  unset INTERAGENT_FAKE_FAIL_FILE
  mkdir -p "$STATE" "$TMP/work" && cd "$TMP/work" || exit 1
}

db_write() { printf '%s\n' "$1" > "$INTERAGENT_FAKE_DB"; }
db_md5()   { md5sum "$INTERAGENT_FAKE_DB" | awk '{print $1}'; }

db_patch() {           # $1 = id, $2.. = key=value (value parsed as JSON if it parses)
  node -e '
    const fs=require("fs"), p=process.env.INTERAGENT_FAKE_DB;
    const s=JSON.parse(fs.readFileSync(p,"utf8"));
    const a=(s.assignments||[]).find(x=>String(x.id)===process.argv[1]);
    for(const kv of process.argv.slice(2)){
      const i=kv.indexOf("="); const k=kv.slice(0,i); let v=kv.slice(i+1);
      try{ v=JSON.parse(v); }catch(e){}
      a[k]=v;
    }
    fs.writeFileSync(p,JSON.stringify(s,null,2));
  ' "$@"
}

db_now() {             # $1 = ISO string for the fake database clock
  node -e '
    const fs=require("fs"), p=process.env.INTERAGENT_FAKE_DB;
    const s=JSON.parse(fs.readFileSync(p,"utf8"));
    s.now=process.argv[1];
    fs.writeFileSync(p,JSON.stringify(s,null,2));
  ' "$1"
}

poll_once_out() { bash "$POLLER" --once 2>/dev/null; }

teardown() { cd /; [[ -n "$TMP" ]] && rm -rf "$TMP"; return 0; }

# ═════════════════════════════════════════════════════════════════════════════
# ARM: the round-2 killer repro.
# An orphan poller whose stdout pipe is held open but NEVER READ runs alongside
# a live poller. On MSYS that orphan's writes succeed (64 KiB of pipe buffer),
# so it believes it delivered the message. Its state is per-process, so the live
# poller must STILL emit the message, exit 0, and neither may write to the DB.
# ═════════════════════════════════════════════════════════════════════════════
arm_orphan_no_steal() {
  setup_env rcvr
  db_write '{"assignments":[{"id":901,"title":"URGENT","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'
  local md5_before; md5_before=$(db_md5)

  # ORPHAN: `| sleep 60` holds the read end open and never reads it. Its writes
  # SUCCEED (MSYS gives a pipe 64 KiB of buffer), so it believes it delivered.
  # It is given a head start so that if state were shared it would win the race
  # deterministically — this arm must not depend on scheduling luck.
  ( INTERAGENT_MAX_LIFETIME_S=25 bash "$POLLER" 1 2>"$TMP/orph.err" | sleep 60 ) & local ORPH=$!
  sleep 5

  local orph_dir; orph_dir=$(ls -d "$STATE"/proc-* 2>/dev/null | head -1)
  assert_eq "orphan has its own per-process state dir" "1" "$(ls -d "$STATE"/proc-* 2>/dev/null | wc -l | tr -d ' ')"
  assert_contains "the orphan did mark the message seen in ITS OWN state" "901" "$(cat "$orph_dir/seen.txt" 2>/dev/null)"

  # LIVE poller, started while the orphan is alive and still polling.
  # Self-terminates so the arm can assert its exit status instead of killing it.
  INTERAGENT_MAX_LIFETIME_S=12 bash "$POLLER" 1 >"$TMP/live.out" 2>"$TMP/live.err" & local LIVE=$!
  wait $LIVE; local live_rc=$?
  local live_out; live_out=$(cat "$TMP/live.out")

  assert_contains "live poller emits the message despite the orphan" "INTERAGENT new #901" "$live_out"
  assert_eq       "live poller exits 0"                              "0" "$live_rc"
  assert_eq       "neither poller wrote to the DB"                   "$md5_before" "$(db_md5)"

  assert_eq "live poller removed its own state dir (the orphan's remains)" "1" \
    "$(ls -d "$STATE"/proc-* 2>/dev/null | wc -l | tr -d ' ')"

  local orph_pid; orph_pid=$(awk '{print $1}' "$orph_dir/owner" 2>/dev/null)
  [[ "$orph_pid" =~ ^[0-9]+$ ]] && kill -9 "$orph_pid" 2>/dev/null
  kill -9 $ORPH 2>/dev/null
  teardown
}

# ARM: a poller armed with the wrong machine name sees nothing and changes nothing.
arm_wrong_name() {
  setup_env rcvr
  db_write '{"assignments":[{"id":901,"title":"for rcvr","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'
  local md5_before; md5_before=$(db_md5)

  INTERAGENT_MACHINE=other-box bash "$POLLER" --once >"$TMP/wrong.out" 2>"$TMP/wrong.err"
  local wrong; wrong=$(cat "$TMP/wrong.out")
  assert_not_contains "wrong-name poller delivers nothing"   "INTERAGENT new"   "$wrong"
  assert_contains     "  ...but says whose inbox it watches" "machine=other-box" "$wrong"
  assert_eq           "wrong-name poller changes nothing"    "$md5_before" "$(db_md5)"

  # positive control: the right name does see it
  assert_contains "right-name poller does see it" "INTERAGENT new #901" "$(poll_once_out)"
  teardown
}

# ARM: on this machine $HOME is itself a git repo root, so the git-root
# inference resolves PROJECT to the home folder's name from any non-repo
# directory under it. The scope must therefore be impossible to miss — on
# stderr AND as the first stdout line, where the Monitor shows it — and
# INTERAGENT_PROJECT must override the inference outright.
arm_scope_banner_and_override() {
  setup_env rcvr
  db_write '{"assignments":[]}'

  # A "home directory" that is a git root, with a non-repo subdir inside it.
  mkdir -p "$TMP/homedir/scratch"
  git -C "$TMP/homedir" init -q 2>/dev/null
  cd "$TMP/homedir/scratch" || return 1

  local inferred
  inferred=$(INTERAGENT_PROJECT= bash "$POLLER" --once 2>"$TMP/b1.err")
  assert_contains "the inferred (wrong) scope is on STDOUT"    "project=homedir" "$inferred"
  assert_contains "  ...named as inferred, not chosen"         "source=git-root" "$inferred"
  assert_contains "  ...and on stderr too"                     "project=homedir" "$(cat "$TMP/b1.err")"

  local overridden
  overridden=$(INTERAGENT_PROJECT=ql-g3-enterprise bash "$POLLER" --once 2>/dev/null)
  assert_contains     "INTERAGENT_PROJECT overrides the git root" "project=ql-g3-enterprise" "$overridden"
  assert_contains     "  ...and says where it came from"          "source=INTERAGENT_PROJECT" "$overridden"
  assert_not_contains "  ...the git root is not used"             "project=homedir"           "$overridden"

  local rc
  INTERAGENT_PROJECT='bad`name`' bash "$POLLER" --once >/dev/null 2>&1; rc=$?
  assert_eq "an override is validated like MACHINE" "2" "$rc"
  teardown
}

# ARM (reviewer BLOCK 1): a directory's mtime does NOT move when files inside
# it are written, so an age-based sweep deletes the state of a live poller that
# has merely been quiet — and it loses its poll.sql with it, warning forever
# and never delivering again. Sweep by DEAD OWNER, never by age.
arm_stale_sweep_spares_live_dirs() {
  setup_env rcvr
  db_write '{"assignments":[]}'

  INTERAGENT_MAX_LIFETIME_S=26 bash "$POLLER" 1 >"$TMP/live.out" 2>"$TMP/live.err" & local LIVE=$!
  sleep 4
  local d; d=$(ls -d "$STATE"/proc-* 2>/dev/null | head -1)
  assert_eq "the live poller has a state dir" "1" "$(ls -d "$STATE"/proc-* 2>/dev/null | wc -l | tr -d ' ')"

  touch -d '2 days ago' "$d"          # exactly what a quiet live poller looks like
  INTERAGENT_MAX_LIFETIME_S=3 bash "$POLLER" 1 >/dev/null 2>&1   # a second poller sweeps
  assert_eq "a second poller leaves the live (but old-looking) dir alone" "1" \
    "$(ls -d "$d" 2>/dev/null | wc -l | tr -d ' ')"

  db_write '{"assignments":[{"id":901,"title":"after the sweep","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'
  wait $LIVE
  local out; out=$(cat "$TMP/live.out")
  assert_contains     "the live poller still delivers afterwards" "INTERAGENT new #901" "$out"
  assert_not_contains "  ...and was never blinded"                "poll failed"         "$out"
  teardown
}

# ARM (reviewer BLOCK 2): keying the state dir by pid alone and creating it with
# mkdir -p inherits whatever a previous process of that pid left behind — MSYS
# recycles small pids — and a pre-seeded seen-file swallows unclaimed mail. The
# decoy below is created by the SAME pid that then execs the poller, so this is
# deterministic rather than a race.
arm_proc_dir_starts_empty() {
  setup_env rcvr
  db_write '{"assignments":[{"id":901,"title":"must not be swallowed","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'

  local out
  out=$(bash -c 'D="$1/proc-$2-$3-$$"; mkdir -p "$D"; printf "901\n" > "$D/seen.txt"; exec bash "$4" --once' \
        _ "$STATE" "$INTERAGENT_MACHINE" "$INTERAGENT_PROJECT" "$POLLER" 2>/dev/null)
  assert_contains "a state dir pre-seeded under our own pid does not swallow the message" \
    "INTERAGENT new #901" "$out"
  teardown
}

# ARM: an owner file that cannot be read is UNKNOWN, not DEAD. A dir created
# this instant has no owner yet, and a truncated one looks identical — so
# treating "empty owner" as "owner dead" lets one poller's sweep delete a LIVE
# poller's state. (Which is also why the owner file is written once,
# atomically, and never rewritten per poll: a per-poll rewrite truncates first
# and opens exactly that window.)
arm_empty_owner_is_not_dead() {
  setup_env rcvr
  db_write '{"assignments":[]}'

  INTERAGENT_MAX_LIFETIME_S=22 bash "$POLLER" 1 >"$TMP/live.out" 2>"$TMP/live.err" & local LIVE=$!
  sleep 4
  local d; d=$(ls -d "$STATE"/proc-* 2>/dev/null | head -1)
  assert_eq "the live poller has a state dir" "1" "$(ls -d "$STATE"/proc-* 2>/dev/null | wc -l | tr -d ' ')"

  : > "$d/owner"                       # exactly what a truncate window looks like
  INTERAGENT_MAX_LIFETIME_S=3 bash "$POLLER" 1 >/dev/null 2>&1   # a second poller sweeps
  assert_eq "a second poller does not delete a live dir with an empty owner" "1" \
    "$(ls -d "$d" 2>/dev/null | wc -l | tr -d ' ')"

  db_write '{"assignments":[{"id":901,"title":"after the empty-owner sweep","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'
  wait $LIVE
  local out; out=$(cat "$TMP/live.out")
  assert_contains     "the live poller still delivers" "INTERAGENT new #901" "$out"
  assert_not_contains "  ...and never lost its state"  "state dir vanished"  "$out"
  teardown
}

# ARM (reviewer BLOCK 3): ConnectTimeout only bounds the TCP connect. A hop that
# connects and then hangs blocks the loop past even MAX_LIFETIME_S, so the hop
# needs a hard timeout — and a killed hop is a FAILURE, never an empty poll.
arm_hop_hangs() {
  setup_env rcvr
  db_write '{"assignments":[]}'
  printf 'cat > /dev/null\nsleep 20\n' > "$TMP/hang.sh"

  local t0 t1 out elapsed
  t0=$(date +%s)
  out=$(INTERAGENT_PSQL_WRAPPER="$TMP/hang.sh" INTERAGENT_HOP_TIMEOUT_S=4 \
        INTERAGENT_MAX_LIFETIME_S=3 timeout 60 bash "$POLLER" 1 2>/dev/null)
  t1=$(date +%s); elapsed=$((t1 - t0))

  assert_contains     "a hung hop is reported as a failure" "hop hung - killed after 4s" "$out"
  assert_not_contains "a hung hop is never a recovery"      "INTERAGENT recovered"       "$out"
  assert_eq "the hop does not outlive the poller's lifetime (took ${elapsed}s)" \
    "bounded" "$( [[ $elapsed -lt 15 ]] && echo bounded || echo unbounded )"
  teardown
}

# ARM (reviewer BLOCK 4): the startup seed that silences pre-existing
# claims/completions must use the DATABASE clock, like every other age here.
# The fake clock sits ten days ahead of this machine, so a local-clock seed
# replays history that should have been silent.
arm_seed_uses_db_clock() {
  setup_env sender
  local T=14400            # +10 days, in minutes
  db_write '{"now":"'"$(iso_shift $T)"'","assignments":[
    {"id":901,"title":"finished before we started","from_agent":"sender","to_target":"peer","status":"completed","claimed_by":"peer","result":"old news","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift $((T-60)))"'","claimed_at":"'"$(iso_shift $((T-50)))"'","completed_at":"'"$(iso_shift $((T-40)))"'"},
    {"id":902,"title":"claimed while we watch","from_agent":"sender","to_target":"peer2","status":"pending","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift $((T-1)))"'"}
  ]}'

  INTERAGENT_MAX_LIFETIME_S=16 bash "$POLLER" 1 >"$TMP/seed.out" 2>"$TMP/seed.err" & local P=$!
  sleep 6
  local during; during=$(cat "$TMP/seed.out")
  assert_not_contains "a claim from before the poller started is silent"      "CLAIMED #901"   "$during"
  assert_not_contains "a completion from before the poller started is silent" "COMPLETED #901" "$during"

  db_patch 902 'status="claimed"' 'claimed_by="peer2"' "claimed_at=\"$(iso_shift $T)\""
  wait $P
  local after; after=$(cat "$TMP/seed.out")
  assert_contains     "a claim made AFTER we started is announced" "CLAIMED #902 by peer2" "$after"
  assert_not_contains "  ...and #901 stayed silent throughout"     "#901"                  "$after"
  teardown
}

# ARM: an ssh hop failure is never an empty poll — warn on the FIRST failure,
# rate-limit after, mark nothing seen, and say so when it recovers.
arm_hop_failure_warns() {
  setup_env rcvr
  export INTERAGENT_FAKE_FAIL_FILE="$TMP/hop-down"
  : > "$INTERAGENT_FAKE_FAIL_FILE"
  db_write '{"assignments":[{"id":901,"title":"survives the outage","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'

  INTERAGENT_MAX_LIFETIME_S=26 bash "$POLLER" 1 >"$TMP/hop.out" 2>"$TMP/hop.err" & local P=$!
  sleep 9
  local during; during=$(cat "$TMP/hop.out")
  assert_contains     "first failing poll warns immediately" "INTERAGENT WARN: poll failed" "$during"
  assert_eq           "warning is rate-limited to one"       "1" "$(count_of "INTERAGENT WARN: poll failed" "$during")"
  assert_not_contains "nothing delivered while the hop is down" "INTERAGENT new #901" "$during"

  rm -f "$INTERAGENT_FAKE_FAIL_FILE"
  wait $P
  local after; after=$(cat "$TMP/hop.out")
  assert_contains "recovery is announced"                  "INTERAGENT recovered" "$after"
  assert_contains "the message survived the outage unseen" "INTERAGENT new #901"  "$after"
  teardown
}

# ARM: a reply that arrives half-written with a CLEAN exit status. rc is 0 and
# the body is non-empty, so only parsing it catches the failure. It must warn
# like any other dropped hop, deliver nothing, and — the part that bit an
# earlier draft of this file — must NOT be announced as a recovery, which
# flapped WARN/recovered twice a poll forever and reset the rate limit each time.
arm_hop_truncated_reply() {
  setup_env rcvr
  export INTERAGENT_FAKE_TRUNC_FILE="$TMP/hop-trunc"
  : > "$INTERAGENT_FAKE_TRUNC_FILE"
  db_write '{"assignments":[{"id":901,"title":"survives a half reply","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'

  INTERAGENT_MAX_LIFETIME_S=26 bash "$POLLER" 1 >"$TMP/tr.out" 2>"$TMP/tr.err" & local P=$!
  sleep 10
  local during; during=$(cat "$TMP/tr.out")
  assert_contains     "a truncated reply warns"            "INTERAGENT WARN: poll failed" "$during"
  assert_contains     "  ...naming what was wrong with it" "malformed reply"              "$during"
  assert_eq           "  ...once, not once per poll"       "1" "$(count_of "INTERAGENT WARN: poll failed" "$during")"
  assert_not_contains "a reply that never parsed is NOT a recovery" "INTERAGENT recovered" "$during"
  assert_not_contains "nothing is delivered from a half reply"      "INTERAGENT new #901"  "$during"

  rm -f "$INTERAGENT_FAKE_TRUNC_FILE"
  wait $P
  local after; after=$(cat "$TMP/tr.out")
  assert_contains "a whole reply IS a recovery"           "INTERAGENT recovered" "$after"
  assert_contains "the message survived the half replies" "INTERAGENT new #901"  "$after"
  teardown
}

# ARM: a re-armed poller re-announces what is still unclaimed, and goes quiet
# once the agent has claimed it. A claim that predates the poller is history.
arm_rearm_reannounces() {
  setup_env rcvr
  db_write '{"assignments":[
    {"id":901,"title":"unclaimed","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift -2)"'"},
    {"id":902,"title":"we sent this","from_agent":"rcvr","to_target":"peer","status":"claimed","claimed_by":"peer","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift -30)"'","claimed_at":"'"$(iso_shift -29)"'"}
  ]}'

  local first; first=$(poll_once_out)
  assert_contains     "first arm announces the unclaimed message" "INTERAGENT new #901" "$first"
  assert_not_contains "a claim older than the poller is history"  "CLAIMED #902"        "$first"

  local second; second=$(poll_once_out)
  assert_contains "re-arm re-announces it (the agent never claimed it)" "INTERAGENT new #901" "$second"

  db_patch 901 'status="claimed"' 'claimed_by="rcvr"' "claimed_at=\"$(iso_shift 0)\""
  local third; third=$(poll_once_out)
  assert_not_contains "once claimed, it stops coming back" "INTERAGENT new #901" "$third"
  teardown
}

# ARM: untagged broadcasts are announced only while fresh — agents deliberately
# never claim them, so without the window every re-arm replays them forever.
arm_broadcast_24h() {
  setup_env rcvr
  db_write '{"assignments":[
    {"id":10,"title":"fresh broadcast","from_agent":"sender","to_target":"any","status":"pending","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift -60)"'"},
    {"id":11,"title":"stale broadcast","from_agent":"sender","to_target":"any","status":"pending","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift -2880)"'"},
    {"id":12,"title":"old but tagged for us","from_agent":"sender","to_target":"any","status":"pending","ttl_hours":168,"context_refs":[{"type":"project","id":"proj"}],"created_at":"'"$(iso_shift -2880)"'"}
  ]}'
  local out; out=$(poll_once_out)
  assert_contains     "fresh broadcast is announced"        "INTERAGENT new #10" "$out"
  assert_not_contains "48h-old untagged broadcast is not"   "INTERAGENT new #11" "$out"
  assert_contains     "an old PROJECT-TAGGED message still is" "INTERAGENT new #12" "$out"
  teardown
}

# ARM: a durable todo carries ttl_hours IS NULL. make_interval(hours => NULL) is
# NULL, so a bare TTL predicate is UNKNOWN and drops every todo — lived on
# 2026-09-20, when the Grok TUI saw #265 and missed #262/#263/#266/#268.
arm_durable_todo_ttl_null_is_emitted() {
  setup_env rcvr
  db_write '{"assignments":[
    {"id":262,"title":"durable todo, no TTL","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":null,"context_refs":[],"created_at":"'"$(iso_shift -4320)"'"},
    {"id":265,"title":"ordinary message with a TTL","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift -30)"'"},
    {"id":268,"title":"genuinely expired","from_agent":"sender","to_target":"rcvr","status":"pending","ttl_hours":1,"context_refs":[],"created_at":"'"$(iso_shift -600)"'"}
  ]}'
  local out; out=$(poll_once_out)
  assert_contains     "a 3-day-old durable todo IS emitted"  "INTERAGENT new #262" "$out"
  assert_contains     "an ordinary in-TTL message still is"  "INTERAGENT new #265" "$out"
  assert_not_contains "a genuinely expired TTL is still cut" "INTERAGENT new #268" "$out"
  teardown
}

# ARM: CLAIMED and COMPLETED are each said exactly once, however many polls run.
arm_claimed_completed_once() {
  setup_env sender
  db_write '{"assignments":[{"id":901,"title":"work item","from_agent":"sender","to_target":"peer","status":"pending","ttl_hours":24,"context_refs":[],"created_at":"'"$(iso_shift 0)"'"}]}'

  INTERAGENT_MAX_LIFETIME_S=20 bash "$POLLER" 1 >"$TMP/sent.out" 2>"$TMP/sent.err" & local P=$!
  sleep 4
  db_patch 901 'status="claimed"' 'claimed_by="peer"' "claimed_at=\"$(iso_shift 0)\""
  sleep 5
  db_patch 901 'status="completed"' "completed_at=\"$(iso_shift 0)\"" 'result="all green, 12 rows written"'
  wait $P
  local out; out=$(cat "$TMP/sent.out")

  assert_contains "CLAIMED is emitted"           "CLAIMED #901 by peer after" "$out"
  assert_eq       "CLAIMED is emitted once"      "1" "$(count_of "CLAIMED #901 by peer after" "$out")"
  assert_contains "COMPLETED carries the result" "COMPLETED #901: all green, 12 rows written" "$out"
  assert_eq       "COMPLETED is emitted once"    "1" "$(count_of "COMPLETED #901:" "$out")"
  teardown
}

# ARM: the 5/15/60 alarms, driven by a FAKE DATABASE CLOCK set ten days ahead of
# this machine. A process that ages rows against the local clock sees negative
# ages and raises nothing, so this arm is also the local-clock detector.
arm_alarms_5_15_60() {
  setup_env sender
  local T=14400            # +10 days, in minutes
  db_write '{"now":"'"$(iso_shift $T)"'","assignments":[{"id":901,"title":"needs a claim","from_agent":"sender","to_target":"peer","status":"pending","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift $((T-6)))"'"}]}'

  INTERAGENT_MAX_LIFETIME_S=22 bash "$POLLER" 1 >"$TMP/al.out" 2>"$TMP/al.err" & local P=$!
  sleep 5
  db_now "$(iso_shift $((T+10)))"      # row is now 16 min old
  sleep 5
  db_now "$(iso_shift $((T+55)))"      # row is now 61 min old
  wait $P
  local out; out=$(cat "$TMP/al.out")

  assert_contains "5 min alarm"  "UNCLAIMED #901 needs a claim - 5 min"  "$out"
  assert_contains "15 min alarm" "UNCLAIMED #901 needs a claim - 15 min" "$out"
  assert_contains "60 min alarm" "UNCLAIMED #901 needs a claim - 60 min" "$out"
  assert_contains "the wording names the three causes" "not watching, busy, or offline" "$out"
  assert_eq "the 5 min alarm is said once" "1" "$(count_of "- 5 min" "$out")"
  teardown
}

# ARM: a claimed row never alarms; an unclaimed one of the same age does.
# Broadcast sends are exempt from alarms entirely.
arm_no_alarm_when_claimed() {
  setup_env sender
  db_write '{"assignments":[
    {"id":901,"title":"claimed long ago","from_agent":"sender","to_target":"peer","status":"claimed","claimed_by":"peer","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift -90)"'","claimed_at":"'"$(iso_shift -85)"'"},
    {"id":902,"title":"still waiting","from_agent":"sender","to_target":"peer2","status":"pending","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift -90)"'"},
    {"id":903,"title":"a broadcast we sent","from_agent":"sender","to_target":"any","status":"pending","ttl_hours":168,"context_refs":[],"created_at":"'"$(iso_shift -90)"'"}
  ]}'
  local out; out=$(poll_once_out)
  assert_contains     "an unclaimed send of that age does alarm" "UNCLAIMED #902" "$out"
  assert_not_contains "a claimed send never alarms"              "UNCLAIMED #901" "$out"
  assert_not_contains "a broadcast send never alarms"            "UNCLAIMED #903" "$out"
  teardown
}

# ARM: machine/project names that are not identifiers are refused outright —
# they reach SQL string literals, and the hop is a remote shell.
arm_injection_refused() {
  setup_env rcvr
  db_write '{"assignments":[]}'

  local out rc
  out=$(INTERAGENT_PROJECT='proj`id`$(whoami)' bash "$POLLER" --once 2>"$TMP/inj1.err"); rc=$?
  assert_eq       "backticked project refused (rc=2)" "2" "$rc"
  assert_eq       "  ...and emits nothing on stdout"  ""  "$out"
  assert_contains "  ...with a reason"                "refusing project name" "$(cat "$TMP/inj1.err")"

  out=$(INTERAGENT_MACHINE="dell'; DROP TABLE x; --" bash "$POLLER" --once 2>"$TMP/inj2.err"); rc=$?
  assert_eq       "quoted machine refused (rc=2)" "2" "$rc"
  assert_contains "  ...with a reason"            "refusing machine name" "$(cat "$TMP/inj2.err")"

  out=$(INTERAGENT_PROJECT='ql-g3_enterprise.v2' bash "$POLLER" --once 2>/dev/null); rc=$?
  assert_eq "a normal name with . _ - is accepted" "0" "$rc"
  teardown
}

# ARM: the lifetime cap exists because the Monitor tool caps at 30 min and
# leaves its poller running.
arm_lifetime_exit() {
  setup_env rcvr
  db_write '{"assignments":[]}'
  local out rc
  out=$(INTERAGENT_MAX_LIFETIME_S=3 timeout 40 bash "$POLLER" 1 2>/dev/null); rc=$?
  assert_eq       "poller exits 0 at its lifetime" "0" "$rc"
  assert_contains "  ...saying so"                 "poller lifetime reached" "$out"
  assert_contains "  ...and how to fix it"         "re-arm"                  "$out"
  teardown
}

# ARM: prove the assertion machinery can fail. Without this, a suite that
# silently stopped asserting would report all-green.
arm_known_bad() {
  local sub_pass=0
  assert_contains "known-bad probe" "THIS-IS-NOT-THERE" "hello"
  if [[ $FAIL -eq 1 ]]; then sub_pass=1; fi
  FAIL=0
  if [[ $sub_pass -eq 1 ]]; then
    PASS=$((PASS + 1)); echo "  PASS  known-bad: the assert infrastructure detected the mismatch"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL  known-bad: the assert did not fire — every result above is worthless"
  fi
}

ARMS="orphan_no_steal wrong_name scope_banner_and_override \
stale_sweep_spares_live_dirs proc_dir_starts_empty empty_owner_is_not_dead \
hop_failure_warns hop_truncated_reply hop_hangs \
rearm_reannounces broadcast_24h durable_todo_ttl_null_is_emitted \
claimed_completed_once alarms_5_15_60 seed_uses_db_clock \
no_alarm_when_claimed injection_refused lifetime_exit known_bad"

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
  "arm_$arm"
  echo "  [$arm] $PASS passed, $FAIL failed"
  [[ $FAIL -gt 0 ]] && exit 1
  exit 0
fi

# ── phase 1 ──────────────────────────────────────────────────────────────────
echo "=== interagent monitor (r3: the claim is the ack) — offline suite ==="
echo "=== no network, no live pgvector, no migration ==="
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
# name | owning arm | file | sed expression
MUTANTS=(
  "shared-seen-file-restored|orphan_no_steal|poller|s@^PROC_DIR=.*@PROC_DIR=\"\$STATE_ROOT/proc-shared\"; mkdir -p \"\$PROC_DIR\"@"
  "scope-banner-not-on-stdout|scope_banner_and_override|poller|s@^say \"\$BANNER\"@:@"
  "sweep-by-age-not-by-owner|stale_sweep_spares_live_dirs|poller|s@^      pid_is_poller \"\$pid\" && continue.*@      :@"
  "proc-dir-reused-across-starts|proc_dir_starts_empty|poller|s@^PROC_DIR=.*@PROC_DIR=\"\$STATE_ROOT/proc-\${MACHINE}-\${PROJECT}-\${MAIN_PID}\"; mkdir -p \"\$PROC_DIR\"@"
  "hop-timeout-removed|hop_hangs|poller|s@^    out=\$(timeout \"\$HOP_TIMEOUT_S\" bash \"\$INTERAGENT_PSQL_WRAPPER\".*@    out=\$(bash \"\$INTERAGENT_PSQL_WRAPPER\" < \"\$SQL_FILE\" 2>\"\$ERR_FILE\"); rc=\$?@"
  "seed-uses-local-clock|seed_uses_db_clock|process|s@^    startMs = nowMs;@    startMs = Date.now();@"
  "empty-owner-treated-as-dead|empty_owner_is_not_dead|poller|s@^    if \[\[ \"\$pid\" =~ .*@    if [[ -f \"\$d/owner\" ]]; then@"
  "hop-failure-as-empty|hop_failure_warns|poller|s@^    hop_failed .*@    return 0@"
  "alarm-fires-for-a-claimed-row|no_alarm_when_claimed|process|s@^    const unclaimed = .*@    const unclaimed = true;@"
  "COMPLETED-every-poll|claimed_completed_once|process|s@'COMPLETED-' + id@'COMPLETED-' + id + Math.random()@"
  "local-clock-used-for-age|alarms_5_15_60|process|s@^  const nowMs = .*@  const nowMs = Date.now();@"
  "broadcast-exempt-removed|broadcast_24h|process|s@^      if (isBroadcast .*@      if (false) continue;@"
  "durable-todo-ttl-guard-reverted|durable_todo_ttl_null_is_emitted|poller|s@^    AND (a.ttl_hours IS NULL OR @    AND (@"
  "recovery-claimed-before-the-reply-parses|hop_truncated_reply|poller|s@^    hop_failed \"\$rc\" \"malformed.*@    hop_recovered@"
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

  POLLER="$mdir/interagent-monitor-poll.sh" PROCESS="$mdir/interagent-monitor-process.js" \
    timeout "$ARM_TIMEOUT" bash "$0" --arm "$marm" > "$mdir/out.txt" 2>&1
  rc=$?
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
