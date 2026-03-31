#!/usr/bin/env bash
# Claude Code SessionStart hook — project context pre-warm.
# Maps the working directory to a project, loads relevant Obsidian notes
# from the local Syncthing copy so agent starts with context.
# Always exits 0 — never blocks session start.

VAULT=~/Syncthing/Obsidian-Vault
PWD_NORM=$(pwd | tr '\\' '/')

# Machine identity (per-machine, not synced)
MACHINE_ID_FILE=~/.claude/machine-identity.json
MACHINE_NAME="unknown"
MM_USERNAME=""
if [[ -f "$MACHINE_ID_FILE" ]]; then
  MACHINE_NAME=$(python3 -c "import json; print(json.load(open('$MACHINE_ID_FILE'))['name'])" 2>/dev/null || echo "unknown")
  MM_USERNAME=$(python3 -c "import json; print(json.load(open('$MACHINE_ID_FILE'))['mattermost_username'])" 2>/dev/null || echo "")
fi

# Map working directory to project + Obsidian note path
PROJECT=""
NOTE_PATH=""

case "$PWD_NORM" in
  */QL-G3-Lite*|*/usb-proxy-ethernet*|*/ql-g3-hub-pcb*)
    PROJECT="QuickLinks G3 Lite"
    # Check subfolder first (newer), then flat file
    if [[ -f "$VAULT/QuickLinks/G3 Lite/Product Overview.md" ]]; then
      NOTE_PATH="$VAULT/QuickLinks/G3 Lite/Product Overview.md"
    else
      NOTE_PATH="$VAULT/QuickLinks/G3 Lite Development Bench.md"
    fi
    ;;
  */QL-G3-Enterprise*)
    PROJECT="QuickLinks G3 Enterprise"
    NOTE_PATH="$VAULT/QuickLinks/G3 Enterprise.md"
    ;;
  */ql-support-portal*)
    PROJECT="QuickLinks Support Portal"
    NOTE_PATH="$VAULT/QuickLinks/Support Portal.md"
    ;;
  */ql-provisioner*)
    PROJECT="QuickLinks Provisioner"
    NOTE_PATH="$VAULT/QuickLinks/Provisioner.md"
    ;;
  */QL-OpenWRT*|*/ql-openwrt*)
    PROJECT="QuickLinks OpenWRT"
    NOTE_PATH="$VAULT/QuickLinks/OpenWRT Firmware.md"
    ;;
  */quoteforge*|*/quote-forge*)
    PROJECT="QuoteForge"
    NOTE_PATH="$VAULT/Quote Forge/Overview.md"
    ;;
  */delectable-dilemmas*|*/stockyards*)
    PROJECT="Delectable Dilemmas"
    NOTE_PATH="$VAULT/Delectable Dilemmas/Overview.md"
    ;;
  */mcp-gateway*|*/mcp-servers*)
    PROJECT="MCP Gateway"
    NOTE_PATH="$VAULT/Homelab/MCP Gateway.md"
    ;;
  */memory-system*)
    PROJECT="Memory System"
    NOTE_PATH="$VAULT/Homelab/Projects/Memory System.md"
    ;;
  */claude-skills-suite*)
    PROJECT="Skills Suite"
    NOTE_PATH=""
    ;;
  *)
    # No project match — still useful to echo working dir context
    PROJECT="general"
    ;;
esac

if [[ "$PROJECT" == "general" ]]; then
  echo "PROJECT CONTEXT: general (working dir: $PWD_NORM)"
else
  echo "PROJECT CONTEXT: $PROJECT"
fi

# Load Obsidian note if it exists (first 150 lines to keep context lean)
if [[ -n "$NOTE_PATH" && -f "$NOTE_PATH" ]]; then
  echo "--- Obsidian reference note: $(basename "$NOTE_PATH") ---"
  head -n 150 "$NOTE_PATH"
  echo "--- end note ---"
fi

# ── Project structure check ──
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -n "$GIT_ROOT" ]] && [[ ! -f "$GIT_ROOT/GROUNDING.md" ]]; then
  echo "NO GROUNDING.md FOUND. Run /project-organize before starting work."
fi

