#!/usr/bin/env bash
# PostToolUse hook (Bash) — memory checkpoint on git commit.
# Always exits 0.

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

if echo "$COMMAND" | grep -qE 'git commit'; then
  cat <<'EOF'
MEMORY CHECKPOINT (git commit detected):
- EVALUATE: Will a future session need this context? If NO → skip.
- IF YES: Store WHY (decisions, reasoning, gotchas), not WHAT (implementation steps).
- LAYERS: Qdrant (narrative), Neo4j (relationships), Project Pipeline (sprint task status).
- RULE: Not all work needs persisting. Think before storing.
EOF
fi

exit 0
