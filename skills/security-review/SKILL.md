---
name: security-review
description: Focused security audit covering dependencies, auth, secrets, input validation, network boundaries, agent patterns, supply chain, and IaC. Uses P0/P1/P2 priority tiers. Use before production deploys or when handling sensitive data.
---

# Security Review

## Purpose

Find security vulnerabilities before attackers do. AI-generated code introduces
6.4-45% more vulnerabilities than human-written code. Only 15.2% of agent solutions
are both correct AND secure. Iterative refinement DEGRADES security (37.6% increase
in critical vulns after 5 rounds). This skill catches what agents miss.

## Inputs

- The full codebase
- GROUNDING.md or project-context.md — to understand the threat model
- Dependency manifests (package.json, requirements.txt, go.mod, Cargo.toml, etc.)
- IaC files (Dockerfiles, docker-compose, Terraform, K8s manifests) if present

## Outputs

See `references/review-lens-framework.md` for the shared output pattern.

## Priority System

Every finding MUST be assigned a priority tier:

- **P0 — Block Deployment**: Hardcoded secrets, SQLi, command injection, known CVEs, missing auth, path traversal, deserialization, RCE vectors
- **P1 — Flag for Review**: Missing rate limiting, insecure headers, weak crypto, BOLA, permissive CORS, package hallucination, overly permissive IAM, missing TLS, log injection, SSRF
- **P2 — Advisory**: Missing CSRF, insufficient logging, info disclosure, session mgmt gaps, timing attacks, tenant isolation, insecure defaults

## Instructions

### Fresh Findings Check

See `references/review-lens-framework.md`.

### 1. Load Context

Read GROUNDING.md or project-context.md to understand:
- Deployment environment (cloud, self-hosted, edge)
- Data sensitivity (PII, credentials, financial, public)
- User base (internal, public, authenticated, anonymous)
- Network boundary (internet-facing, internal only, hybrid)
- Whether AI agents, MCP servers, or tool-calling LLMs are involved

### 2. Secrets Scan (P0)

Search the entire codebase for exposed secrets:
- API keys, tokens, passwords hardcoded in source
- `.env` files committed to version control
- Secrets in Docker build args (persist in layers)
- Private keys, certificates in the repo
- Connection strings with embedded passwords
- Webhook URLs or callback secrets in source

### 3. Dependency & Supply Chain Audit (P0/P1)

- Known vulnerable versions in dependency manifests
- Pinned vs floating dependencies (floating = supply chain risk)
- Unnecessary dependencies expanding attack surface
- Dev dependencies leaking into production
- Lockfile present and committed
- **Package hallucination**: Do all dependencies actually exist? Flag unfamiliar packages with low download counts
- **Typosquatting**: Packages 1-2 chars different from popular ones
- **Install scripts**: preinstall/postinstall executing arbitrary code

### 4. Authentication & Authorization (P0/P1)

- Session management (JWT, cookies, tokens — secure?)
- CSRF protection
- Auth checks applied consistently across routes
- Role-based access control where needed
- Password hashing (bcrypt/argon2, not MD5/SHA)
- Rate limiting on auth endpoints
- **BOLA/IDOR**: Endpoints verify requesting user owns the resource

### 5. Input Validation & Injection (P0)

- SQL injection: queries parameterized?
- XSS: output encoded/escaped?
- Command injection: user input in shell commands?
- Path traversal: user input in file paths?
- Deserialization of untrusted data
- SSRF: user input controlling outbound requests
- Log injection: user input in logs without encoding

### 6. Network & Infrastructure (P1/P2)

- CORS settings — overly permissive?
- TLS/SSL enforced?
- Internal services exposed publicly?
- Health/debug endpoints protected?
- Secure headers: CSP, HSTS, X-Frame-Options, X-Content-Type-Options

### 7. IaC Security (P1)

If Dockerfiles, docker-compose, Terraform, or K8s manifests exist:
- Running as non-root?
- Privileged mode or host networking unnecessary?
- Base image pinning (not `:latest`)
- Resource limits on containers
- Security groups / firewall overly permissive?

### 8. Agent-Specific Patterns (P0/P1/P2)

If code was generated or modified by AI agents:
- Hardcoded debug constructs, insecure defaults, missing validation
- Universally omitted: rate limiting, session mgmt, secure headers, CORS, CSRF
- Trust boundary violations, PII in logs/caches, privilege escalation paths
- If code went through multiple AI refinement rounds, re-validate ALL security properties

### 9. Agentic Security (P0/P1)

If the project involves AI agents, MCP servers, or tool-calling LLMs:
- **Goal Hijacking**: External data sanitized before entering agent context?
- **Identity Abuse**: Agent credentials scoped to minimum necessary?
- **Excessive Agency**: Agent has more tools/permissions than needed?
- **Output Validation**: Agent outputs validated before execution?
- **Tool Misuse**: MCP tools input-validated and allow-listed?
- **Code Execution**: Agent-generated code sandboxed?

### 10. Produce Findings

Each finding:

```
## [P0|P1|P2] [SEVERITY] Finding Title

**Category**: Secrets | Dependencies | Supply Chain | Auth | Input Validation | Network | IaC | Agent Pattern | Agentic Security
**Location**: file/path:line
**CWE**: CWE-XXX (if applicable)
**Priority**: P0 (block) | P1 (review) | P2 (advisory)

**Risk**: What could an attacker do?
**Evidence**: Code snippet showing the issue.
**Remediation**: Specific steps to fix.
```

### 11. Summarize

- Summary table by priority tier, severity, and category
- P0 count (must be zero to deploy)
- P1 count (must be reviewed before deploy)
- P2 count (advisory)
- Overall posture: **BLOCK** (any P0) | **CONDITIONAL** (P1s only) | **CLEAR**

## References (on-demand)

- `references/agent-patterns.md` — AI anti-pattern catalog, omission patterns, iterative degradation
- `references/priority-checklists.md` — Full P0/P1/P2 checklists with CWEs
- `references/owasp-agentic.md` — OWASP Agentic Top 10, Least-Agency principle

## Examples

```
User: Run a security audit before we deploy.
→ Full audit. Produce prioritized findings. BLOCK/CONDITIONAL/CLEAR verdict.
```

```
User: We're building an MCP server. Review the security.
→ Emphasis on Agentic Security. Read references/owasp-agentic.md.
```

---

Before completing, read and follow `../references/review-lens-framework.md` and `../references/cross-cutting-rules.md`.
