---
name: gemini
description: Driver skill for Gemini CLI syntax, flags, and gotchas. Load this before spawning any Gemini call. Use when other skills need Gemini or user says "use Gemini".
---

# Gemini CLI Driver

Encode the exact Gemini CLI invocation for a given task type. This is a
utility skill — it provides command templates that other skills compose into
their workflows. It is not triggered directly by the user in most cases.

## PATH & Absolute Paths

`run_in_background` and subagent Bash calls spawn non-interactive subshells
that do NOT source `.zshrc`/`.zprofile`. Custom PATH entries are missing.

**Use absolute paths for all Gemini invocations:**

```
/Users/trevorbyrum/.npm-global/bin/gemini
```

Fallback location (if installed via Homebrew): `/opt/homebrew/bin/gemini`

Every template below uses the absolute path. Do not use bare `gemini`.

## Concurrency Limit (MANDATORY)

Gemini supports a maximum of **2** simultaneous processes. Exceeding this
causes rate-limit errors and wasted tokens. If you need to run more than 2,
queue excess tasks and launch them as slots free up — identical to the Codex
5-slot pattern in `/codex`. This limit is set in `general.md` and applies to
ALL skills.

## Availability Check

Before any invocation, verify the CLI is installed:

```bash
GEMINI="/Users/trevorbyrum/.npm-global/bin/gemini"
test -x "$GEMINI" || GEMINI="/opt/homebrew/bin/gemini"
test -x "$GEMINI" || { echo "Gemini CLI not installed"; exit 1; }
```

If unavailable, fall back:
- **Web research tasks**: use Claude WebSearch instead.
- **Review / critique tasks**: skip and note "Gemini unavailable" in output.

## Environment Safety

Gemini CLI is sensitive to environment variables that change its behavior.
Before every call, clean the environment:

```bash
unset DEBUG 2>/dev/null        # DEBUG causes CLI to hang trying to attach a debugger
unset CI 2>/dev/null           # CI_* vars force non-interactive detection
unset GOOGLE_CLOUD_PROJECT 2>/dev/null  # Triggers org subscription check for personal accounts
```

These unsets go on the same line or in a wrapper function — they only affect
the current shell invocation.

## Timeout Binary (MANDATORY)

macOS ships NO `timeout` command. The zsh alias `timeout=gtimeout` only
works in interactive shells — subagents, `run_in_background`, and bare
bash subshells do NOT have it. Using bare `timeout` in these contexts
invokes a perl-based alarm wrapper that **breaks Gemini** (SIGALRM kills
the process incorrectly).

**Always use the absolute path to GNU coreutils `gtimeout`:**

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
test -x "$GTIMEOUT" || { echo "gtimeout not installed (brew install coreutils)"; exit 1; }
```

Every template below uses `$GTIMEOUT`. Do not use bare `timeout`.

## Sub-Agent Types

Gemini CLI has three built-in sub-agents. Specify the right one per task:

| Sub-Agent | Use For | Flag |
|---|---|---|
| `codebase_investigator` | Reviews, architectural analysis, bug root-cause hunting | `--agent codebase_investigator` |
| `generalist` | High-volume batch tasks, speculative research, web grounding | `--agent generalist` |
| `cli_help` | Questions about Gemini CLI features and configuration | `--agent cli_help` |

### Routing by Skill Context

| Calling Skill | Sub-Agent |
|---|---|
| counter-review, security-review, refactor-review, drift-review, completeness-review, compliance-review, test-review | `codebase_investigator` |
| research-execute, project-questions | `generalist` |
| skill-doctor (Gemini CLI diagnostics) | `cli_help` |

If no sub-agent is specified, Gemini uses its default routing. Explicit
selection is preferred for consistency.

## Task-Type Templates

### Research / Analysis

The bread-and-butter use case. Gemini has native Google Search grounding,
making it superior to other CLIs for web research.

```bash
unset DEBUG 2>/dev/null
$GTIMEOUT 120 "$GEMINI" --agent generalist -p "PROMPT" 2>/dev/null > OUTPUT_FILE
```

### File Context (@-syntax)

Gemini supports `@path/to/file` inline references to include file contents
in the prompt without piping.

```bash
unset DEBUG 2>/dev/null
$GTIMEOUT 60 "$GEMINI" --agent codebase_investigator -p "Review @src/index.ts for security issues" 2>/dev/null > OUTPUT_FILE
```

### Long Prompt via stdin

For prompts too long to pass as a `-p` argument, pipe from a file:

```bash
unset DEBUG 2>/dev/null
cat /path/to/prompt.md | $GTIMEOUT 120 "$GEMINI" 2>/dev/null > OUTPUT_FILE
```

### JSON Output

Use `--output-format json` (there is no `-o` short flag) and extract the
response field with `jq`:

```bash
unset DEBUG 2>/dev/null
$GTIMEOUT 120 "$GEMINI" -p "PROMPT" --output-format json 2>/dev/null | jq -r '.response' > OUTPUT_FILE
```

### Model Selection

Override the default model when a specific model is needed (e.g., Pro for
harder reasoning):

```bash
unset DEBUG 2>/dev/null
$GTIMEOUT 120 "$GEMINI" -m gemini-2.5-pro -p "PROMPT" 2>/dev/null > OUTPUT_FILE
```

## Output Validation (MANDATORY)

Gemini produces **very long lines** — a typical response may be only 5-10 lines
but each line can be 500-2000+ characters. **Do NOT judge output quality by
line count.** An 8-line response with 4000+ characters is a full, valid response.

**Validation rules:**
1. Check character count, not line count: `wc -c < OUTPUT_FILE` — expect ≥ 200
   chars for a real response
2. Check for empty/error: `[ -s OUTPUT_FILE ]` (file exists and is non-empty)
3. An output with < 50 characters is likely a failure or error message

**For structured parsing**, use `--output-format json` and extract with `jq`:

```bash
unset DEBUG 2>/dev/null
$GTIMEOUT 120 "$GEMINI" -p "PROMPT" --output-format json 2>/dev/null | jq -r '.response' > OUTPUT_FILE
# Validate: at least 200 chars
CHARS=$(wc -c < OUTPUT_FILE 2>/dev/null | tr -d ' ')
if [ "${CHARS:-0}" -lt 50 ]; then
  echo "Gemini output too small (${CHARS} chars) — likely failed"
