---
name: security-review
description: Focused security audit covering dependencies, auth, secrets exposure, input validation, network boundaries, agent-specific patterns, supply chain, and IaC. Uses P0/P1/P2 priority tiers and OWASP Agentic Top 10. Use before production deploys or when handling sensitive data.
---

# Security Review

## Purpose

Find security vulnerabilities before attackers do. This skill performs a structured
security audit covering the most common vulnerability classes in web applications,
infrastructure code, and AI agent systems.

AI-generated code introduces 6.4-45% more vulnerabilities than human-written code.
Only 15.2% of agent solutions are both correct AND secure. Iterative refinement
DEGRADES security (37.6% increase in critical vulns after 5 rounds). This skill
exists to catch what agents miss.

## Inputs

- The full codebase
- `project-context.md` — to understand the threat model and deployment environment
- Dependency manifests (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, etc.)
- IaC files (Dockerfiles, docker-compose, Terraform, K8s manifests) if present

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'security-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings in the artifact DB:
  - Sonnet: `db_upsert 'security-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'security-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'security-review' 'findings' 'gemini' "$CONTENT"`

## Priority System

Every finding MUST be assigned a priority tier. Read `references/priority-checklists.md`
for the full checklist with CWEs and detection patterns.

- **P0 — Block Deployment** (CRITICAL): Hardcoded secrets, SQLi, command injection, known CVEs, missing auth, path traversal, deserialization, RCE vectors
- **P1 — Flag for Review** (HIGH/MEDIUM): Missing rate limiting, insecure headers, weak crypto, BOLA, permissive CORS, package hallucination, overly permissive IAM, missing TLS, log injection, SSRF
- **P2 — Advisory** (LOW): Missing CSRF, insufficient logging, info disclosure, session mgmt gaps, timing attacks, tenant isolation, insecure defaults, missing SRI

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'security-review' 'findings' 'standalone')
# For multi-model: db_age_hours 'security-review' 'findings' 'sonnet'
```
If `$AGE` is non-empty and less than 24, report: "Found fresh security-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB: `db_read 'security-review' 'findings' 'standalone'` (or `sonnet`/`codex`/`gemini` as appropriate).
If no record exists or user says no, proceed with a fresh scan.

### 1. Load Context

Read `project-context.md` to understand:
- What environment does this deploy to? (Cloud, self-hosted, edge, etc.)
- What data does it handle? (PII, credentials, financial, public, etc.)
- Who are the users? (Internal, public, authenticated, anonymous)
- What's the network boundary? (Internet-facing, internal only, hybrid)
- Does this project involve AI agents, MCP servers, or tool-calling LLMs?

This shapes the threat model. An internal tool with no PII has different priorities than
a public API handling payment data. If agents are involved, read `references/owasp-agentic.md`.

### 2. Secrets Scan (P0)

Search the entire codebase for exposed secrets:
- API keys, tokens, passwords hardcoded in source files
- `.env` files committed to version control
- Secrets in Docker build args or Dockerfiles (they persist in layers)
- Private keys, certificates, or credentials in the repo
- Connection strings with embedded passwords
- Webhook URLs or callback secrets in source code

For each finding, note whether the secret is real (P0) or a placeholder/example
(P2, but still flag as a pattern risk).

### 3. Dependency & Supply Chain Audit (P0/P1)

Examine dependency manifests:
- Are there known vulnerable versions? (Check against advisory databases)
- Are dependencies pinned or floating? (Floating = supply chain risk)
- Are there unnecessary dependencies that expand the attack surface?
- Are dev dependencies leaking into production builds?
- Is there a lockfile, and is it committed?
- **Package hallucination**: Do all dependencies actually exist in their registries? Flag unfamiliar packages with low download counts or recent creation dates
- **Typosquatting**: Flag packages whose names are 1-2 characters different from popular packages
- **Install scripts**: Check for `preinstall`/`postinstall` scripts executing arbitrary code

Read `references/priority-checklists.md` → Supply Chain Checklist for the full list.

### 4. Authentication & Authorization (P0/P1)

Review auth implementation:
- How are sessions managed? (JWT, cookies, tokens — and are they secure?)
- Is there proper CSRF protection?
- Are auth checks applied consistently, or do some routes skip them?
- Is there role-based access control where needed?
- Are passwords hashed properly? (bcrypt/argon2, not MD5/SHA)
- Is there rate limiting on auth endpoints?
- **BOLA/IDOR**: Do endpoints verify the requesting user owns the resource they're accessing?
- **Object-level authorization**: Authentication != authorization. Check both.

### 5. Input Validation & Injection (P0)

Check all user input handling:
- SQL injection: Are queries parameterized?
- XSS: Is output encoded/escaped?
- Command injection: Is user input ever passed to shell commands?
- Path traversal: Is user input used in file paths?
- Deserialization: Is untrusted data deserialized?
- SSRF: Can user input control outbound requests?
- Log injection: Is user input written to logs without encoding?

### 6. Network & Infrastructure (P1/P2)

Review network configuration:
- CORS settings — are they overly permissive?
- TLS/SSL configuration — is it enforced?
- Are internal services exposed to the public?
- Are health check or debug endpoints protected?
- Secure HTTP headers: CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy

### 7. IaC Security (P1)

If the project contains Dockerfiles, docker-compose, Terraform, or K8s manifests:
- Container user: running as non-root?
- Privileged mode or host networking unnecessarily?
- Base image pinning (`:latest` vs specific version/digest)
- Resource limits (CPU/memory) on containers
- Security groups / firewall rules overly permissive?
- Terraform state containing secrets or not using encrypted remote backend?

Read `references/priority-checklists.md` → IaC Security Checklist for the full list.

### 8. Agent-Specific Patterns (P0/P1/P2)

Read `references/agent-patterns.md` for the full anti-pattern catalog.

If the code was generated or modified by AI agents, check for:
- **Anti-patterns**: hardcoded debug constructs, insecure defaults, missing validation, weak crypto, resource leaks, inconsistent error handling (AP-1 through AP-7)
- **Universally omitted concerns**: rate limiting, session mgmt, secure headers, CORS, CSRF, timing attacks, dependency validation
- **Context blindness**: trust boundary violations, PII in logs/caches, privilege escalation paths, missing tenant isolation

If the code has gone through multiple rounds of AI refinement, re-validate ALL security
properties — iterative refinement degrades security.

### 9. Agentic Security (P0/P1)

If the project involves AI agents, MCP servers, or tool-calling LLMs, read
`references/owasp-agentic.md` and check for:
- **ASI01 (Goal Hijacking)**: Is external data sanitized before entering agent context?
- **ASI02 (Identity Abuse)**: Are agent credentials scoped to minimum necessary?
- **ASI03 (Excessive Agency)**: Does the agent have more tools/permissions than needed?
- **ASI04 (Output Validation)**: Are agent outputs validated before execution?
- **ASI06 (Tool Misuse)**: Are MCP tools input-validated and allow-listed?
- **ASI09 (Code Execution)**: Is agent-generated code sandboxed?
- **Least-Agency principle**: minimum autonomy, tool access, credential scope

### 10. Produce Findings

Write findings with this structure per finding:

```
## [P0|P1|P2] [SEVERITY] Finding Title

