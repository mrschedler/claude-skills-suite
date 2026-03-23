---
name: gemini
description: Driver skill for Gemini CLI syntax, flags, and gotchas. Load this before spawning any Gemini call. Use when other skills need Gemini or user says "use Gemini".
disable-model-invocation: true
---

# Gemini CLI Driver

Encode the exact Gemini CLI invocation for a given task type. This is a
utility skill. Other skills should delegate syntax, path resolution, model
selection, timeout handling, and fallback logic here instead of duplicating
CLI flags.

## PATH & Availability

`run_in_background` and non-interactive subshells may miss shell aliases and
custom startup files. Resolve the real binary path first. Do not hardcode a
username-specific install path.

```bash
GEMINI="$(whence -p gemini 2>/dev/null)"
[ -n "$GEMINI" ] || GEMINI="$(type -P gemini 2>/dev/null)"

if [ -z "$GEMINI" ] && [ -d "$HOME/.nvm/versions/node" ]; then
  GEMINI="$(find "$HOME/.nvm/versions/node" -path '*/bin/gemini' \( -type f -o -type l \) -print 2>/dev/null | sort -V | tail -n 1)"
fi

if [ -z "$GEMINI" ] && [ -x /opt/homebrew/bin/gemini ]; then
  GEMINI="/opt/homebrew/bin/gemini"
fi
if [ -z "$GEMINI" ] && [ -x /usr/local/bin/gemini ]; then
  GEMINI="/usr/local/bin/gemini"
fi
if [ -z "$GEMINI" ] && [ -x "$HOME/.npm-global/bin/gemini" ]; then
  GEMINI="$HOME/.npm-global/bin/gemini"
fi
[ -n "$GEMINI" ] || { echo "Gemini CLI not installed"; exit 1; }
```

Local validation on this machine found the live binary at:

```bash
/Users/byrum_work/.nvm/versions/node/v24.13.0/bin/gemini
```

The old hardcoded path
`/Users/trevorbyrum/.npm-global/bin/gemini` failed with `No such file or directory`.

If unavailable, fall back:
- **Web research tasks**: use Claude WebSearch.
- **Review / critique tasks**: retry with Copilot, then skip and note the gap.

## Concurrency Limit (MANDATORY)

Gemini supports a maximum of **2** simultaneous processes. Exceeding this
causes rate-limit errors and wasted tokens. Queue excess tasks exactly like
the Codex 5-slot pattern in `/codex`.

## Environment Safety

Gemini CLI is sensitive to environment variables that change runtime behavior.
Before every call, clear the high-risk variables:

```bash
unset DEBUG 2>/dev/null                # validated: floods stderr and changes runtime behavior
unset GOOGLE_CLOUD_PROJECT 2>/dev/null # validated: broke auth flow on this machine
unset CI 2>/dev/null                   # harmless to clear in automation; did not break simple prompts when set
```

## Timeout Binary (MANDATORY)

Do not rely on a shell alias for `timeout`. Resolve a real binary:

```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
[ -x "$GTIMEOUT" ] || GTIMEOUT="$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)"
[ -n "$GTIMEOUT" ] || { echo "GNU timeout not installed (brew install coreutils)"; exit 1; }
```

Use `$GTIMEOUT` in every non-interactive invocation.

## Headless Output Mode (MANDATORY)

Prefer JSON output in automation. Live testing on Gemini CLI `0.33.0` showed:

- `-o json` and `--output-format json` both work.
- Raw text `-p "..."` was flaky and timed out in local testing.
- Successful runs still emit startup noise on stderr (`Loaded cached credentials`,
  extension loading, MCP notices), so redirect stderr away from output files.

**Standard automation pattern:**

```bash
unset DEBUG 2>/dev/null
unset GOOGLE_CLOUD_PROJECT 2>/dev/null
unset CI 2>/dev/null
$GTIMEOUT 120 "$GEMINI" -m gemini-2.5-flash-lite -o json -p "PROMPT" 2>/dev/null | jq -r '.response // empty' > OUTPUT_FILE
```

## Subagents (Current CLI Behavior)

Gemini CLI `0.33.0` does **not** expose a top-level `--agent` flag. Local test:

```bash
$GEMINI --agent codebase_investigator -p "Reply with OK."
# -> exit 1, stderr starts with: Unknown argument: agent
```

Use prompt forcing instead: start the prompt with `@subagent_name`.

