#!/usr/bin/env bash
# PostToolUse hook — deterministic complexity check after Edit/Write
# Runs fast CLI linters on the edited file. No LLM cost.
# Only checks JS/TS/Python files. Skips everything else silently.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit silently if no file path (shouldn't happen but safety)
[ -z "$FILE_PATH" ] && exit 0

# Only check code files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx)
    LANG="js"
    ;;
  *.py)
    LANG="py"
    ;;
  *)
    exit 0
    ;;
esac

WARNINGS=""

if [ "$LANG" = "js" ]; then
  # Check cognitive complexity via eslint + sonarjs if available
  if command -v npx &>/dev/null; then
    # Quick complexity check — only errors, no warnings
    RESULT=$(npx --yes eslint --no-eslintrc \
      --plugin sonarjs \
      --rule '{"sonarjs/cognitive-complexity": ["error", 15]}' \
      --rule '{"max-depth": ["error", 4]}' \
      --rule '{"max-lines-per-function": ["warn", {"max": 50, "skipBlankLines": true, "skipComments": true}]}' \
      "$FILE_PATH" 2>/dev/null)

    if [ $? -ne 0 ] && [ -n "$RESULT" ]; then
      WARNINGS="$RESULT"
    fi
  fi
elif [ "$LANG" = "py" ]; then
  # Check with ruff if available
  if command -v ruff &>/dev/null; then
    RESULT=$(ruff check --select C901,E501 --line-length 120 "$FILE_PATH" 2>/dev/null)
    if [ $? -ne 0 ] && [ -n "$RESULT" ]; then
      WARNINGS="$RESULT"
    fi
  fi
fi

if [ -n "$WARNINGS" ]; then
  # Escape for JSON
  ESCAPED=$(echo "$WARNINGS" | head -20 | jq -Rs .)
  cat <<EOF
{
  "decision": "block",
  "reason": "Complexity threshold exceeded in edited file. Fix before continuing:\n\n${ESCAPED}\n\nReduce cognitive complexity to ≤15, nesting to ≤4 levels, and function length to ≤50 lines."
}
EOF
else
  exit 0
fi
