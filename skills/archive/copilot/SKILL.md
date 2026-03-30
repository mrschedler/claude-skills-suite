---
name: copilot
description: Driver skill for Copilot CLI syntax, flags, and sandbox modes. Load this before spawning any Copilot call. Use when other skills need Copilot or user says "use Copilot".
disable-model-invocation: true
---

# Copilot CLI Driver

Encode the exact Copilot CLI invocation for a given task type. This is a
utility skill — it provides command templates that other skills compose into
their workflows. It is not triggered directly by the user in most cases.

## PATH & Absolute Paths

`run_in_background` and subagent Bash calls spawn non-interactive subshells
that do NOT source `.zshrc`/`.zprofile`. Custom PATH entries are missing.

**Always resolve the path dynamically:**

```bash
COPILOT=$(command -v copilot 2>/dev/null)
test -x "$COPILOT" || COPILOT="$HOME/.local/bin/copilot"
test -x "$COPILOT" || COPILOT="/opt/homebrew/bin/copilot"
test -x "$COPILOT" || { echo "Copilot CLI unavailable — skipping"; exit 0; }
```

Use `"$COPILOT"` in every invocation. Do not use bare `copilot`.

## Concurrency Limit (MANDATORY)

Copilot CLI consumes **premium requests** from your GitHub Copilot quota on
every invocation. Limit simultaneous processes to **2** to avoid quota
exhaustion and API rate limits. This limit is set in `general.md` and applies
to ALL skills. Queue excess tasks and launch as slots free up — identical to
the Gemini 2-slot pattern in `/gemini`.

Track active sessions via a PID file:

```bash
PID_FILE=/tmp/copilot-slots.pid

# Prune dead entries
if [ -f "$PID_FILE" ]; then
  while IFS= read -r pid; do
    ps -p "$pid" >/dev/null 2>&1 && echo "$pid"
  done < "$PID_FILE" > "${PID_FILE}.tmp"
  mv "${PID_FILE}.tmp" "$PID_FILE"
fi

# Check slot availability
ACTIVE=$(wc -l < "$PID_FILE" 2>/dev/null | tr -d ' ' || echo 0)
if [ "${ACTIVE:-0}" -ge 2 ]; then
  echo "All 2 Copilot slots occupied — queuing"
  # Wait for a slot to free up, or skip
fi
```

After launching a background call, append its PID:
```bash
echo $! >> /tmp/copilot-slots.pid
```

## Availability Check

Before any invocation, verify the CLI is installed:

```bash
COPILOT=$(command -v copilot 2>/dev/null)
test -x "$COPILOT" || COPILOT="$HOME/.local/bin/copilot"
test -x "$COPILOT" || COPILOT="/opt/homebrew/bin/copilot"
test -x "$COPILOT" || { echo "Copilot CLI not installed"; exit 1; }
```

If unavailable:
- **Code tasks**: fall back to Codex (`/codex`) or Claude directly.
- **Review tasks**: skip and note "Copilot unavailable" in output.

## Timeout Binary (MANDATORY)

macOS ships NO `timeout` command. The alias only works in interactive shells —
subagents, `run_in_background`, and bare bash subshells do NOT have it.

**Always use the absolute path to GNU coreutils `gtimeout`:**

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
test -x "$GTIMEOUT" || { echo "gtimeout not installed (brew install coreutils)"; exit 1; }
```

Every template below uses `$GTIMEOUT`. Do not use bare `timeout`.

## Non-Interactive (Headless) Mode

Copilot CLI enters headless mode via `-p/--prompt`. The process exits after
the task completes — no interactive session is opened.

**Baseline flags for unattended headless calls:**

| Flag | Purpose |
|---|---|
| `-p "PROMPT"` | The prompt text — this is the headless trigger |
| `--allow-all-tools` | Recommended when the task may need tools; avoids permission prompts |
| `--no-ask-user` | Recommended when execution must not pause on a question |
| `--no-color` | Strips ANSI escape codes from the response body |
| `-s` / `--silent` | Outputs only the agent response; suppresses stats/metadata |

```bash
$GTIMEOUT 120 "$COPILOT" \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  -s \
  -p "PROMPT" 2>/dev/null