| Subagent | Use For | Invocation |
|---|---|---|
| `codebase_investigator` | Deep codebase analysis, architecture review, dependency tracing | `-p "@codebase_investigator ..."` |
| `cli_help` | Interactive/manual Gemini CLI questions | `-p "@cli_help ..."` |
| `generalist_agent` | Internal routing agent | Do **not** force in automation; use plain `-p` |
| `browser_agent` | Experimental browser automation | Avoid in normal skill flows; disabled by default |

### Routing by Skill Context

| Calling Skill | Preferred Pattern |
|---|---|
| counter-review, security-review, refactor-review, drift-review, completeness-review, compliance-review, test-review | Plain file-context prompt first; escalate to `@codebase_investigator` only when the environment supports it |
| research-execute, project-questions, release-prep | Plain research/analysis prompt; do not force `@generalist_agent` |
| skill-doctor | Use `gemini --help`, `gemini skills --help`, `gemini mcp --help` directly; do not rely on `@cli_help` in automation |

### Built-in Subagent Reliability

Built-in subagents currently route to preview models on this machine:

- `codebase_investigator` defaulted to `gemini-3.1-pro-preview`
- `generalist` defaulted to `gemini-3-flash-preview`

In local testing, both hit `429 MODEL_CAPACITY_EXHAUSTED` in headless runs.
The subagent mechanism itself still works, but callers need a fallback plan.

**Preferred order:**
1. Try a plain `-p` prompt with explicit `@file` references and a pinned model.
2. Force `@codebase_investigator` only if you specifically need the specialist.
3. If forced subagents repeatedly 429, retry with Copilot or use a local agent override.

### Optional Agent Override Workaround

If `@codebase_investigator` keeps failing on preview-model capacity, run from an
isolated working directory that contains:

```json
{
  "agents": {
    "overrides": {
      "codebase_investigator": {
        "modelConfig": { "model": "gemini-2.5-flash-lite" },
        "runConfig": { "maxTurns": 10 }
      }
    }
  }
}
```

Local validation confirmed that this override restored successful headless
`@codebase_investigator` runs.

## Task-Type Templates

### Research / Analysis

Use plain headless prompts. Do not force `@generalist_agent`.

```bash
unset DEBUG 2>/dev/null
unset GOOGLE_CLOUD_PROJECT 2>/dev/null
unset CI 2>/dev/null
$GTIMEOUT 120 "$GEMINI" -m gemini-2.5-flash-lite -o json -p "PROMPT" 2>/dev/null | jq -r '.response // empty' > OUTPUT_FILE
```

### File Context (`@path`)

Gemini supports inline file references in the prompt.

```bash
unset DEBUG 2>/dev/null
unset GOOGLE_CLOUD_PROJECT 2>/dev/null
unset CI 2>/dev/null
$GTIMEOUT 60 "$GEMINI" -m gemini-2.5-flash-lite -o json --approval-mode plan -p "Review @src/index.ts for security issues" 2>/dev/null | jq -r '.response // empty' > OUTPUT_FILE
```

### Forced `@codebase_investigator` (Optional)

Use only when you need deeper codebase analysis than a plain file-context
prompt gives you.

```bash
unset DEBUG 2>/dev/null
unset GOOGLE_CLOUD_PROJECT 2>/dev/null
unset CI 2>/dev/null
$GTIMEOUT 60 "$GEMINI" -o json --approval-mode plan -p "@codebase_investigator Review @src/index.ts for architectural issues" 2>/dev/null | jq -r '.response // empty' > OUTPUT_FILE
```

If this returns capacity errors, retry with Copilot or apply the local agent
override shown above.

### Long Prompt via stdin

stdin still works in headless mode. Local validation:
`printf 'Reply with exactly PIPE_OK.' | gemini -m gemini-2.5-flash-lite -o json -p ''`.

```bash
unset DEBUG 2>/dev/null
unset GOOGLE_CLOUD_PROJECT 2>/dev/null
unset CI 2>/dev/null
cat /path/to/prompt.md | $GTIMEOUT 120 "$GEMINI" -m gemini-2.5-flash-lite -o json -p '' 2>/dev/null | jq -r '.response // empty' > OUTPUT_FILE
```

### CLI Diagnostics

For Gemini CLI diagnostics, prefer native help commands over `@cli_help`:

```bash
"$GEMINI" --help
"$GEMINI" skills --help
"$GEMINI" mcp --help
"$GEMINI" hooks --help
```

### Model Selection

Pin a model explicitly for automation. `gemini-2.5-flash-lite` was the most
reliable local choice in testing; move to `gemini-2.5-pro` only when needed.

