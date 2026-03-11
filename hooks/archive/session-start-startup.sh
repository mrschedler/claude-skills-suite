#!/usr/bin/env bash
# SessionStart hook (matcher: startup)
# Fresh start: load project awareness files into context

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

for FILE in project-context.md coterie.md todo.md; do
  if [ -f "$CWD/$FILE" ]; then
    echo "=== $FILE ==="
    cat "$CWD/$FILE"
    echo ""
  fi
done

exit 0
