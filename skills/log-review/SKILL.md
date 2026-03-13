---
name: log-review
description: Audits logging and observability gaps — silent catches, missing context, no structured logging, absent trace IDs. Use before deploys or after implementation sprints.
---

# Log Review

Finds logging and observability gaps that make production debugging impossible.
Code that fails silently, swallows errors, or logs without context turns every
incident into a guessing game. This skill exists because LLM-generated code
routinely omits logging entirely — happy-path code with zero observability.

## Inputs

- The full codebase
- `project-context.md` — to understand deployment environment and observability stack
- Logger configuration files (if any) — winston, pino, structlog, slog, log4j configs

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'log-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings:
  - Sonnet: `db_upsert 'log-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'log-review' 'findings' 'codex' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'log-review' 'findings' 'standalone')
```
If `$AGE` is non-empty and less than 24, report: "Found fresh log-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB. If no record exists or user says no, proceed with a fresh scan.

### 1. Load Context

Read `project-context.md` to understand:
- What observability stack is in use? (ELK, Grafana/Loki, Datadog, CloudWatch, etc.)
- Is structured logging configured? (JSON logs vs plaintext)
- Is distributed tracing in use? (OpenTelemetry, Jaeger, X-Ray)
- What environments exist? (dev, staging, prod — logging needs differ)
- Is this a monolith or distributed system? (distributed = correlation IDs are critical)

### 2. Logging Framework Assessment

Check if the project has a consistent logging setup:
- Is there a centralized logger configuration, or does each file use its own?
- Are log levels used correctly? (DEBUG for dev detail, INFO for business events, WARN for recoverable issues, ERROR for failures)
- Is the logger structured (key-value / JSON) or unstructured (string concatenation)?
- Are there `console.log`, `print()`, `System.out.println` in production code? (Flag as MEDIUM — should use proper logger)

### 3. Silent Failure Scan (CRITICAL)

Search for code that swallows errors:
- Empty `catch` blocks — `catch (e) {}` or `except: pass`
- Catch blocks that only log the message but not the stack trace
- `.catch(() => {})` or `.catch(console.log)` in promise chains
- Error handlers that return default values without logging
- `try/finally` without `catch` where failure should be logged
- Async operations with no `.catch()` or `try/catch` wrapper
- Event handlers that silently fail (`on('error', () => {})`)

Every silent failure is a potential hours-long debugging session in production.

### 4. Error Context Scan (HIGH)

Check that errors include sufficient debugging context:
- Are caught errors logged with the original error object (stack trace preserved)?
- Do error logs include relevant request/operation context? (user ID, request ID, operation name)
- Are errors re-thrown with context added, or just swallowed?
- Do error messages distinguish between types of failure? ("Failed to connect" vs "Connection refused on port 5432 after 3 retries")
- Are error codes or categories used for alerting/filtering?

### 5. API Boundary Logging (HIGH)

Check logging at system boundaries:
- **Inbound requests**: Are HTTP requests logged? (method, path, status code, duration)
- **Outbound calls**: Are external API calls, DB queries, and cache operations logged?
- **Queue/event processing**: Are message consumption and publishing logged?
- **Auth events**: Are login attempts, failures, token refreshes, and permission denials logged?
- **Business events**: Are significant state changes logged? (order placed, user registered, payment processed)

Missing boundary logging means you can't trace a request through the system.

### 6. Correlation & Tracing (MEDIUM)

Check for request tracing infrastructure:
- Is there a request/correlation ID generated at ingress and propagated through the call chain?
- Do log entries include the correlation ID?
- Are trace IDs propagated to downstream service calls?
- Can you trace a single user request from ingress to response across all services?
- Are background jobs / async operations tied back to the originating request?

### 7. Log Hygiene (MEDIUM/LOW)

Check for log anti-patterns:
- **PII in logs**: Are passwords, tokens, SSNs, emails, or credit card numbers logged? (Flag as HIGH — cross-reference with security-review)
- **Excessive logging**: Are hot-path operations logging at INFO level? (Causes log flood, storage cost)
- **Missing log rotation**: Are log files unbounded? (Causes disk exhaustion)
- **Inconsistent format**: Do some modules log JSON while others log plaintext? (Breaks parsing)
- **Hardcoded log levels**: Can log levels be changed at runtime without redeployment?
- **Missing timestamps**: Do all log entries have timestamps?

### 8. Produce Findings

Write findings with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Silent Failure | Error Context | API Boundary | Correlation | Log Hygiene | Framework
**Location**: file/path:line
**Severity**: CRITICAL | HIGH | MEDIUM | LOW

**Problem**: What observability gap exists.

**Evidence**: Code snippet showing the issue.

**Impact**: What happens during an incident because of this gap.

**Recommendation**: Specific fix with code example.
```

Severity levels:
- **CRITICAL** — Silent failures that hide production errors entirely (empty catches, swallowed errors)
- **HIGH** — Missing logging at system boundaries or errors without context (makes debugging take hours instead of minutes)
- **MEDIUM** — Missing correlation IDs, inconsistent logging, no structured format
- **LOW** — Log hygiene improvements, missing debug-level logging, minor format issues

### 9. Summarize

End with:
- Summary table of findings by severity and category
- Silent failure count (CRITICAL — these are ticking time bombs)
- API boundary coverage assessment (what percentage of boundaries have logging?)
- Correlation ID status (present / partial / absent)
- Overall observability posture: **BLIND** (multiple CRITICALs), **PARTIAL** (HIGHs but basics covered), **OBSERVABLE** (minor gaps only)

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions. Stores findings as `db_upsert 'log-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex runs in parallel. Each stores findings under label `sonnet` or `codex`. Meta-review handles synthesis.

## Examples

```
User: Check if we have enough logging to debug production issues.
→ Full audit across all categories. Emphasis on silent failures and API boundary logging.
```

```
User: We had an incident and couldn't figure out what happened. Review our logging.
→ Emphasis on correlation IDs (§6) and error context (§4). Check if requests are traceable end-to-end.
```

```
User: Review logging before we deploy to prod.
→ Full audit. Flag any CRITICAL silent failures as deploy blockers. Check structured logging is configured.
```

```
User: We're moving to microservices. Is our logging ready?
→ Emphasis on correlation/tracing (§6) and API boundary logging (§5). Distributed systems need end-to-end traceability.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