```bash
unset DEBUG 2>/dev/null
unset GOOGLE_CLOUD_PROJECT 2>/dev/null
unset CI 2>/dev/null
$GTIMEOUT 120 "$GEMINI" -m gemini-2.5-pro -o json -p "PROMPT" 2>/dev/null | jq -r '.response // empty' > OUTPUT_FILE
```

## Output Validation (MANDATORY)

Validate the extracted response, not line count:

```bash
CHARS=$(wc -c < OUTPUT_FILE 2>/dev/null | tr -d ' ')
if [ "${CHARS:-0}" -lt 50 ]; then
  echo "Gemini output too small (${CHARS:-0} chars) — likely failed"
fi
```

Rules:
1. Prefer `--output-format json` / `-o json`.
2. Extract `.response` with `jq -r '.response // empty'`.
3. Treat any empty output, or any research/review output under ~50 chars, as failure.
4. Inspect stderr for startup noise, 429s, auth errors, or deprecated-flag warnings.

## Critical Gotchas

1. **`--agent` is invalid on Gemini CLI 0.33.0**. Use `@subagent` at the start of the prompt.
2. **`-o` exists**. The old "no short flag" guidance is wrong; `-o json` worked in local tests.
3. **`-y` exists**. The old "no short flag" guidance is wrong; `-y` and `--yolo` both worked.
4. **`--allowed-tools` is deprecated, not gone**. It still parses on 0.33.0, but Gemini warns to migrate to the Policy Engine. Avoid relying on it in new templates.
5. **stderr is noisy even on success**. Redirect it away from output files.
6. **`GOOGLE_CLOUD_PROJECT` can break auth/subscription resolution**. Clear it before automation.
7. **`@cli_help` was unreliable in headless automation** on this machine. It timed out and logged unauthorized-tool errors. Use native help commands instead.
8. **Do not rely on a fixed exit-code map**. Local tests observed: success `0`, bad flag `1`, wrapper timeout `124`. Treat any non-zero exit as failure and inspect stderr.

## Fallback Behavior

**Copilot is Gemini's primary fallback.** When Gemini fails for any reason,
retry with Copilot (`/copilot`) before falling back to WebSearch or skipping.

| Failure Mode | Fallback |
|---|---|
| CLI not installed | Try Copilot; then Claude WebSearch for research; skip for review |
| Timeout / wrapper timeout | Retry once with a longer timeout; then Copilot; then WebSearch |
| Auth failure | Try Copilot; then skip and note "Gemini+Copilot unavailable" |
| 429 / capacity exhausted | Retry once with a pinned stable model or local agent override; then Copilot; then Claude WebSearch |
| Empty output | Retry with JSON mode and pinned model; then Copilot |

## Examples

```
Skill (research): Needs current Kubernetes operator patterns.
--> unset DEBUG 2>/dev/null
    unset GOOGLE_CLOUD_PROJECT 2>/dev/null
    unset CI 2>/dev/null
    $GTIMEOUT 120 "$GEMINI" -m gemini-2.5-flash-lite -o json -p "Research current Kubernetes operator patterns and best practices as of 2026. Include framework comparisons." 2>/dev/null | jq -r '.response // empty' > /tmp/k8s-operator-research.md
```

```
Skill (review): Needs architecture feedback on a source file.
--> unset DEBUG 2>/dev/null
    unset GOOGLE_CLOUD_PROJECT 2>/dev/null
    unset CI 2>/dev/null
    $GTIMEOUT 60 "$GEMINI" -m gemini-2.5-flash-lite -o json --approval-mode plan -p "Review @src/server.ts for architectural issues: over-abstraction, missing error handling, scaling bottlenecks. Be specific." 2>/dev/null | jq -r '.response // empty' > /tmp/gemini-review.md
```

```
Skill (deep review): Needs the codebase specialist specifically.
--> unset DEBUG 2>/dev/null
    unset GOOGLE_CLOUD_PROJECT 2>/dev/null
    unset CI 2>/dev/null
    $GTIMEOUT 60 "$GEMINI" -o json --approval-mode plan -p "@codebase_investigator Map the dependency chain from @src/index.ts to @src/db/client.ts and flag architectural risks." 2>/dev/null | jq -r '.response // empty' > /tmp/gemini-review.md
```

```
Skill (stdin prompt): Needs a long prompt from a temp file.
--> unset DEBUG 2>/dev/null
    unset GOOGLE_CLOUD_PROJECT 2>/dev/null
    unset CI 2>/dev/null
    cat /tmp/review-prompt.md | $GTIMEOUT 120 "$GEMINI" -m gemini-2.5-flash-lite -o json -p '' 2>/dev/null | jq -r '.response // empty' > /tmp/gemini-review-output.md
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