```

Simple text-only prompts can complete without `--allow-all-tools` or
`--no-ask-user`, but that is brittle. If the agent decides to use a tool or ask
a question, the run can stall or fail. Use both flags for unattended tasks.

**Never use `--yolo` in automated contexts** — it also enables
`--allow-all-paths` and `--allow-all-urls`, which are too permissive for
scripted calls. Use `--allow-all-tools` with explicit `--add-dir` instead.

## Task-Type Templates

**Every template includes `--allow-all-tools --no-ask-user --no-color -s`**
to prevent interactive pauses and produce clean output.

### Read-Only Analysis / Review

No file writes needed. Disable the built-in GitHub MCP server for local-only
tasks to eliminate 3-10s of startup latency.

```bash
RESULT=$($GTIMEOUT 120 "$COPILOT" \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --disable-builtin-mcps \
  --add-dir /path/to/project \
  -s \
  -p "Review /path/to/project for security issues, focusing on input validation and auth. Be specific with file and line references." 2>/dev/null)
echo "$RESULT" > OUTPUT_FILE
```

### Code Generation / File Writes

When Copilot needs to write files outside the current working directory, add
the target directory explicitly and use a longer timeout to account for
multi-step work.

```bash
$GTIMEOUT 180 "$COPILOT" \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --add-dir /path/to/project \
  -s \
  -p "Add input validation to all API route handlers in /path/to/project" 2>/dev/null > OUTPUT_FILE
```

### Autopilot (Multi-Step Tasks)

For complex tasks that require the agent to continue autonomously across
multiple turns. Always cap with `--max-autopilot-continues`.

```bash
$GTIMEOUT 300 "$COPILOT" \
  --autopilot \
  --max-autopilot-continues 5 \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --add-dir /path/to/project \
  -s \
  -p "Implement all TODO items in /path/to/project/src" 2>/dev/null > OUTPUT_FILE
```

Cap `--max-autopilot-continues` at 3–5. Without it, autopilot runs
indefinitely and the only stop is `$GTIMEOUT`.

### JSON Output (Structured)

`--output-format json` produces JSONL — one JSON object per line. Parse
line-by-line, not as a single document.

```bash
$GTIMEOUT 120 "$COPILOT" \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --disable-builtin-mcps \
  --output-format json \
  -p "PROMPT" 2>/dev/null > /tmp/copilot-out.jsonl

# Extract final assistant message content
jq -r 'select(.type=="assistant.message") | .data.content // empty' \
  /tmp/copilot-out.jsonl | tail -1 > OUTPUT_FILE
```

Validate the JSONL schema on first use — field names may vary by CLI version.
On 1.0.4, the last line is a `result` event, not the final assistant message,
so `tail -1` alone is not a safe extractor.

### With Specific Model

```bash
$GTIMEOUT 120 "$COPILOT" \
  --model gpt-5.4 \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --disable-builtin-mcps \
  -s \
  -p "PROMPT" 2>/dev/null > OUTPUT_FILE
```

**Model reference:**

| Model | Best For |
|---|---|
| `claude-sonnet-4.6` | Balanced quality and speed when you want to pin a Claude model |
| `claude-opus-4.6` | Highest-quality reasoning, slower |
| `claude-haiku-4.5` | Fast, cheap, simple tasks |
| `gpt-5.4` | Codex-class tasks, structured output |
| `gpt-5.1-codex` | Code generation and review |
| `gemini-3-pro-preview` | Large context, web research |

Do not assume a fixed default model. On 2026-03-13, a simple unpinned prompt
auto-routed to `claude-haiku-4.5` on this machine. Pin `--model` when the
output profile must be deterministic.

### High Reasoning

For hard analysis tasks that benefit from extended thinking:

```bash
$GTIMEOUT 180 "$COPILOT" \
  --reasoning-effort high \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --disable-builtin-mcps \
  -s \
  -p "PROMPT" 2>/dev/null > OUTPUT_FILE
