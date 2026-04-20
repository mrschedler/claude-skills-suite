#!/usr/bin/env bash
# PostToolUse hook (Bash) — memory checkpoint on git commit.
# Always exits 0.

INPUT=$(cat)

# JSON parse via node (python3 on Windows resolves to the MS Store stub).
COMMAND=$(printf '%s' "$INPUT" | node -e "let b='';process.stdin.on('data',c=>b+=c);process.stdin.on('end',()=>{try{const d=JSON.parse(b);process.stdout.write(String((d.tool_input&&d.tool_input.command)||d.command||''))}catch(e){}})" 2>/dev/null)

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