# ── Artifact DB awareness ──
if [[ -n "$GIT_ROOT" ]]; then
  DB_PATH="$GIT_ROOT/artifacts/project.db"
  if [[ -f "$DB_PATH" ]]; then
    RECORD_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM artifacts;" 2>/dev/null || echo "0")
    LATEST=$(sqlite3 "$DB_PATH" "SELECT skill || ' / ' || phase || ' / ' || label || ' (' || created_at || ')' FROM artifacts ORDER BY id DESC LIMIT 3;" 2>/dev/null || echo "none")
    echo ""
    echo "ARTIFACT DB: $RECORD_COUNT records in project database"
    echo "Recent entries:"
    echo "$LATEST"
    echo "(query with: source artifacts/db.sh && db_search 'your topic')"
  fi
fi

# ── Derive session ID from debug directory ──
SESSION_ID=$(ls -t ~/.claude/debug/ 2>/dev/null | head -1 | sed 's/\.txt$//')
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown-$$"

# ── Gateway awareness: task pickup, concurrent sessions, coordination ──
prewarm_gateway() {
  local SSH_HOST="deepthought"

  _mcp_call() {
    local payload_b64="$1"
    ssh -o ConnectTimeout=4 -o BatchMode=yes "$SSH_HOST" "
      IP=\$(docker inspect homelab-mcp-gateway --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
      [ -z \"\$IP\" ] && exit 1
      GW=\"http://\${IP}:3500/mcp\"
      HDR='-H Content-Type:application/json -H Accept:application/json,text/event-stream'
      INIT=\$(curl -s --max-time 4 \$HDR -D /tmp/mcp-h-pw \"\$GW\" \
        -d '{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"prewarm\",\"version\":\"1.0\"}},\"id\":1}')
      SID=\$(grep -i mcp-session-id /tmp/mcp-h-pw 2>/dev/null | tr -d '\r\n' | sed 's/.*: //')
      [ -z \"\$SID\" ] && exit 1
      curl -s --max-time 3 \$HDR -H \"mcp-session-id: \$SID\" \"\$GW\" \
        -d '{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}' > /dev/null
      echo '$payload_b64' | base64 -d | \
        curl -s --max-time 5 \$HDR -H \"mcp-session-id: \$SID\" \"\$GW\" -d @-
    " 2>/dev/null
  }

  # Check interagent inbox for assignments from other machines
  local INBOX_B64=$(python3 -c "
import json, base64, sys
p = {'jsonrpc': '2.0', 'method': 'tools/call', 'params': {'name': 'interagent_call', 'arguments': {'tool': 'inbox', 'params': {'machine': sys.argv[1]}}}, 'id': 7}
print(base64.b64encode(json.dumps(p).encode()).decode())
" "$MACHINE_NAME" 2>/dev/null) || true
  local RAW_INBOX=""
  if [[ -n "$INBOX_B64" ]]; then
    RAW_INBOX=$(_mcp_call "$INBOX_B64") || true
  fi

  # Check for ready agent tasks
  local TASK_B64=$(echo -n '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"task_call","arguments":{"tool":"next","params":{"executor":"agent"}}},"id":2}' | base64 -w 0)
  local RAW_TASK=$(_mcp_call "$TASK_B64") || true

  # Check for concurrent sessions
  local SESS_B64=$(echo -n '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"activity_call","arguments":{"tool":"sessions","params":{"hours":2,"limit":5}}},"id":3}' | base64 -w 0)
  local RAW_SESSIONS=$(_mcp_call "$SESS_B64") || true

  # Register this session with coordination system
  local HOSTNAME_VAL=$(hostname 2>/dev/null || echo "unknown")
  local COORD_PAYLOAD=$(python3 -c "
import json, sys
p = {
    'jsonrpc': '2.0', 'method': 'tools/call',
    'params': {
        'name': 'coordination_call',
        'arguments': {
            'tool': 'register_session',
            'params': {
                'session_id': sys.argv[1],
                'cwd': sys.argv[2],
                'project': sys.argv[3],
                'hostname': sys.argv[4]
            }
        }
    },
    'id': 4
}
print(json.dumps(p))
" "$SESSION_ID" "$PWD_NORM" "$PROJECT" "$HOSTNAME_VAL" 2>/dev/null | base64 -w 0) || true
  local RAW_COORD=""
  if [[ -n "$COORD_PAYLOAD" ]]; then
    RAW_COORD=$(_mcp_call "$COORD_PAYLOAD") || true
  fi

  # Map project to Mattermost channel
  local MM_CHANNEL="agent-activity"
  case "$PROJECT" in
    QuickLinks*) MM_CHANNEL="quicklinks" ;;
    Delectable*) MM_CHANNEL="delectable-dilemmas" ;;
    QuoteForge*) MM_CHANNEL="quicklinks" ;;
  esac

  # Create root thread post in Mattermost
  local ROOT_MSG="**Session ${SESSION_ID:0:8}** | $PROJECT | $MACHINE_NAME"
  local ROOT_POST_B64=$(python3 -c "
import json, sys, base64
params = {'channel': sys.argv[1], 'message': sys.argv[2]}
if sys.argv[3]:
    params['username'] = sys.argv[3]
p = {
    'jsonrpc': '2.0', 'method': 'tools/call',
    'params': {
        'name': 'mattermost_call',
        'arguments': {
            'tool': 'create_post',
            'params': params
        }
    },
    'id': 5
}
print(base64.b64encode(json.dumps(p).encode()).decode())
" "$MM_CHANNEL" "$ROOT_MSG" "$MM_USERNAME" 2>/dev/null) || true
  local RAW_ROOT_POST=""
  if [[ -n "$ROOT_POST_B64" ]]; then
    RAW_ROOT_POST=$(_mcp_call "$ROOT_POST_B64") || true
  fi

  # Read recent channel context (last 5 posts)
  local CHAN_B64=$(python3 -c "
import json, base64
p = {
    'jsonrpc': '2.0', 'method': 'tools/call',
    'params': {
        'name': 'mattermost_call',
        'arguments': {
            'tool': 'get_posts',
            'params': {'channel': '$MM_CHANNEL', 'per_page': '5'}
        }
    },
    'id': 6
}
print(base64.b64encode(json.dumps(p).encode()).decode())
" 2>/dev/null) || true
  local RAW_CHANNEL=""
  if [[ -n "$CHAN_B64" ]]; then
    RAW_CHANNEL=$(_mcp_call "$CHAN_B64") || true
  fi

  # Parse all responses with local python3
  local OUTPUT=$(python3 -c "
import sys, json, os

raw_task = sys.argv[1] if len(sys.argv) > 1 else ''
raw_sess = sys.argv[2] if len(sys.argv) > 2 else ''
raw_coord = sys.argv[3] if len(sys.argv) > 3 else ''
session_id = sys.argv[4] if len(sys.argv) > 4 else 'unknown'
raw_root = sys.argv[5] if len(sys.argv) > 5 else ''
mm_channel = sys.argv[6] if len(sys.argv) > 6 else 'agent-activity'
raw_channel = sys.argv[7] if len(sys.argv) > 7 else ''
raw_inbox = sys.argv[8] if len(sys.argv) > 8 else ''

# Interagent inbox — assignments from other machines
if raw_inbox:
    try:
        outer = json.loads(raw_inbox)
        inner_text = outer['result']['content'][0]['text']
        inner = json.loads(inner_text)
        assignments = inner.get('assignments', [])
        count = inner.get('count', len(assignments))
        if count > 0:
            print(f'*** INTERAGENT INBOX: {count} assignment(s) pending ***')
            for a in assignments:
                title = a.get('title', 'untitled')
                frm = a.get('from_agent', '?')
                priority = a.get('priority', 'normal')
                aid = a.get('id', '?')
                print(f'  [{priority}] #{aid}: {title} (from {frm})')
            print(f'  (use interagent_call > claim to pick up)')
    except Exception:
        pass

if raw_task:
    try:
        outer = json.loads(raw_task)
        inner_text = outer['result']['content'][0]['text']
        inner = json.loads(inner_text)
        task = inner.get('task')
        if task:
            title = task.get('title', 'untitled')
            priority = task.get('priority', '?')
            ttype = task.get('type', '?')
            desc = (task.get('description', '') or '')[:200]
            tid = task.get('id', '?')
            print(f'PENDING TASK: {title}')
            print(f'  Priority: {priority}  Type: {ttype}  ID: {tid}')
            if desc: print(f'  {desc}')
            print(f'  (use task_call > dispatch to claim)')
    except Exception:
        pass

if raw_sess:
    try:
        outer = json.loads(raw_sess)
        inner_text = outer['result']['content'][0]['text']
        inner = json.loads(inner_text)
        sessions = [s for s in inner.get('sessions', []) if s.get('calls', 0) > 2]
        if sessions:
            print(f'CONCURRENT SESSIONS: {len(sessions)} active in last 2 hours')
            for s in sessions:
                sid = s.get('session_id', '?')[:8]
                calls = s.get('calls', 0)
                mods = ', '.join(s.get('modules', []))
                print(f'  - {sid}: {calls} calls ({mods})')
    except Exception:
        pass

# Parse coordination response and write cache file
coord_data = {'signals': None, 'locks': None, 'registered': False}
if raw_coord:
    try:
        outer = json.loads(raw_coord)
        inner_text = outer['result']['content'][0]['text']
        inner = json.loads(inner_text)
        coord_data = inner

        signals = inner.get('signals')
        locks = inner.get('locks')

        if signals:
            print(f'*** ACTIVE SIGNALS ***')
            for name, info in signals.items():
                reason = info.get('reason', '?')
                set_by = info.get('set_by', '?')
                print(f'  {name}: {reason} (set by {set_by})')
        else:
            print('No active coordination signals.')

        if locks:
            print(f'ACTIVE LOCKS:')
            for name, info in locks.items():
                owner = info.get('owner', '?')[:8]
                reason = info.get('reason', '?')
                print(f'  {name}: held by {owner} -- {reason}')
    except Exception:
        pass

# Parse root post response and save post ID + channel ID
root_post_id = ''
channel_id = ''
if raw_root:
    try:
        outer = json.loads(raw_root)
        inner_text = outer['result']['content'][0]['text']
        inner = json.loads(inner_text)
        root_post_id = inner.get('id', '')
        channel_id = inner.get('channel_id', '')
    except Exception:
        pass

# Write session cache (coordination + root post info)
cache_dir = os.path.expanduser(f'~/.claude/session-env/{session_id}')
os.makedirs(cache_dir, exist_ok=True)

cache_path = os.path.join(cache_dir, 'coordination.json')
with open(cache_path, 'w') as f:
    json.dump(coord_data, f)

if root_post_id:
    root_path = os.path.join(cache_dir, 'root_post.json')
    with open(root_path, 'w') as f:
        json.dump({'post_id': root_post_id, 'channel_id': channel_id, 'channel': mm_channel}, f)

# Show recent channel activity
if raw_channel:
    try:
        outer = json.loads(raw_channel)
        inner_text = outer['result']['content'][0]['text']
        inner = json.loads(inner_text)
        posts = inner.get('posts', [])
        if posts and len(posts) > 1:
            print(f'')
            print(f'Recent channel activity ({mm_channel}):')
            for p in posts[:5]:
                user = p.get('user', '?')
                msg = p.get('message', '')[:120].replace(chr(10), ' ')
                print(f'  [{user}] {msg}')
    except Exception:
        pass
" "$RAW_TASK" "$RAW_SESSIONS" "$RAW_COORD" "$SESSION_ID" "$RAW_ROOT_POST" "$MM_CHANNEL" "$RAW_CHANNEL" "$RAW_INBOX" 2>/dev/null) || true

  if [[ -n "$OUTPUT" ]]; then
    echo ""
    echo "$OUTPUT"
  fi
  return 0
}

# Run gateway awareness with 10s hard timeout
prewarm_gateway &
GW_PID=$!
( sleep 15; kill $GW_PID 2>/dev/null ) &
TIMER_PID=$!
wait $GW_PID 2>/dev/null
kill $TIMER_PID 2>/dev/null
wait $TIMER_PID 2>/dev/null

exit 0
