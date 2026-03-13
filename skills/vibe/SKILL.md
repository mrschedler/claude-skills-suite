---
name: vibe
description: Driver skill for Mistral Vibe CLI (headless) syntax. Load this before spawning any Vibe call. Use when other skills need fast Mistral/Codestral generation or user says "use Vibe".
disable-model-invocation: true
---

# Mistral Vibe CLI Driver

Encode the exact Mistral Vibe CLI invocation for code generation and review tasks. This is a
utility skill — it provides command templates that other skills compose into their workflows.

## PATH & Absolute Paths

`run_in_background` and subagent Bash calls spawn non-interactive subshells that do NOT
source `.zshrc`/`.zprofile`. Custom PATH entries are missing.

**Always resolve the path dynamically:**

```bash
VIBE=$(command -v vibe 2>/dev/null)
test -x "$VIBE" || VIBE="$HOME/.local/bin/vibe"
test -x "$VIBE" || VIBE="/usr/local/bin/vibe"
test -x "$VIBE" || { echo "Mistral Vibe CLI unavailable — skipping"; exit 0; }
```

Use `"$VIBE"` in every invocation. Do not use bare `vibe`.

## Timeout Binary (MANDATORY)

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
test -x "$GTIMEOUT" || { echo "gtimeout not installed (brew install coreutils)"; exit 1; }
```

Every template below uses `$GTIMEOUT`. Do not use bare `timeout`.

## Programmatic Mode (MANDATORY)

**Without `-p` / `--prompt`, Vibe enters interactive TUI mode and hangs indefinitely**
in subshells. The `-p` flag is required for ALL automated invocations.

`-p` auto-approves all tool executions by default — no separate `--auto-approve` needed.

```bash
# Minimum viable programmatic invocation
$GTIMEOUT 120 "$VIBE" -p "PROMPT" --output text --max-turns 5 2>/dev/null
```

**Do NOT use positional prompts** (e.g., `vibe "prompt"`) — those launch the interactive TUI.

## Prompt Scoping (MANDATORY)

Vibe performs best when the prompt is **narrow, concrete, and file/work-unit scoped**.
Do not ask it to "look around the repo", "analyze the whole project", or
"figure out what to change." That pattern burns turns on exploration and often
ends with no final answer.

**Always give Vibe all 4 of these:**

1. **Target** — exact file(s), directory, or work unit ID
2. **Task** — what to implement/review/summarize
3. **Output shape** — patch, code block, bullets, test, etc.
4. **Success criteria** — what "done" means for this prompt

**Good prompt shape:**

```text
Read [specific file(s)].
Implement [specific change].
Return [specific output format].
Stay within [named files / single work unit].
Do not inspect unrelated parts of the project.
```

**Good examples:**

- `Read src/auth.ts and src/session.ts. Implement refresh-token rotation for WU-3. Return complete replacement code blocks for those files only. Do not inspect unrelated directories.`
- `Read rules/general.md and references/cross-cutting-rules.md. Summarize the driver-skill boundary in 5 bullets. Do not scan the rest of the repo.`

**Bad examples:**

- `Analyze the architecture of this project`
- `Look through the repo and figure out what needs to change`
- `Implement this feature however you think is best`

## CLI Flags Reference (v2.4.2)

| Flag | Argument | Purpose |
|---|---|---|
| `-p` / `--prompt` | `TEXT` | Programmatic mode: send prompt, auto-approve tools, output, exit |
| `--output` | `text\|json\|streaming` | Output format (default: `text`) |
| `--max-turns` | `N` | Limit assistant turns (programmatic mode only) |
| `--max-price` | `DOLLARS` | Cost cap — interrupts if exceeded |
| `--enabled-tools` | `TOOL` | Restrict to specific tools; disables all others. Supports glob (`bash*`) and regex (`re:^pattern$`). Can repeat. |
| `--agent` | `NAME` | Agent profile: `default`, `plan`, `accept-edits`, `auto-approve`, or custom |
| `--workdir` | `DIR` | Set working directory |
| `-c` / `--continue` | — | Resume most recent session |
| `--resume` | `SESSION_ID` | Resume specific session (partial ID match) |
| `--setup` | — | Configure API key |
| `-v` / `--version` | — | Show version |

**Flags that do NOT exist** (despite appearing in some docs for other versions):
`--headless`, `--no-prompt`, `--model`, `--auto-approve`, `generate`, `review` subcommands.

## Task-Type Templates

### Code Generation (Primary Use Case)

```bash
# Fast generation with devstral-2 (default model)
# Prompt should name the exact work unit and target files.
$GTIMEOUT 180 "$VIBE" \
  -p "$(cat /tmp/prompt.md)" \
  --output text \
  --max-turns 10 \
  --workdir /path/to/project \
  2>/dev/null > /tmp/vibe-generated.ts
