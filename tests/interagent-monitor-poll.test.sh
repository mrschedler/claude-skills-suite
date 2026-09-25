#!/usr/bin/env bash
# tests/interagent-monitor-poll.test.sh — offline tests for hooks/interagent-monitor-poll.sh.
#
# Stubs the SSH/psql query with INTERAGENT_POLL_STUB and isolates all state under a
# temporary LOCALAPPDATA, so it never touches the real inbox or real seen-files.
# Runs from a temp dir that is not a git repo, so PROJECT = that dir's basename.
#
#   bash tests/interagent-monitor-poll.test.sh      # exit 0 = all pass

set -uo pipefail

POLL="$(cd "$(dirname "$0")/.." && pwd)/hooks/interagent-monitor-poll.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
PROJ="$ROOT/proj-x"
mkdir -p "$PROJ" "$ROOT/lad"
STUB="$ROOT/rows.json"
ME=dell-xps
# The temp dir may sit inside a git repo (a home dir under git); stop the
# poller's project lookup at ROOT so PROJECT is the temp dir basename.
export GIT_CEILING_DIRECTORIES="$ROOT"
STATE="$ROOT/lad/claude-interagent"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL - $1"; [[ -n "${2:-}" ]] && printf '       got: %s\n' "$2"; }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "$2"; fi; }

# Run the poller as one session. $1 = session key ("" = leave unset), rest = args.
poll() {
  local key="$1"; shift
  ( cd "$PROJ" && env -u INTERAGENT_SESSION -u CLAUDE_CODE_SESSION_ID -u CLAUDE_SESSION_ID \
      ${key:+INTERAGENT_SESSION="$key"} \
      INTERAGENT_MACHINE="$ME" LOCALAPPDATA="$ROOT/lad" INTERAGENT_POLL_STUB="$STUB" \
      bash "$POLL" "$@" )
}
ids() { grep -o '#[0-9]*' | tr -d '#' | tr '\n' ' ' | sed 's/ $//'; }

cat > "$STUB" <<'JSON'
[{"id":101,"title":"broadcast from peer","from":"dell-xps-work","refs":[]},
 {"id":102,"title":"for this project","from":"dell-xps-work","refs":[{"type":"project","id":"proj-x"}]},
 {"id":103,"title":"for another project","from":"dell-xps-work","refs":[{"type":"project","id":"other"}]},
 {"id":104,"title":"my own broadcast","from":"dell-xps","refs":null},
 {"id":105,"title":"my own project post","from":"dell-xps","refs":[{"type":"project","id":"proj-x"}]}]
JSON

# 1. Two sessions under the same name both see every routed id.
A1=$(poll sessA --once)
B1=$(poll sessB --once)
check "session A emits all routed ids (103 skipped)" "$(ids <<<"$A1")" "101 102 104 105"
check "session B emits the same ids despite A having seen them" "$(ids <<<"$B1")" "101 102 104 105"

# 2. Output line format is unchanged apart from the [self] marker.
check "broadcast line format" "$(grep '#101' <<<"$A1")" \
  "INTERAGENT new #101 [broadcast] from dell-xps-work: broadcast from peer  -> check interagent to read + claim"
check "project line format" "$(grep '#102' <<<"$A1")" \
  "INTERAGENT new #102 [project=proj-x] from dell-xps-work: for this project  -> check interagent to read + claim"
check "self broadcast tagged [self]" "$(grep '#104' <<<"$A1")" \
  "INTERAGENT new #104 [broadcast] [self] from dell-xps: my own broadcast  -> check interagent to read + claim"
check "self project post tagged [self]" "$(grep -c '#105 \[project=proj-x\] \[self\] from dell-xps:' <<<"$A1")" "1"
check "peer mail never tagged [self]" "$(grep -E '#10[12] ' <<<"$A1" | grep -c '\[self\]')" "0"

# 3. Re-runs do not re-emit.
check "session A re-run emits nothing" "$(poll sessA --once)" ""
check "session B re-run emits nothing" "$(poll sessB --once)" ""

# 4. A new message reaches both sessions exactly once.
sed -i 's/^\[/[{"id":106,"title":"late","from":"skip","refs":[]},\n /' "$STUB"
check "session A emits only the new id" "$(poll sessA --once | ids)" "106"
check "session B emits only the new id" "$(poll sessB --once | ids)" "106"
check "per-session files are separate" \
  "$(ls "$STATE/seen" | grep -c "^${ME}-proj-x-sess[AB].txt$")" "2"

# 5. Legacy machine+project file seeds a NEW session once and is never written.
printf '101\n102\n' > "$STATE/seen-${ME}-proj-x.txt"
check "new session seeded from legacy file skips legacy ids" "$(poll sessC --once | ids)" "106 104 105"
check "legacy file untouched" "$(cat "$STATE/seen-${ME}-proj-x.txt" | tr '\n' ' ')" "101 102 "

# 6. Session key derivation.
st=$(cd "$PROJ" && env -u INTERAGENT_SESSION -u CLAUDE_SESSION_ID CLAUDE_CODE_SESSION_ID=abc-123 \
       INTERAGENT_MACHINE="$ME" LOCALAPPDATA="$ROOT/lad" bash "$POLL" --status)
