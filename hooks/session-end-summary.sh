#!/usr/bin/env bash
# Claude Code Stop hook — session summary to Qdrant + Mattermost.
# Runs on Windows Git Bash. SSH to Unraid only for curl to gateway.
# Python parsing runs locally (python3 available on Windows).
# Always exits 0 — never blocks the agent stop.

SSH_HOST="deepthought"
MIN_CALLS=5
COOLDOWN_SECS=1800   # 30 min — suppress Qdrant session-log if last store was recent
COOLDOWN_FILE=~/.claude/.session-log-cooldown

# Machine identity (per-machine, not synced)
MACHINE_ID_FILE=~/.claude/machine-identity.json
MM_USERNAME=""
if [[ -f "$MACHINE_ID_FILE" ]]; then
  MM_USERNAME=$(python3 -c "import json; print(json.load(open('$MACHINE_ID_FILE'))['mattermost_username'])" 2>/dev/null || echo "")
fi

# ── Cooldown check — skip Qdrant store if too recent ─────────────────────
SKIP_QDRANT=0
if [[ -f "$COOLDOWN_FILE" ]]; then
  LAST_STORE=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  ELAPSED=$((NOW - LAST_STORE))
  if (( ELAPSED < COOLDOWN_SECS )); then
    SKIP_QDRANT=1
  fi
fi