```

Reasoning levels: `low`, `medium`, `high`, `xhigh`. Default is unset (model
decides). Use `high` for architectural analysis or security reviews. Use
`xhigh` sparingly — significantly increases latency and quota cost.

### Long Prompt via File

When the prompt is too long for a shell argument, use command substitution:

```bash
PROMPT=$(cat /path/to/prompt.md)
$GTIMEOUT 180 "$COPILOT" \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --disable-builtin-mcps \
  -s \
  -p "$PROMPT" 2>/dev/null > OUTPUT_FILE
```

Avoid here-docs and pipes — Copilot's `-p` flag requires an argument string,
not stdin. Use `$(cat file)` subshell expansion to stay safe.

### With Additional Directories

When the task needs access to shared libraries or configs outside the project:

```bash
$GTIMEOUT 120 "$COPILOT" \
  --allow-all-tools \
  --no-ask-user \
  --no-color \
  --add-dir /path/to/project \
  --add-dir /shared/libs \
  -s \
  -p "Check for API contract mismatches between /path/to/project and /shared/libs" 2>/dev/null > OUTPUT_FILE
```

## Output Validation (MANDATORY)

With `-s/--silent`, Copilot outputs only the agent response text.

1. Check non-empty: `[ -s OUTPUT_FILE ]`
2. Check character count: `wc -c < OUTPUT_FILE` — expect ≥ 100 chars for a real response
3. An output with < 20 characters is likely a failure, timeout, or empty response

```bash
CHARS=$(wc -c < OUTPUT_FILE 2>/dev/null | tr -d ' ')
if [ "${CHARS:-0}" -lt 50 ]; then
  echo "Copilot output too small (${CHARS} chars) — likely failed"
