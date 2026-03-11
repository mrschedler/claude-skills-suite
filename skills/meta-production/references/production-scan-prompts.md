# Production Scan Prompts

Reference prompts for the three Codex workers in Phase 2, Track B.
Each worker scans one production dimension. Read this file before launching
workers, then use the appropriate section as the Codex exec prompt body.

---

## Observability Prompt (Dimension 8)

```
You are a production observability auditor. Scan this entire codebase
and assess its observability posture. For each finding, cite file:line.

CHECK FOR:
- Health check endpoints (/health, /healthz, /readyz, /livez)
- Structured logging vs bare console.log/print (context, levels, correlation IDs)
- Metrics collection (Prometheus, StatsD, OpenTelemetry, custom counters)
- Distributed tracing (trace headers, span creation, context propagation)
- Error tracking integration (Sentry, Bugsnag, Datadog, etc.)
- Logging sensitive data (passwords, tokens, PII leaking into logs)
- Request/response logging for API endpoints (method, path, status, duration)
- Log levels used appropriately (not everything as info/error)
- Startup/shutdown event logging

ALSO NOTE what IS done well — observability patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix
```

---

## Deployment Prompt (Dimension 9)

```
You are a production deployment auditor. Scan this entire codebase
and assess its deployment readiness. For each finding, cite file:line.

CHECK FOR:
- Hardcoded environment-specific values (URLs, ports, hosts, IPs)
- Graceful shutdown handler (SIGTERM, SIGINT signal handling)
- Connection draining on shutdown (DB pools, HTTP keep-alive, WebSockets)
- Dockerfile quality (running as root, multi-stage build, .dockerignore,
  image size, HEALTHCHECK instruction, non-root USER)
- Environment variable validation at startup (fail fast on missing config)
- Database migration strategy (migration files, version tracking)
- Feature flags or kill switches for new functionality
- Build reproducibility (lockfiles committed, pinned versions)
- Secrets in Docker build args or layers
- Container signal forwarding (exec form CMD vs shell form)

ALSO NOTE what IS done well — deployment patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix
```

---

## Operations Prompt (Dimension 10)

```
You are a production operations auditor. Scan this entire codebase
and assess its operational resilience. For each finding, cite file:line.

CHECK FOR:
- Rate limiting on public endpoints
- Request timeout configuration (HTTP clients, DB queries, external calls)
- Circuit breaker pattern for external dependencies
- Retry logic with exponential backoff for network calls
- Resource limits (memory, CPU, connection pool sizes, thread pools)
- Unbounded queries (missing LIMIT, no pagination, SELECT *)
- Error classification (retryable vs fatal, transient vs permanent)
- CORS configuration for web APIs
- Request size limits (body parser limits, upload limits)
- Deadlock potential (lock ordering, connection pool exhaustion)
- Queue/buffer overflow handling
- Graceful degradation when dependencies are down

ALSO NOTE what IS done well — operational resilience patterns already implemented.

Format: SEVERITY (CRITICAL/HIGH/MEDIUM/LOW) | file:line | Issue | Impact | Fix
```
