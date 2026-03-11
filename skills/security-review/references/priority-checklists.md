# Priority Checklists

Reference material for the security-review skill. Use these checklists to classify
findings by deployment impact. Every finding MUST be assigned a priority tier.

> Sources: OWASP Top 10 (2021), OWASP ASVS v5.0.0 (2025), OWASP Agentic Top 10 (2026),
> deep research run 001D (2026-03-10)

## Priority Tiers

### P0 — Block Deployment

These findings MUST be fixed before any deployment. Flag as CRITICAL severity.

| Check | CWE | What to Look For |
|---|---|---|
| Hardcoded secrets | CWE-798 | API keys, passwords, tokens, private keys in source. Regex: `/(?:api[_-]?key\|secret\|password\|token\|private[_-]?key)\s*[:=]\s*['"][^'"]{8,}/i` |
| SQL injection | CWE-89 | String concatenation in SQL queries. Any `f"SELECT...{user_input}"` or `"SELECT..." + variable` pattern |
| Command injection | CWE-78 | User input in `exec()`, `eval()`, `os.system()`, `child_process.exec()`, backticks, `subprocess.shell=True` |
| Known CVE dependencies | CWE-1395 | Dependencies with published CVEs in advisory databases. Check lockfile versions against `npm audit`, `pip-audit`, `cargo audit` |
| Missing authentication | CWE-306 | Endpoints that handle sensitive data/actions without any auth check. Routes missing auth middleware |
| Path traversal | CWE-22 | User input used in `fs.readFile()`, `open()`, `Path()` without sanitization. Look for `../` pattern handling |
| Deserialization of untrusted data | CWE-502 | `pickle.loads()`, `yaml.load()` (not safe_load), `JSON.parse()` on unvalidated external input, Java `ObjectInputStream` |
| RCE vectors | CWE-94 | `eval()`, `Function()`, template injection, SSTI patterns |

### P1 — Flag for Review

These findings need attention before production. Flag as HIGH or MEDIUM severity.

| Check | CWE | What to Look For |
|---|---|---|
| Missing rate limiting | CWE-770 | Public endpoints (especially auth, password reset, API) without rate limiting middleware |
| Insecure HTTP headers | CWE-693 | Missing CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy |
| Weak cryptography | CWE-327 | MD5/SHA1 for passwords, fixed keys/IVs, `Math.random()` for tokens, ECB mode |
| Broken object-level auth (BOLA) | CWE-639 | Endpoints that access resources by ID without verifying the requesting user owns that resource |
| Permissive CORS | CWE-942 | `Access-Control-Allow-Origin: *` or reflecting `Origin` header without validation |
| Package hallucination risk | — | Dependencies that don't exist in registries, typosquatting-risk names, recently created packages with few downloads |
| Overly permissive IAM/roles | CWE-250 | `*` permissions, admin roles on service accounts, containers running as root |
| Missing TLS enforcement | CWE-319 | HTTP endpoints without redirect-to-HTTPS, mixed content, unencrypted internal service communication |
| Log injection | CWE-117 | User input written to logs without encoding (88% agent failure rate) |
| SSRF vectors | CWE-918 | User-controlled URLs passed to `fetch()`, `requests.get()`, `http.get()` without allow-list |

### P2 — Advisory

Hardening recommendations. Flag as LOW severity.

| Check | CWE | What to Look For |
|---|---|---|
| Missing CSRF protection | CWE-352 | State-changing forms/endpoints without CSRF tokens (especially if using cookies for auth) |
| Insufficient logging | CWE-778 | Auth events, admin actions, data access not logged. Missing audit trail |
| Information disclosure | CWE-209 | Stack traces, internal paths, version numbers, debug info in error responses |
| Session management gaps | CWE-613 | No idle timeout, no absolute timeout, no concurrent session limits, no fixation prevention |
| Missing constant-time comparisons | CWE-208 | String equality (`==`, `===`, `strcmp`) used for secrets, tokens, HMAC validation instead of `hmac.compare_digest()` or `crypto.timingSafeEqual()` |
| Tenant isolation gaps | CWE-284 | Database queries without tenant ID filtering, shared caches without namespace isolation |
| Insecure defaults | CWE-1188 | Debug mode on, verbose errors on, permissive file permissions, security middleware disabled |
| Missing Subresource Integrity | CWE-353 | External scripts/stylesheets loaded without `integrity` attribute |

## Supply Chain Checklist

Dedicated checks for dependency and supply chain risks:

1. **Lockfile exists and is committed** — `package-lock.json`, `yarn.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`
2. **No floating versions** — check for `*`, `latest`, `>=` without upper bound
3. **Package existence verification** — for any unfamiliar package, verify it exists in the registry and has meaningful download counts
4. **Typosquatting check** — flag packages whose names are 1-2 characters different from popular packages
5. **Install scripts** — check for `preinstall`/`postinstall` scripts in dependencies that execute arbitrary code
6. **Dev dependency leakage** — dev-only dependencies bundled into production builds

## IaC Security Checklist

For projects with infrastructure-as-code (Dockerfiles, docker-compose, Terraform, K8s manifests):

1. **Container user** — running as non-root? (`USER` directive in Dockerfile)
2. **Privileged mode** — `privileged: true` or `--privileged` flag
3. **Host networking** — `network_mode: host` unnecessarily
4. **Secrets in build** — `ARG` or `ENV` with secrets in Dockerfiles (they persist in layers)
5. **Base image pinning** — using `:latest` vs specific digest/version
6. **Resource limits** — missing CPU/memory limits on containers
7. **Read-only filesystem** — `read_only: true` where appropriate
8. **Capability dropping** — `cap_drop: ALL` + explicit `cap_add` for needed capabilities
9. **Terraform state** — state files containing secrets, not using remote backend with encryption
10. **Security groups / firewall rules** — overly permissive ingress (0.0.0.0/0 on non-public ports)
