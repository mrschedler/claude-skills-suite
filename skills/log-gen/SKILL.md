---
name: log-gen
description: Generates logging instrumentation from log-review findings or for uninstrumented code. Use after log-review or when adding observability to a module.
disable-model-invocation: true
---

# Log Gen

Adds logging instrumentation to code that lacks observability. Takes log-review
findings and implements the fixes — adding structured logging, error context,
correlation IDs, and API boundary logging. Like test-gen for tests, but for
observability.

This skill exists because adding logging is tedious but critical, and LLM-generated
code almost never includes adequate logging on its own.

## Inputs

| Input | Source | Required |
|---|---|---|
| log-review findings | Artifact DB or direct scan | Yes (or target files) |
| project-context.md | Project root | Yes |
| Logger configuration | Project root | Recommended |
| Target files | User-specified or from findings | Yes |

**Finding the input**: Check the artifact DB first:
```bash
source artifacts/db.sh
db_read 'log-review' 'findings' 'standalone'
```
If no findings exist, ask the user to run `/log-review` first, or accept a list
of target files to instrument directly.

## Outputs

- Modified source files with logging added
- Logger setup file created if none exists (e.g., `src/lib/logger.ts`, `app/core/logging.py`)

## Instructions

### 1. Load Context

Read `project-context.md` to understand:
- Language and framework (determines logger library)
- Deployment environment (determines log format — JSON for cloud, structured for ELK)
- Existing logging setup (add to it, don't create a competing one)

### 2. Detect or Create Logger

Check if the project already has a logger configured:

**Node.js/TypeScript**: Look for `winston`, `pino`, `bunyan`, `morgan` in `package.json`
**Python**: Look for `logging`, `structlog`, `loguru` imports
**Go**: Look for `log/slog`, `zap`, `logrus`, `zerolog` imports
**Java**: Look for `slf4j`, `log4j`, `logback` in dependencies
**Rust**: Look for `tracing`, `log`, `env_logger` in `Cargo.toml`

If no logger exists, create a minimal structured logger setup using the idiomatic
library for the language. Prefer structured/JSON loggers:
- Node.js → pino (fastest) or winston (most common)
- Python → structlog
- Go → log/slog (stdlib, no dependency)
- Prefer the project's existing patterns. Don't introduce a new library if one exists.

### 3. Parse Findings and Prioritize

Read log-review findings (from DB or user input). Group by category:

1. **Silent failures** (CRITICAL) — fix first, these hide production errors
2. **Error context** (HIGH) — add context to existing error handlers
3. **API boundaries** (HIGH) — add request/response logging at system edges
4. **Correlation IDs** (MEDIUM) — add request ID generation and propagation
5. **Log hygiene** (LOW) — fix format inconsistencies, remove PII

Present the grouped findings to the user and ask which to implement.

### 4. Implement Fixes

For each approved finding, implement the logging fix:

**Silent failures**: Replace empty catches with proper error logging:
```typescript
// Before
catch (e) {}

// After
catch (e) {
  logger.error({ err: e, operation: 'fetchUser', userId }, 'Operation failed');
  throw e; // or handle gracefully with logging
}
```

**Error context**: Add structured context to error logs:
```python
# Before
except Exception as e:
    logger.error(f"Failed: {e}")

# After
except Exception as e:
    logger.error("operation_failed", operation="fetch_user", user_id=user_id, exc_info=True)
```

**API boundaries**: Add middleware or interceptors for request/response logging.

**Correlation IDs**: Add request ID middleware that generates and propagates IDs.

Key rules:
- Match the project's existing code style exactly
- Use the project's existing logger — don't import a different one
- Log at appropriate levels (ERROR for failures, INFO for business events, DEBUG for internals)
- Include structured context (key-value pairs), not string interpolation
- Never log sensitive data (passwords, tokens, PII) — redact or omit

### 5. Verify

After implementing:
- Confirm the project still compiles / passes lint
- Check that no PII or secrets are being logged
- Verify log levels are appropriate (no INFO logging in hot paths)
- Ensure new logging doesn't break existing tests (mocking may need updates)

## Integration Points

This skill can be invoked from:
- **`/review-fix`** — when log-review findings are part of a meta-review synthesis, review-fix can dispatch log-gen to implement logging fixes
- **`/meta-execute`** — during implementation, log-gen can be run as a post-generation pass to add logging to newly written code
- **Standalone** — user runs `/log-gen` directly after `/log-review`

## Examples

```
User: [after log-review] "Fix the logging gaps"
→ Parse log-review findings from DB. Present grouped findings. Implement approved fixes.
```

```
User: "Add logging to src/api/routes/"
→ No prior findings needed. Scan the target directory for logging gaps, then instrument.
```

```
User: "We need structured logging throughout the project"
→ Create logger setup if missing. Scan for console.log/print statements. Replace with structured logger calls.
```

```
User: "Add correlation IDs to our API"
→ Focus on §4 correlation ID implementation. Add request ID middleware and propagation.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