**Category**: Secrets | Dependencies | Supply Chain | Auth | Input Validation | Network | IaC | Agent Pattern | Agentic Security
**Location**: file/path:line
**CWE**: CWE-XXX (if applicable)
**Priority**: P0 (block) | P1 (review) | P2 (advisory)

**Risk**: What could an attacker do with this vulnerability?

**Evidence**: Code snippet or config showing the issue.

**Remediation**: Specific steps to fix. Include code examples where helpful.
```

Severity levels:
- **CRITICAL** — Exploitable vulnerability with high impact (data breach, RCE, auth bypass). Always P0.
- **HIGH** — Significant vulnerability that needs immediate attention. Usually P0 or P1.
- **MEDIUM** — Vulnerability with limited exploitability or impact. Usually P1.
- **LOW** — Hardening recommendation or defense-in-depth improvement. Usually P2.

### 11. Summarize

End with:
- Summary table of findings by priority tier, severity, and category
- P0 count (must be zero to deploy)
- P1 count (must be reviewed before deploy)
- P2 count (advisory, fix when convenient)
- Overall security posture assessment: BLOCK (any P0), CONDITIONAL (P1s only), CLEAR (P2s or clean)

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'security-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## References (on-demand)

Read these files only when needed for the relevant section:
- `references/agent-patterns.md` — Agent-specific anti-patterns, omission catalog, context blindness patterns, iterative degradation warning
- `references/priority-checklists.md` — Full P0/P1/P2 checklists with CWEs, supply chain checklist, IaC checklist
- `references/owasp-agentic.md` — OWASP Agentic Top 10 (ASI01-ASI10), Least-Agency principle, prompt injection defense

## Examples

```
User: Run a security audit before we deploy.
→ Full audit across all categories. Produce prioritized findings. Report BLOCK/CONDITIONAL/CLEAR verdict.
```

```
User: I just added OAuth. Can you check if I did it right?
→ Emphasis on Auth section (§4) and agent patterns (§8). Still scan other areas but prioritize auth.
```

```
User: Check our dependencies for vulnerabilities.
→ Emphasis on Dependency & Supply Chain Audit (§3). Include package hallucination checks.
```

```
User: We're building an MCP server. Review the security.
→ Emphasis on Agentic Security (§9). Read references/owasp-agentic.md. Apply Least-Agency checks.
```

```
User: This code went through 5 rounds of AI iteration. Is it secure?
→ Read references/agent-patterns.md → Iterative Degradation Warning. Re-validate ALL security
  properties. Pay extra attention to error handling and auth middleware.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