fi
```

**For review/research tasks**, prefer `--output-format json` + `jq` extraction
over raw text mode. This avoids ANSI artifacts and makes character-count
validation reliable.

## Critical Gotchas

1. **Always wrap with `$GTIMEOUT`** (absolute path, never bare `timeout`)
   — the CLI hangs indefinitely if a tool call is denied in `-p`
   (non-interactive) mode. 120s is the standard ceiling for research
   tasks; use 60s for reviews and 30s for quick lookups.

2. **No `-o` short flag** — the output format flag is `--output-format`
   with values `text`, `json`, or `stream-json`. Using `-o` will error or
   be misinterpreted.

3. **No `-y` short flag** — use `--yolo` if you need to auto-approve tool
   calls. This is rarely needed in non-interactive mode.

4. **`--allowed-tools` is broken in non-interactive mode** — if the task
   needs Gemini to use its built-in tools (Google Search, code execution),
   pass `--yolo` instead.

5. **Rate limits** — free tier allows 60 requests per minute and 1,000
   requests per day. If you hit 429 errors, back off or switch to Claude
   WebSearch.

6. **Exit codes**:
   - `0` — success
   - `41` — authentication failure
   - `42` — input error (bad flags, bad prompt)
   - `130` — cancelled (timeout or Ctrl-C)

7. **`2>/dev/null` is mandatory** — stderr contains progress spinners and
   ANSI codes that corrupt file output and inflate context size.

## Fallback Behavior

| Failure Mode | Fallback |
|---|---|
| CLI not installed | Claude WebSearch for research; skip for review |
| Timeout (exit 130) | Retry once with 180s; then fall back to WebSearch |
| Auth failure (exit 41) | Skip and note "Gemini auth failed" |
| Rate limit (HTTP 429) | Claude WebSearch for the current task |
| Capacity exhausted | Claude WebSearch for the current task |

## Examples

```
Skill (research): Needs web research on "Kubernetes operator patterns 2026".
--> unset DEBUG 2>/dev/null
    $GTIMEOUT 120 "$GEMINI" -p "Research current Kubernetes operator patterns and best practices as of 2026. Include framework comparisons." 2>/dev/null > /tmp/k8s-operator-research.md
```

```
Skill (counter-review): Needs Gemini to review a file for architecture issues.
--> unset DEBUG 2>/dev/null
    $GTIMEOUT 60 "$GEMINI" -p "Review @src/server.ts for architectural issues: over-abstraction, missing error handling, scaling bottlenecks. Be specific." 2>/dev/null > /tmp/gemini-review.md
```

```
Skill (plan): Needs devil's advocate perspective on a proposed architecture.
--> unset DEBUG 2>/dev/null
    cat /tmp/architecture-proposal.md | $GTIMEOUT 120 "$GEMINI" 2>/dev/null > /tmp/gemini-critique.md
```

```
Skill (parallel review): Firing Gemini alongside Codex and Claude for multi-model review.
--> unset DEBUG 2>/dev/null
    $GTIMEOUT 120 "$GEMINI" -p "$(cat /tmp/review-prompt.md)" 2>/dev/null > /tmp/gemini-review-output.md &
    GEMINI_PID=$!
    # ... launch other reviews ...
    wait $GEMINI_PID
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