check "CLAUDE_CODE_SESSION_ID is used when INTERAGENT_SESSION is unset" \
  "$(grep '^session_key=' <<<"$st")" "session_key=abc-123 (source: CLAUDE_CODE_SESSION_ID)"
st=$(cd "$PROJ" && env -u INTERAGENT_SESSION -u CLAUDE_SESSION_ID CLAUDE_CODE_SESSION_ID=abc-123 \
       INTERAGENT_SESSION=override INTERAGENT_MACHINE="$ME" LOCALAPPDATA="$ROOT/lad" bash "$POLL" --status)
check "INTERAGENT_SESSION wins over CLAUDE_CODE_SESSION_ID" \
  "$(grep '^session_key=' <<<"$st")" "session_key=override (source: INTERAGENT_SESSION)"
st=$(poll "" --status)
if grep -qE '^session_key=ppid-[0-9]+-[0-9]* \(source: ppid\)$' <<<"$st"; then ok "ppid fallback when no session env"
else bad "ppid fallback when no session env" "$(grep '^session_key=' <<<"$st")"; fi
check "unsafe characters in the key are replaced" \
  "$(poll 'a/b c' --status | grep '^session_key=')" "session_key=a_b_c (source: INTERAGENT_SESSION)"

# 7. --status reports the file and its id count, and is read-only.
st=$(poll sessA --status)
check "--status names the session file with its count" "$(grep '^seen_file=' <<<"$st")" \
  "seen_file=$STATE/seen/${ME}-proj-x-sessA.txt ids=5"
check "--status lists other sessions" "$(grep -c 'proj-x-sess[BC].txt ids=' <<<"$st")" "2"
poll sessNew --status >/dev/null
check "--status does not create a seen-file" "$(ls "$STATE/seen" | grep -c sessNew)" "0"

# 8. Prune: other sessions' files idle for 7+ days are removed; fresh ones stay.
touch -d '10 days ago' "$STATE/seen/${ME}-proj-x-stale.txt" "$STATE/seen/${ME}-proj-x-stale.err"
poll sessA --once >/dev/null
check "stale session file pruned" "$(ls "$STATE/seen" | grep -c stale)" "0"
check "live session files kept" "$(ls "$STATE/seen" | grep -c "sess[ABC].txt")" "3"

# 9. Query failure: one ERROR line, rate-limited in loop mode.
REAL_STUB="$STUB"; STUB="$ROOT/missing.json"
out=$(poll sessErr --once)
if grep -qE '^INTERAGENT poller ERROR: query failed \(exit 1\)' <<<"$out" && [[ $(wc -l <<<"$out") -eq 1 ]]
then ok "--once reports a failed query as one ERROR line"; else bad "--once reports a failed query" "$out"; fi
rm -f "$STATE/seen/${ME}-proj-x-sessLoop.err"
out=$(cd "$PROJ" && env -u CLAUDE_CODE_SESSION_ID INTERAGENT_SESSION=sessLoop INTERAGENT_MACHINE="$ME" \
        LOCALAPPDATA="$ROOT/lad" INTERAGENT_POLL_STUB="$STUB" timeout 12 bash "$POLL" 1)
check "loop mode emits the ERROR once across several failed polls" "$(grep -c 'poller ERROR' <<<"$out")" "1"
out=$(cd "$PROJ" && env -u CLAUDE_CODE_SESSION_ID INTERAGENT_SESSION=sessLoop INTERAGENT_MACHINE="$ME" \
        LOCALAPPDATA="$ROOT/lad" INTERAGENT_POLL_STUB="$STUB" timeout 10 bash "$POLL" 1)
check "a re-armed loop inside the window stays quiet" "$(grep -c 'poller ERROR' <<<"$out")" "0"
out=$(cd "$PROJ" && env -u CLAUDE_CODE_SESSION_ID INTERAGENT_SESSION=sessLoop INTERAGENT_ERR_INTERVAL=0 \
        INTERAGENT_MACHINE="$ME" LOCALAPPDATA="$ROOT/lad" INTERAGENT_POLL_STUB="$STUB" timeout 10 bash "$POLL" 1)
if [[ $(grep -c 'poller ERROR' <<<"$out") -ge 2 ]]; then ok "rate limit is the only thing holding errors back"
else bad "errors repeat once the window is zero" "$out"; fi
STUB="$ROOT/garbage.json"; printf 'psql: FATAL: something\n' > "$STUB"
check "unparseable output is reported" "$(poll sessErr --once | sed 's/:.*//;q')" "INTERAGENT poller ERROR"
STUB="$ROOT/empty.json"; : > "$STUB"
check "empty output is reported" "$(poll sessErr --once)" "INTERAGENT poller ERROR: query returned no output"
STUB="$REAL_STUB"
# sessErr was first created after step 5, so it was seeded from the legacy file.
check "a healthy poll after errors emits normally" "$(poll sessErr --once | ids)" "106 104 105"

echo
echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