fi
```

## Critical Gotchas

1. **`-p` IS `--prompt`** (unlike Codex where `-p` is `--profile`). `-p "text"`
   is correct. This is the inverse of the Codex gotcha — stay alert when
   switching between the two CLIs.

2. **`--allow-all-tools` is the safe default for unattended tasks** — simple
   text-only prompts can succeed without it, but any prompt that triggers tools
   can stall on a permission request.

3. **`--no-ask-user` prevents headless pauses** — simple prompts can finish
   without it, but the `ask_user` tool can block unattended runs indefinitely.

4. **`--autopilot` without `--max-autopilot-continues` runs indefinitely** —
   always cap it (3–5 recommended). The only fallback is `$GTIMEOUT`.

5. **JSON output is JSONL with mixed event types** — `--output-format json`
   produces one JSON object per line, including reasoning deltas, assistant
   messages, and a final `result` event. Filter for `assistant.message` when
   extracting the answer.

6. **No working-directory flag** — unlike Codex (`-C`), Copilot has no `-C`
   or `--cd`. Use `--add-dir /path` for file access permissions and reference
   the absolute path in your prompt.

7. **`--yolo` is too broad for automation** — it enables `--allow-all-paths`
   and `--allow-all-urls` in addition to `--allow-all-tools`. Use
   `--allow-all-tools` with explicit `--add-dir` instead.

8. **`2>/dev/null` is mandatory** — stderr contains progress spinners, MCP
   startup logs, and ANSI sequences that corrupt output and inflate context.

9. **`-s/--silent` and `--no-color` are both needed** — `-s` removes stats and
   metadata headers; `--no-color` removes ANSI escape codes from the response
   body. One without the other still produces garbage in captured output.

10. **Premium request quota** — every invocation consumes one premium request
    from your GitHub Copilot quota. Batch tasks into a single prompt where
    possible rather than making many small calls.

11. **MCP server startup adds latency** — the built-in GitHub MCP server loads
    by default. Use `--disable-builtin-mcps` for all local-only tasks to
    save 3-10s of startup overhead per call.

12. **Exit codes**: `0` = success; non-zero = error. During debugging, remove
    `2>/dev/null` temporarily to see the actual error message on stderr.
13. **Do not assume a fixed default model** — the CLI can auto-route per task.
    Pin `--model` when model choice matters.

## Short Flag Reference

| Short | Long | Purpose |
|---|---|---|
| `-h` | `--help` | Display help |
| `-i` | `--interactive <prompt>` | Start interactive session with initial prompt |
| `-p` | `--prompt <text>` | Non-interactive headless prompt (**NOT profile**) |
| `-s` | `--silent` | Output only agent response (no stats) |
| — | `--allow-all` | Enable all permissions (alias: `--yolo`) |
| — | `--allow-all-paths` | Allow access to any file path |
| — | `--allow-all-tools` | Allow all tools without confirmation |
| — | `--allow-all-urls` | Allow all URL access |
| — | `--add-dir <dir>` | Add directory to allowed access list |
| — | `--autopilot` | Enable autonomous continuation |
| — | `--available-tools[=tools...]` | Restrict available tools to this set |
| — | `--disable-builtin-mcps` | Disable GitHub MCP server (reduces latency) |
| — | `--disable-mcp-server <name>` | Disable a specific MCP server by name |
| — | `--max-autopilot-continues <n>` | Cap autopilot continuation count |
| — | `--model <model>` | Override model |
| — | `--no-ask-user` | Disable the ask_user tool |
| — | `--no-color` | Strip ANSI codes from output |
| — | `--no-custom-instructions` | Skip loading instruction files |
| — | `--output-format <fmt>` | `text` (default) or `json` (JSONL) |
| — | `--reasoning-effort <lvl>` | `low`, `medium`, `high`, `xhigh` |
| — | `--resume[=id]` | Resume a previous session by ID |
| — | `--yolo` | All permissions (tools + paths + URLs) |

## Fallback Behavior

| Failure Mode | Action |
|---|---|
| CLI not installed | Fall back to Codex (`/codex`) or Claude directly |
| Timeout (killed by `$GTIMEOUT`) | Retry once with 2× timeout; then skip |
| Quota exhausted (429 / hang) | Skip and note "Copilot quota exhausted" |
| All 2 slots occupied | Queue and retry after 30s; skip after 3 attempts |
| MCP server hang | Retry with `--disable-builtin-mcps` |
| Empty output (< 50 chars) | Retry once; then skip |

## Examples

```
Skill (review): Needs Copilot to review a project for code quality issues.
--> RESULT=$($GTIMEOUT 120 "$COPILOT" \
      --allow-all-tools \
      --no-ask-user \
      --no-color \
      --disable-builtin-mcps \
      --add-dir /path/to/project \
      -s \
      -p "Review /path/to/project for code quality issues: naming, duplication, missing error handling. Report with file and line references." 2>/dev/null)
    echo "$RESULT" > /tmp/copilot-review.md
```

```
Skill (meta-review): Firing Copilot alongside Codex and Gemini in parallel.
--> $GTIMEOUT 120 "$COPILOT" \
      --allow-all-tools \
      --no-ask-user \
      --no-color \
      --disable-builtin-mcps \
      --add-dir /path/to/project \
      -s \
      -p "$(cat /tmp/review-prompt.md)" 2>/dev/null > /tmp/copilot-review-output.md &
    echo $! >> /tmp/copilot-slots.pid
    COPILOT_PID=$!
    # ... launch other reviews ...
    wait $COPILOT_PID
```

```
Skill (generation): Implementing a feature with autopilot and a turn cap.
--> $GTIMEOUT 300 "$COPILOT" \
      --autopilot \
      --max-autopilot-continues 5 \
      --allow-all-tools \
      --no-ask-user \
      --no-color \
      --add-dir /path/to/project \
      -s \
      -p "Implement JWT refresh token support in /path/to/project/src/auth.ts following the existing pattern." 2>/dev/null > /tmp/copilot-gen.md
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
