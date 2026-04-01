---
name: codex
description: Driver skill for Codex CLI. Provides codex-exec.sh wrapper — call the script, not raw CLI. Load before any Codex invocation.
disable-model-invocation: true
---

# Codex CLI Driver

Use the wrapper script for ALL Codex invocations. Never construct raw
`codex exec` commands — the wrapper handles path resolution, timeout,
MCP, concurrency, and output routing.

## Wrapper Script

**Location**: `skills/codex/scripts/codex-exec.sh`

### API

```
codex-exec.sh <mode> [options] "PROMPT"
codex-exec.sh <mode> [options] --stdin /path/to/prompt.md
```

### Modes

| Mode | Sandbox | Default Timeout | Use Case |
|------|---------|-----------------|----------|
| `review` | read-only | 180s | Code review, analysis, lint |
| `generate` | workspace-write | 180s | Code generation, file writes |
| `full-access` | danger-full-access | 300s | Tasks needing network (rare) |

### Options

| Option | Description |
|--------|-------------|
| `--cd DIR` | Working directory for Codex |
| `--output FILE` | Write final message to file |
| `--timeout SECS` | Override default timeout |
| `--stdin FILE` | Read prompt from file (use for long prompts) |
| `--with-mcp` | Keep MCP servers enabled (disabled by default) |
| `--add-dir DIR` | Additional writable directory |
| `--schema FILE` | JSON schema for structured output |
| `--json` | Output JSONL events |
| `--reasoning high` | Increase model reasoning effort |
| `--model MODEL` | Override model |
| `--skip-concurrency` | Skip PID-based slot tracking |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Codex unavailable or config error |
| 2 | All 5 concurrency slots occupied |
| 3 | Invalid arguments |
| 124 | Timeout |

## Examples

### Quick review (most common)

```bash
skills/codex/scripts/codex-exec.sh review \
  --cd /path/to/project \
  --output /tmp/codex-review.md \
  "Review for security issues. Focus on input validation and auth."
```

### Code generation

```bash
skills/codex/scripts/codex-exec.sh generate \
  --cd /path/to/project \
  --timeout 180 \
  "Add input validation to all API route handlers"
```

### Long prompt from file

```bash
skills/codex/scripts/codex-exec.sh review \
  --cd /path/to/project \
  --output /tmp/codex-review.md \
  --stdin /tmp/review-prompt.md
```

### Structured JSON output

```bash
skills/codex/scripts/codex-exec.sh review \
  --cd /path/to/project \
  --schema skills/codex/schemas/review-findings-schema.json \
  --output /tmp/findings.json \
  "List all security findings"
```

### Background with concurrency tracking (for meta-review waves)

```bash
skills/codex/scripts/codex-exec.sh review \
  --cd /path/to/project \
  --output /tmp/codex-security.md \
  --stdin /tmp/security-prompt.md &
CODEX_PID=$!
# ... launch more (up to 5 total) ...
wait $CODEX_PID
```

## Concurrency

Max **5** concurrent Codex processes (hard limit from `general.md`).
The wrapper tracks active processes via `/tmp/codex-slots.pid` and
blocks if all slots are occupied (retries 3x with 10s waits).

Use `--skip-concurrency` only for quick one-off tests, never in
multi-model workflows.

## MCP Servers

Disabled by default for speed (saves 3-10s startup). Pass `--with-mcp`
when the task needs GitHub/SSH context. Current servers in
`~/.codex/config.toml`: `homelab-gateway`, `ssh-tower`, `github`.

## Gotchas the Wrapper Does NOT Handle

1. **Prompts must be self-contained** — Codex `exec` auto-cancels all
   clarifying questions. Include all context in the prompt.
2. **`--json` outputs JSONL** — each line is a separate event. Parse
   line-by-line with `jq -s` or per-line processing.
3. **Output validation** — check `wc -c` (expect >= 100 chars). The
   wrapper warns on files < 10 bytes but does not retry.
4. **Schema validation** — OpenAI structured outputs require
   `additionalProperties: false` in all schema objects. Use the
   provided schema in `schemas/review-findings-schema.json` as a
   template.

## Model

Reads from `~/.codex/config.toml` (currently `gpt-5.4`). Override
with `--model o3` or `--model gpt-5.4`.

## Fallback

If Codex is unavailable (exit 1), skip the Codex portion and note
"Codex unavailable" in output. There is no direct substitute.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
