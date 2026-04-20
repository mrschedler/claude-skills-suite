#!/usr/bin/env bash
# PostToolUse hook — deterministic complexity check after Edit/Write
# Runs fast CLI linters on edited files. No LLM cost.
# Only checks JS/TS/Python files. Skips everything else silently.
# All tools optional — gracefully exits if not installed.
# Works on Windows Git Bash.

INPUT=$(cat)
# JSON parse via node (python3 on Windows resolves to the MS Store stub).
FILE_PATH=$(printf '%s' "$INPUT" | node -e "let b='';process.stdin.on('data',c=>b+=c);process.stdin.on('end',()=>{try{const d=JSON.parse(b);process.stdout.write(String((d.tool_input&&d.tool_input.file_path)||d.file_path||''))}catch(e){}})" 2>/dev/null)

# Exit silently if no file path
[ -z "$FILE_PATH" ] && exit 0

# Normalize path for Git Bash
FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

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

# Check file exists
[ ! -f "$FILE_PATH" ] && exit 0

WARNINGS=""

if [ "$LANG" = "py" ]; then
  if command -v ruff >/dev/null 2>&1; then
    RESULT=$(ruff check --select C901,E501 --line-length 120 "$FILE_PATH" 2>/dev/null || true)
    if [ -n "$RESULT" ] && echo "$RESULT" | grep -q "C901"; then
      WARNINGS="$RESULT"
    fi
  fi
elif [ "$LANG" = "js" ]; then
  if command -v npx >/dev/null 2>&1; then
    # Quick complexity check — cognitive complexity > 15, nesting > 4, function > 50 lines
    RESULT=$(npx --yes eslint --no-eslintrc \
      --plugin sonarjs \
      --rule '{"sonarjs/cognitive-complexity": ["error", 15]}' \
      --rule '{"max-depth": ["error", 4]}' \
      --rule '{"max-lines-per-function": ["warn", {"max": 50, "skipBlankLines": true, "skipComments": true}]}' \
      "$FILE_PATH" 2>/dev/null || true)

    if [ -n "$RESULT" ] && echo "$RESULT" | grep -qE '(error|warning)'; then
      WARNINGS="$RESULT"
    fi
  fi
fi

if [ -n "$WARNINGS" ]; then
  ESCAPED=$(echo "$WARNINGS" | head -20 | sed 's/"/\\"/g' | tr '\n' ' ')
  cat <<EOF
{
  "decision": "block",
  "reason": "Complexity threshold exceeded in edited file. Simplify before continuing:\n\n$ESCAPED\n\nTargets: cognitive complexity ≤15, nesting ≤4, function length ≤50 lines."
}
EOF
else
  exit 0
fi
