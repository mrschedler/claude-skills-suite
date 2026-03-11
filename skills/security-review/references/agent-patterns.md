# Agent-Specific Vulnerability Patterns

Reference material for the security-review skill. Read this file when scanning code
that was generated or modified by AI coding agents (Claude, Copilot, Cursor, Codex, etc.).

> Sources: Cotroneo et al. (2025), Yoo & Kim (2025), Sabra et al. (2025), Saleem & Nazlıoğlu (2025),
> Chen et al. (2025) SecureAgentBench, deep research run 001D (2026-03-10)

## Why Agent Code Is Different

- AI-generated code contains 6.4-45% more vulnerabilities than human-written code (range reflects methodology differences; direction is consistent across studies)
- Only 15.2% of agent solutions are both functionally correct AND secure (SecureAgentBench)
- Pass@1 benchmark scores do NOT predict security — models that pass functional tests still introduce critical vulnerabilities
- Iterative refinement DEGRADES security: 37.6% increase in critical vulns after 5 rounds of "improvement" (Shukla et al. 2025)

## Anti-Pattern Catalog

### AP-1: Hardcoded Debugging Constructs
- `print()` / `console.log()` statements with sensitive data
- Debug flags left enabled (`DEBUG=true`, `app.debug = True`)
- Verbose error messages exposing internals
- **CWE**: CWE-489 (Active Debug Code), CWE-209 (Error Message Information Leak)

### AP-2: Insecure Defaults
- HTTP instead of HTTPS in URLs and redirects
- CORS set to `*` or overly permissive origins
- Debug/development mode enabled in production configs
- Permissive file permissions (0777, world-readable)
- `allowAll`, `permitAll`, `disable()` on security middleware
- **CWE**: CWE-276 (Incorrect Default Permissions), CWE-1188 (Insecure Default Initialization)

### AP-3: Missing Input Validation
- No sanitization on user inputs before database queries
- No type checking on API request bodies
- No length limits on string inputs
- No allow-list validation on enum-like inputs
- Agents fail input sanitization in 86% of web-related tests
- **CWE**: CWE-20 (Improper Input Validation)

### AP-4: Weak Cryptography
- Fixed XOR keys for "encryption"
- MD5 or SHA1 for password hashing (no salting)
- Hardcoded IVs or nonces
- `Math.random()` / `random.random()` for security-sensitive values
- Self-signed or disabled certificate verification
- **CWE**: CWE-327 (Use of Broken Crypto), CWE-328 (Reversible One-Way Hash), CWE-330 (Insufficient Randomness)

### AP-5: Hardcoded Credentials
- API keys, tokens, passwords in source files
- Found across ALL models in empirical studies (Sabra et al.)
- Connection strings with embedded passwords
- Default admin credentials in setup code
- **CWE**: CWE-798 (Hardcoded Credentials)

### AP-6: Resource Management Failures
- Files/connections opened but never closed
- Missing `finally` blocks or context managers
- Memory leaks (1,068 bytes in 34 blocks per Yoo & Kim study)
- Database connections not returned to pool
- **CWE**: CWE-404 (Improper Resource Shutdown), CWE-772 (Missing Release of Resource)

### AP-7: Inconsistent Error Handling
- Mix of try/catch and uncaught exceptions in same module
- Empty catch blocks that swallow errors silently
- Stack traces and internal paths exposed in HTTP responses
- Error messages that differ between "user not found" and "wrong password" (oracle)
- **CWE**: CWE-755 (Improper Handling of Exceptional Conditions), CWE-209 (Error Message Information Leak)

## Universally Omitted Security Concerns

Agents skip these unless explicitly prompted. Check for ALL of them:

1. **Rate limiting** — on API endpoints, auth endpoints, password reset → DoS/DoW risk
2. **Session management** — idle timeout, fixation prevention, concurrent session limits
3. **Secure HTTP headers** — CSP, HSTS, X-Frame-Options, X-Content-Type-Options
4. **CORS configuration** — defaults to permissive or absent entirely
5. **CSRF protection** — no token generation/validation on state-changing forms
6. **Timing attack prevention** — no constant-time comparisons for secrets, tokens, passwords
7. **Error handling security** — stack traces and internal paths in responses
8. **Dependency validation** — no check whether suggested packages actually exist (slopsquatting)

## Context Blindness Patterns

General-purpose agents fail at four levels of security context:

1. **Trust boundary blindness** — treats all inputs equally (authenticated user, external API, internal service all get same handling)
2. **Data flow ignorance** — PII may end up in logs, caches, error messages, analytics without tracking
3. **Privilege escalation** — inherits over-privileged tokens, cannot reason about least-privilege (322% increase in privilege escalation paths per Apiiro)
4. **Multi-tenant isolation** — generates single-tenant code by default, no tenant ID filtering
5. **Object-level authorization** — implements authentication but not per-object access control (BOLA/IDOR)

## Iterative Degradation Warning

If the code has gone through multiple rounds of AI refinement:
- Re-validate ALL security properties — do not assume previous checks still hold
- Pay extra attention to error handling (first thing to degrade)
- Check that security middleware hasn't been "simplified" away
- Verify auth checks haven't been loosened to "fix" functional test failures