```

### Code Review

```bash
# Review a file — reference the exact file and review focus in the prompt
$GTIMEOUT 120 "$VIBE" \
  -p "Read src/complex-module.ts and analyze for security issues, performance bottlenecks, and code smells" \
  --output text \
  --max-turns 5 \
  --workdir /path/to/project \
  2>/dev/null > /tmp/vibe-review.md
```

### Focused Read-Only Analysis

```bash
# Keep analysis narrow: name the files or directories you want summarized.
$GTIMEOUT 120 "$VIBE" \
  -p "Read rules/general.md and references/cross-cutting-rules.md, then summarize the external-agent driver boundary in 5 bullets." \
  --output text \
  --max-turns 10 \
  --enabled-tools "read_file" \
  --enabled-tools "grep" \
  --workdir /path/to/project \
  2>/dev/null > /tmp/vibe-analysis.md
```

Do **not** use `--agent plan` for one-shot headless analysis. On Vibe 2.4.2 it
enters the CLI's plan-mode workflow, requires a plan file, and can burn turns
without ever producing a final answer.

### Tool-Restricted Run

```bash
# Only allow bash and read_file (no writes)
$GTIMEOUT 120 "$VIBE" \
  -p "List all TODO comments in the project" \
  --output text \
  --max-turns 5 \
  --enabled-tools "bash" \
  --enabled-tools "read_file" \
  --enabled-tools "grep" \
  --workdir /path/to/project \
  2>/dev/null > /tmp/vibe-todos.md
```

## Model Selection

Models are configured in `~/.vibe/config.toml`, not via CLI flags:

```toml
active_model = "devstral-2"  # default
```

| Model (alias) | Provider | Use Case |
|---|---|---|
| `devstral-2` | Mistral API | Code generation (default) |
| `devstral-small` | Mistral API | Lighter/cheaper tasks |
| `local` | llamacpp | Offline/local inference |

To use a different model, create a custom agent config at `~/.vibe/agents/NAME.toml`:

```toml
active_model = "devstral-small"
```

Then invoke with `--agent NAME`.

## Available Tools

Vibe has these built-in tools (use with `--enabled-tools` to restrict):

| Tool | Permission | Purpose |
|---|---|---|
| `read_file` | always | Read file contents |
| `grep` | always | Recursive code search (ripgrep) |
| `bash` | ask (auto in `-p`) | Execute shell commands |
| `write_file` | ask (auto in `-p`) | Create/modify files |
| `search_replace` | ask (auto in `-p`) | Patch files with replacements |
| `task` | ask | Delegate to subagents (`explore` built-in) |
| `web_search` | ask | Search the web |
| `web_fetch` | ask | Fetch URL content |
| `todo` | always | Track work items |
| `ask_user_question` | always | Prompt user (no-op in `-p` mode) |

## Output Validation (MANDATORY)

**Vibe produces concise output** — smoke tests and exact-match prompts may be
2-20 characters, while substantive review/generation responses are usually
50+ characters. Validate based on task type, not a fixed global threshold.

```bash
# Validate output file
if [ ! -s /tmp/vibe-output.md ]; then
  echo "ERROR: Vibe produced empty output" >&2
  exit 1
fi

