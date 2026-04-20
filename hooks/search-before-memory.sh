#!/bin/bash
# PreToolUse hook for mcp__gateway__memory_call and mcp__gateway__graph_call.
# Injects reminders about documented Qdrant/Neo4j API quirks so the agent
# doesn't repeat failures that already exist as stored gotchas.
#
# Keyed on the MCP sub-tool name (delete, update_node, etc.), not shell commands.
# Same search-before-act discipline as the Bash hook.
#
# Input: PreToolUse event JSON on stdin
# Output: stdout reminder injected into conversation context
#
# JSON parsing uses node (always present — Claude Code is a Node app).
# python3 on Windows resolves to the Microsoft Store stub and errors out.

INPUT=$(cat)

EXTRACT=$(printf '%s' "$INPUT" | node -e "
let buf = '';
process.stdin.on('data', c => buf += c);
process.stdin.on('end', () => {
  try {
    const d = JSON.parse(buf);
    const tn = d.tool_name || d.tool || '';
    const ti = d.tool_input || d.params || {};
    const sub = (ti && typeof ti === 'object') ? (ti.tool || '') : '';
    process.stdout.write(tn + '|' + sub);
  } catch (e) {
    process.stdout.write('|');
  }
});
" 2>/dev/null)

TOOL_NAME="${EXTRACT%|*}"
SUB_TOOL="${EXTRACT#*|}"

REMINDERS=""

case "$TOOL_NAME" in
  mcp__gateway__memory_call)
    case "$SUB_TOOL" in
      delete|update|confirm|get|classify)
        REMINDERS="$REMINDERS\n- memory_call > $SUB_TOOL: param is 'memory_id' (NOT 'id'). Wrong name returns Qdrant PointsSelector 400."
        ;;
      list)
        REMINDERS="$REMINDERS\n- memory_call > list: tag filter param doesn't work. Use 'search' with tags= for tag filtering."
        ;;
      store)
        REMINDERS="$REMINDERS\n- memory_call > store: search first to avoid duplicates. Use PascalCase entity name tags for Neo4j cross-reference."
        ;;
    esac
    ;;
  mcp__gateway__graph_call)
    case "$SUB_TOOL" in
      update_node)
        REMINDERS="$REMINDERS\n- graph_call > update_node: silently ignores status/type changes. Use 'query' with raw Cypher SET."
        ;;
      add_observation)
        REMINDERS="$REMINDERS\n- graph_call > add_observation: stores literal 'undefined' on wrong param shape. Verify expected params via graph_list first."
        ;;
      search_nodes|searchNodes)
        REMINDERS="$REMINDERS\n- graph_call > search_nodes: NOT a real tool. Use find_node (by name) or query (Cypher)."
        ;;
    esac
    ;;
esac

if [ -n "$REMINDERS" ]; then
  echo -e "SEARCH-BEFORE-ACT (memory/graph):$REMINDERS"
fi

exit 0