# ── helper: MCP call via SSH → curl to gateway container ─────────────────
# Discovers gateway IP, does full MCP handshake, executes tool call.
# Args: $1 = JSON-RPC tool call payload (base64-encoded)
# Returns: raw JSON response on stdout
mcp_call() {
  local payload_b64="$1"
  ssh -o ConnectTimeout=6 -o BatchMode=yes "$SSH_HOST" "
    IP=\$(docker inspect homelab-mcp-gateway --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
    [ -z \"\$IP\" ] && exit 1
    GW=\"http://\${IP}:3500/mcp\"
    HDR='-H Content-Type:application/json -H Accept:application/json,text/event-stream'

    # Initialize
    INIT=\$(curl -s --max-time 8 \$HDR -D /tmp/mcp-h \"\$GW\" \
      -d '{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"hook\",\"version\":\"1.0\"}},\"id\":1}')
    SID=\$(grep -i mcp-session-id /tmp/mcp-h 2>/dev/null | tr -d '\r\n' | sed 's/.*: //')
    [ -z \"\$SID\" ] && exit 1

    # Notify initialized
    curl -s --max-time 5 \$HDR -H \"mcp-session-id: \$SID\" \"\$GW\" \
      -d '{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}' > /dev/null

    # Execute tool call
    echo '$payload_b64' | base64 -d | \
      curl -s --max-time 10 \$HDR -H \"mcp-session-id: \$SID\" \"\$GW\" -d @-
  " 2>/dev/null
}

# ── 1. Fetch most recent session from activity log ──────────────────────────
FETCH_B64=$(echo -n '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"activity_call","arguments":{"tool":"sessions","params":{"hours":6,"limit":1}}},"id":2}' | base64 -w 0)

RAW_SESSION=$(mcp_call "$FETCH_B64") || exit 0
[[ -z "$RAW_SESSION" ]] && exit 0

# ── 2. Parse response locally with python3 ──────────────────────────────────
read -r -d '' PARSE_SCRIPT <<'PYEOF'
import sys, json, base64, os
from datetime import datetime

raw       = sys.argv[1]
min_calls = int(sys.argv[2])
session_id_arg = sys.argv[3] if len(sys.argv) > 3 else ''
mm_username = sys.argv[4] if len(sys.argv) > 4 else ''
skip_qdrant = sys.argv[5] if len(sys.argv) > 5 else '0'

try:
    outer      = json.loads(raw)
    inner_text = outer["result"]["content"][0]["text"]
    inner      = json.loads(inner_text)
    sessions   = inner.get("sessions", [])
except Exception:
    sys.exit(0)

if not sessions:
    sys.exit(0)

s          = sessions[0]
call_count = s.get("calls", 0)

if call_count <= min_calls:
    sys.exit(0)

# Additional filter: skip pure-gateway sessions (only gateway/activity calls = no real work)
modules = s.get("modules", [])
noise_modules = {"gateway", "activity", "coordination"}
real_modules = [m for m in modules if m not in noise_modules]
if not real_modules:
    sys.exit(0)

session_id = s.get("session_id", "unknown")
errors     = s.get("errors", 0)
started    = s.get("started", "?")
ended      = s.get("last_activity", "?")

def fmt_time(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.strftime("%H:%M UTC")
    except Exception:
        return ts

# Build structured summary
lines = []
lines.append(f"**Session ended** | {call_count} tool calls | {fmt_time(started)} to {fmt_time(ended)}")
if modules:
    lines.append(f"Modules: {', '.join(modules)}")
if errors > 0:
    lines.append(f"Errors: {errors}")

summary_text = '\n'.join(lines)
flat_summary = f"Session {session_id[:8]}: {call_count} calls across {'/'.join(modules)}. {errors} error(s). {fmt_time(started)}-{fmt_time(ended)}."

# Qdrant store payload — only if not in cooldown
store_payload = None
if skip_qdrant != '1':
    store_payload = {
        "jsonrpc": "2.0", "method": "tools/call",
        "params": {
            "name": "memory_call",
            "arguments": {
                "tool": "store",
                "params": {
                    "content":  flat_summary,
                    "tags":     "auto-summary, session-log",
                    "category": "session-log"
                }
            }
        },
        "id": 3
    }

# Check for root post info (for threaded reply)
root_post_id = ''
channel_id = ''
use_sid = session_id_arg or session_id
root_path = os.path.expanduser(f'~/.claude/session-env/{use_sid}/root_post.json')
try:
    with open(root_path) as f:
        rp = json.load(f)
        root_post_id = rp.get('post_id', '')
        channel_id = rp.get('channel_id', '')
except Exception:
    pass

# Mattermost post payload - reply to thread if root post exists, else create new
if root_post_id and channel_id:
    post_payload = {
        "jsonrpc": "2.0", "method": "tools/call",
        "params": {
            "name": "mattermost_call",
            "arguments": {
                "tool": "reply_to_post",
                "params": {k: v for k, v in {
                    "post_id": root_post_id,
                    "channel_id": channel_id,
                    "message": summary_text,
                    "username": mm_username or None
                }.items() if v}
            }
        },
        "id": 4
    }
else:
    post_payload = {
        "jsonrpc": "2.0", "method": "tools/call",
        "params": {
            "name": "mattermost_call",
            "arguments": {
                "tool": "create_post",
                "params": {k: v for k, v in {
                    "channel": "agent-activity",
                    "message": f"**Claude Code session ended**\n{flat_summary}",
                    "username": mm_username or None
                }.items() if v}
            }
        },
        "id": 4
    }

# Output: line 1 = store payload (or SKIP), line 2 = post payload
if store_payload:
    print(base64.b64encode(json.dumps(store_payload).encode()).decode())
else:
    print("SKIP")
print(base64.b64encode(json.dumps(post_payload).encode()).decode())
PYEOF

SESSION_ID_PRE=$(ls -t ~/.claude/debug/ 2>/dev/null | head -1 | sed 's/\.txt$//')
PAYLOADS=$(python3 -c "$PARSE_SCRIPT" "$RAW_SESSION" "$MIN_CALLS" "$SESSION_ID_PRE" "$MM_USERNAME" "$SKIP_QDRANT") || exit 0
[[ -z "$PAYLOADS" ]] && exit 0

STORE_B64=$(echo "$PAYLOADS" | sed -n '1p')
POST_B64=$(echo  "$PAYLOADS" | sed -n '2p')

[[ -z "$POST_B64" ]] && exit 0

# ── 3. Store summary to Qdrant (unless cooldown or filtered) ────────────────
if [[ "$STORE_B64" != "SKIP" && -n "$STORE_B64" ]]; then
  mcp_call "$STORE_B64" > /dev/null 2>&1 || true
  # Update cooldown timestamp on successful store
  date +%s > "$COOLDOWN_FILE" 2>/dev/null || true
fi

# ── 4. Post to Mattermost ────────────────────────────────────────────────
mcp_call "$POST_B64" > /dev/null 2>&1 || true

# ── 5. Deregister from coordination system ───────────────────────────────
SESSION_ID=$(ls -t ~/.claude/debug/ 2>/dev/null | head -1 | sed 's/\.txt$//')
if [[ -n "$SESSION_ID" ]]; then
  DEREG_B64=$(python3 -c "
import json, sys, base64
p = {
    'jsonrpc': '2.0', 'method': 'tools/call',
    'params': {
        'name': 'coordination_call',
        'arguments': {
            'tool': 'deregister_session',
            'params': {'session_id': sys.argv[1]}
        }
    },
    'id': 5
}
print(base64.b64encode(json.dumps(p).encode()).decode())
" "$SESSION_ID" 2>/dev/null) || true
  if [[ -n "$DEREG_B64" ]]; then
    mcp_call "$DEREG_B64" > /dev/null 2>&1 || true
  fi
  # Clean up coordination cache
  rm -rf "$HOME/.claude/session-env/${SESSION_ID}" 2>/dev/null || true
fi

exit 0