# Character-count heuristic:
# - Smoke tests / exact-match prompts: EXPECT_MIN_CHARS=1 (default)
# - Real review / generation tasks: EXPECT_MIN_CHARS=50
EXPECT_MIN_CHARS="${EXPECT_MIN_CHARS:-1}"
CHARS=$(wc -c < /tmp/vibe-output.md 2>/dev/null | tr -d ' ')
if [ "${CHARS:-0}" -lt "$EXPECT_MIN_CHARS" ]; then
  echo "ERROR: Vibe output too small (${CHARS} chars)" >&2
  exit 1
fi
```

## Critical Gotchas

1. **`-p` is MANDATORY for automation** — without it, CLI enters interactive TUI and hangs
2. **Always wrap with `$GTIMEOUT`** — CLI can hang on tool call failures
3. **Character count > line count** — Vibe produces compact, dense output
4. **No `--model` flag** — model selection is config-only (`~/.vibe/config.toml` or `--agent`)
5. **`2>/dev/null` recommended** — stderr can contain progress/status noise
6. **Exit codes**: `0` = success, `1` = error, `124` = timeout (from gtimeout)
7. **Concurrency**: Max 3 simultaneous Vibe processes
8. **`--workdir`** sets the project root — Vibe reads project context from this directory
9. **Positional prompt** (without `-p`) enters interactive mode — never use in automation
10. **Broad repo-analysis prompts can hit turn limits** — keep analysis prompts
    narrow, name the target files/directories, and prefer `--enabled-tools`
    for focused read-only runs.
11. **`--agent plan` is not a lightweight analysis profile** — it activates
    Vibe plan mode and is a poor fit for one-shot CLI calls.
12. **Code-generation prompts must name the exact coding scope** — specify the
    work unit, target files, expected output format, and what not to touch.
    Do not ask Vibe to discover the scope itself.

## Concurrency Limit (MANDATORY)

```bash
PID_FILE=/tmp/vibe-slots.pid

# Prune dead entries
if [ -f "$PID_FILE" ]; then
  while IFS= read -r pid; do
    ps -p "$pid" >/dev/null 2>&1 && echo "$pid"
  done < "$PID_FILE" > "${PID_FILE}.tmp"
  mv "${PID_FILE}.tmp" "$PID_FILE"
fi

# Check slot availability (max 3)
ACTIVE=$(wc -l < "$PID_FILE" 2>/dev/null || echo 0)
if [ "$ACTIVE" -ge 3 ]; then
  echo "All 3 Vibe slots occupied — queuing or skipping"
  # Queue or exit based on your workflow
fi

# After launching, append PID
echo $! >> /tmp/vibe-slots.pid
```

## Fallback Behavior

| Failure Mode | Fallback |
|---|---|
| CLI not installed | Try Codex (`/codex`); then Claude direct generation |
| Timeout (exit 124) | Retry once with 240s; then try Codex |
| Turn limit reached (exit 1 + `vibe_stop_event`) | Tighten the prompt, name specific files, restrict tools, or switch to Cursor/Codex for repo-wide analysis |
| Empty output | Retry with more `--max-turns`; then try Codex |
| Rate limit | Queue and retry after 60s; then try Codex |

## Real-World Examples (From meta-execute)

```bash
# Generation work unit (meta-execute pattern)
$GTIMEOUT 180 "$VIBE" \
  -p "$(cat /tmp/wu-feature-x-prompt.md)" \
  --output text \
  --max-turns 15 \
  --workdir /path/to/project \
  2>/dev/null > /tmp/wu-feature-x-vibe.md
```

```bash
# Parallel generation with Codex as second generator
# (Vibe invocation as above, background'd; then for Codex:)
# Load /codex for invocation syntax. Key params:
# --sandbox workspace-write, --ephemeral, --cd /path/to/project, 180s timeout.
# Prompt: $(cat /tmp/prompt.md). Output to /tmp/codex-output.md (background).
#
# wait for both PIDs, then compare /tmp/vibe-output.md and /tmp/codex-output.md
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
