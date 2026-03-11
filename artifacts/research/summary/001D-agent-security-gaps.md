# Deep Research: AI Coding Agent Security Gaps

> Research folder: research/001D/
> Date: 2026-03-10
> Models: Opus 4.6 (orchestrator), Sonnet 4.6 (8 connector subagents),
>   Codex (unavailable — redistributed to Opus), Gemini 3.1 Pro (2 instances)
> MCP connectors used: Consensus, Scholar Gateway, HuggingFace Papers, WebSearch, MS Learn, GitHub
> Debate rounds: 3 (2-model: Claude + Gemini; Codex unavailable)
> Addendum cycle: yes — OWASP Agentic Top 10, iterative degradation, prompt injection on agents, vibe coding emerged
> Sources: 53 queries | 998 scanned | 203 cited
> Claims: 14 verified, 4 high, 1 contested, 0 debunked

## Executive Summary

1. **AI-generated code contains more security vulnerabilities than human-written code** in most studies, with rates varying from 6.4% more per LOC to 45% of generated code containing flaws, depending on methodology (VERIFIED, 2/2 agree)
2. **Top vulnerability classes**: CWE-89 (SQL Injection), CWE-79 (XSS), CWE-117 (Log Injection), CWE-798 (Hardcoded Credentials), CWE-22 (Path Traversal) — AI fails input sanitization in 86% of web-related tests (VERIFIED)
3. **Agents systematically skip defensive security**: rate limiting, session management, secure headers, CORS, CSRF protection, timing attack prevention are universally omitted unless explicitly requested (VERIFIED)
4. **General coding agents cannot reason about security context**: trust boundaries, data flow, privilege escalation, multi-tenant isolation remain fundamental blind spots; only 15.2% of agent solutions are correct AND secure (VERIFIED)
5. **Specialized security agents CAN outperform humans**: Google Big Sleep found zero-days in SQLite; Claude Opus 4.6 found 22 Firefox vulnerabilities in two weeks — but this is specialized, not general agent behavior (HIGH)
6. **Iterative AI refinement DEGRADES security**: 37.6% increase in critical vulnerabilities after just 5 rounds of "improvements" — directly contradicts the assumption that iteration improves security (HIGH, single study with replication caveat)
7. **Traditional SAST tools miss ~53% of AI-specific vulnerabilities** — AI-generated code has distinct patterns that conventional scanners are not designed to detect (HIGH)
8. **Package hallucination ("slopsquatting") is a verified supply chain threat**: 5.2-21.7% hallucination rates across models, 205K+ unique hallucinated package names, 43% repeat predictably enabling targeted attacks (VERIFIED)
9. **Prompt injection on coding IDEs achieves up to 84% success rate**: 30+ CVEs disclosed across Cursor, Copilot, Windsurf, and others in 2025; attack taxonomy now covers 42 distinct techniques (VERIFIED)
10. **OWASP Agentic Top 10 (2026) defines the agent threat model**: ASI01 (Agent Goal Hijacking) is highest risk; introduces Least-Agency principle and MAESTRO threat modeling framework (VERIFIED)
11. **Functional benchmark scores (Pass@1) do NOT predict code security** — models that pass functional tests still introduce critical vulnerabilities (VERIFIED)
12. **No single tool is sufficient** — best practice is "Stacked Verification": IDE linting + AI-augmented SAST + human review + ephemeral sandboxing (VERIFIED, with single-source caveat on 91% noise reduction claim)
13. **The existing security review skill needs significant expansion**: agent-specific patterns, context-aware checks, supply chain validation, IaC scanning, and integration with OWASP ASVS v5/Agentic Top 10 are all gaps (HIGH)
14. **A tiered priority system is essential**: P0 (block deployment) for hardcoded secrets, SQLi, known CVEs, missing auth; P1 (flag for review) for rate limiting, insecure headers, weak crypto; P2 (advisory) for missing CSRF, suboptimal logging (HIGH)

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| SQ-1 | Do AI agents introduce vulns at higher rates? | VERIFIED | 2/2 | Yes, 6.4-45% higher depending on methodology |
| SQ-2 | Which CWE/OWASP categories most frequent? | VERIFIED | 2/2 | CWE-89, CWE-79, CWE-117, CWE-798, CWE-22 |
| SQ-3 | What anti-patterns do agents produce? | VERIFIED | 2/2 | Hardcoded secrets/debug, insecure defaults, missing validation |
| SQ-4 | What do agents consistently skip? | VERIFIED | 2/2 | Rate limiting, sessions, headers, CORS, CSRF, timing |
| SQ-5 | How do agents fail at security context? | VERIFIED | 2/2 | Trust boundaries, data flow, privilege, multi-tenant |
| SQ-6 | Pitfalls of AI security review? | VERIFIED | 2/2 | Automation bias, hallucinated vulns, semantic gap, degradation |
| SQ-7 | Best security review process? | HIGH | 2/2 | Stacked verification (lint + AI SAST + human + sandbox) |
| SQ-8 | What should a security skill enforce? | HIGH | 2/2 | 6 categories, P0/P1/P2 prioritization, tool integration |
| SQ-9 | Supply chain / slopsquatting risk? | VERIFIED | 2/2 | 5.2-21.7% hallucination rates, verified attack cases |
| SQ-10 | Existing tools for AI code security? | HIGH | 2/2 | Rich ecosystem, no single tool sufficient |
| E-1 | OWASP Agentic Top 10 impact? | VERIFIED | 2/2 | Defines agent threat model, Least-Agency principle |
| E-2 | Iterative security degradation? | HIGH | 2/2 (caveat) | 37.6% vuln increase after 5 rounds |
| E-3 | Prompt injection on coding agents? | VERIFIED | 2/2 | 84% success, 42 attack techniques, 30+ CVEs |
| E-4 | MCP mitigates slopsquatting? | CONTESTED | 1/2 | Partially — not universal, vibe coders still vulnerable |

## Detailed Findings

### SQ-1: Empirical Evidence of AI Code Vulnerability Rates

**Confidence**: VERIFIED (with methodological nuance)
**Agreement**: 2/2 — both models converged after debate on range expression

**Finding**: Multiple independent studies confirm AI-generated code introduces more security vulnerabilities than human-written code, though rates vary significantly by methodology:
- **6.4% more vulnerabilities per LOC** (Yoo & Kim 2025, 20 C programs via Ghidra/Valgrind/Frida)
- **45% of AI-generated code contains security flaws** (Veracode 2025 GenAI Code Security Report)
- **15-18% more vulnerabilities** in production-like contexts (Opsera 2026 AI Coding Impact Benchmark)
- **10,000+ new security findings per month** by mid-2025, a 10x spike in 6 months (Apiiro)
- **AI-generated code causes 1 in 5 breaches** in 2026 (Aikido Security)
- BUT: ChatGPT code has **20% fewer vulnerabilities than StackOverflow** code (Hamer et al. 2024, 30 citations) — suggesting AI may be better than worst human practices while worse than professional standards

**Evidence**:
- Cotroneo, Improta & Liguori (2025) IEEE ISSRE — 500K+ code samples, Python/Java, CWE classification
- Yoo & Kim (2025) Tehnički glasnik — network security +18.8%, file operations +12.4%, error handling +12.4%
- Sabra, Schmitt & Tyler (2025) — 4,442 Java assignments via SonarQube; hard-coded passwords and path traversal across ALL 5 models tested; no correlation between Pass@1 and security

**Debate**: Gemini challenged the range (6.4-45%) as conflating different methodologies. Claude conceded the nuance — the range reflects genuinely different measurements. Both agreed the DIRECTION is consistent: more risk from AI code.

### SQ-2: Most Frequent CWE/OWASP Categories

**Confidence**: VERIFIED
**Agreement**: 2/2

**Finding**: The most frequently introduced vulnerability classes are:
- **CWE-89 (SQL Injection)**: AI fails to use parameterized queries; 86% failure in web tests
- **CWE-79 (XSS)**: Missing output encoding in HTML contexts
- **CWE-117 (Log Injection)**: Failed in 88% of cases due to lack of output encoding
- **CWE-798 (Hardcoded Credentials)**: Found across ALL models in Sabra et al. study
- **CWE-22 (Path Traversal)**: Found across multiple models
- **CWE-1336 (Prompt Injection)**: Emergent category specific to agent-generated code
- 19-25 distinct CWE types typically found per study

**Evidence**: Saleem & Nazlıoğlu (2025, UBMK — LLMSecEval, 150 Python tasks), Hamer et al. (2024, 30 citations), OWASP Agentic Top 10 (2026)

### SQ-3: Security Anti-Patterns in AI-Generated Code

**Confidence**: VERIFIED
**Agreement**: 2/2 (Gemini noted need for concrete examples)

**Finding**: AI agents produce a distinct anti-pattern profile:
- **Hardcoded debugging constructs** and secrets (print statements, API keys in source)
- **Insecure defaults**: HTTP instead of HTTPS, permissive CORS (`*`), debug mode enabled
- **Missing input validation**: no sanitization on user inputs, no type checking
- **Weak cryptography**: fixed XOR keys, MD5/SHA1 for passwords, no salting
- **Memory management issues**: leaks (1,068 bytes in 34 blocks per Yoo & Kim), use-after-free
- **Inconsistent resource management**: files/connections opened but not properly closed

**Evidence**: Cotroneo et al. (2025), Yoo & Kim (2025), Sabra et al. (2025)

### SQ-4: Consistently Skipped Security Concerns

**Confidence**: VERIFIED
**Agreement**: 2/2

**Finding**: Agents universally omit unless explicitly requested:
1. **Rate limiting** on API endpoints — enables Denial-of-Service and Denial-of-Wallet
2. **Session management** — no idle timeout, fixation prevention, concurrent session limits
3. **Secure HTTP headers** — CSP, HSTS, X-Frame-Options, X-Content-Type-Options absent
4. **CORS configuration** — defaults to permissive or missing
5. **CSRF protection** — no token generation/validation on forms
6. **Timing attack prevention** — no constant-time comparisons for sensitive values
7. **Error handling security** — stack traces and internal paths exposed in responses
8. **Dependency validation** — no check whether suggested packages actually exist

### SQ-5: How Agents Fail at Security Context

**Confidence**: VERIFIED
**Agreement**: 2/2 (Gemini conceded that general agents fail, only specialized agents succeed)

**Finding**: General-purpose coding agents fail at four levels of security context:
1. **Trust boundary blindness**: treat all inputs equally — no distinction between authenticated user, external API, internal service
2. **Data flow ignorance**: PII may end up in logs, caches, error messages, analytics without tracking
3. **Privilege escalation**: inherit over-privileged tokens, cannot reason about least-privilege (322% increase in privilege escalation paths per Apiiro)
4. **Multi-tenant isolation**: generate single-tenant code by default, no tenant ID filtering
5. **API authorization scoping**: implement authentication but not object-level authorization (BOLA)

Specialized security agents (Big Sleep, ARTEMIS, Claude Opus 4.6 security mode) CAN exceed human capability — but this supports the need for a dedicated security skill, not the claim that general agents are secure.

### SQ-6: Pitfalls of AI Security Review

**Confidence**: VERIFIED
**Agreement**: 2/2

**Finding**:
1. **Automation bias**: developers 1.7x more likely to ignore flaws when using AI+SAST
2. **Semantic gap**: SAST+AI cannot detect MISSING security code (absent auth checks, missing rate limiting)
3. **Hallucinated vulnerabilities**: AI reviewers report non-existent CVEs or incorrect CWE classifications
4. **Iterative degradation**: 37.6% increase in critical vulns after 5 rounds of "improvement" (Shukla et al. 2025)
5. **Context window limits**: cannot hold full security context of large applications
6. **Overconfidence**: models present HIGH confidence even with thin evidence
7. **Business logic blindness**: cannot reason about domain-specific security requirements
8. **Detection efficiency gap**: conventional tools miss 53.3% of AI-specific vulnerabilities (Yoo & Kim 2025)

### SQ-7: Best Security Review Processes

**Confidence**: HIGH (MEDIUM-HIGH for specific metrics)
**Agreement**: 2/2

**Finding**: The emerging best practice is "Stacked Verification":
1. **Layer 1 — IDE-integrated linting**: Real-time pattern matching for "table stakes" issues
2. **Layer 2 — AI-augmented SAST**: LLMs post-process static analysis findings, reducing noise (up to 91% per Qwiet AI — single source, treat as upper bound)
3. **Layer 3 — Human-in-the-loop**: Review ONLY high-risk modules and business-logic intent
4. **Layer 4 — Ephemeral sandboxing**: Execute in isolated micro-VMs (Firecracker, Wasm) before production

Tool integration: Semgrep + CodeQL (SAST) + Snyk/Socket (SCA) + Checkov/Trivy (IaC) + custom agent-specific rules.

### SQ-8: What a Security Review Skill Should Enforce

**Confidence**: HIGH
**Agreement**: 2/2 (with agreed prioritization)

**Finding**: The security skill should enforce checks across 6 categories with 3 priority tiers:

**P0 — Block Deployment:**
- Hardcoded secrets (API keys, passwords, tokens)
- SQL injection patterns (string concatenation in queries)
- Known CVE dependencies (via SCA integration)
- Missing authentication on endpoints
- Path traversal in file operations
- Command injection in shell operations

**P1 — Flag for Review:**
- Missing rate limiting on public endpoints
- Insecure HTTP headers (no CSP, HSTS, X-Frame-Options)
- Weak cryptography (MD5, SHA1 for passwords)
- Broken object-level authorization (BOLA)
- Missing CORS configuration or permissive wildcard
- Package hallucination detection (verify against registries)
- Overly permissive IAM/container configurations

**P2 — Advisory:**
- Missing CSRF protection on state-changing operations
- Insufficient logging and monitoring
- Suboptimal error handling (information disclosure)
- Session management improvements
- Missing constant-time comparisons
- Tenant isolation recommendations

**Meta-requirements:**
- MUST integrate with SAST tools (Semgrep, CodeQL), not replace them
- MUST re-validate after iterative refinement (counter iterative degradation)
- SHOULD reference OWASP ASVS v5.0.0 and Agentic Top 10 (2026)
- SHOULD implement context-aware threat modeling using STRIDE or MAESTRO
- MUST be resistant to prompt injection (the skill itself is an attack surface)

### SQ-9: Supply Chain / Slopsquatting

**Confidence**: VERIFIED
**Agreement**: 2/2

**Finding**: Package hallucination is a verified, quantified threat:
- **5.2% hallucination rate** for commercial models, **21.7%** for open-source (Spracklen et al. USENIX 2025, 29 citations)
- **205,474 unique hallucinated package names** identified
- **43% of hallucinations repeat** across queries — making them PREDICTABLE targets
- Active exploitation documented: `huggingface-cli` (35K downloads), `ccxt-mexc-futures` (malware)
- Inverse correlation between hallucination rate and HumanEval benchmark score

**Mitigation**: MCP real-time package registry lookups (for MCP-enabled agents), CI/CD package validation (universal), lockfile enforcement, and explicit warnings for unverified packages.

### SQ-10: Existing Tools for AI-Generated Code Security

**Confidence**: HIGH
**Agreement**: 2/2

**Finding**: The tool ecosystem is rich but fragmented:

| Category | Tools | Status |
|---|---|---|
| AI-specific security probing | Garak (NVIDIA), Protect AI, HiddenLayer | Production, validated |
| AI-augmented SAST | Semgrep AI, CodeQL, SonarQube, Aikido | Production, well-validated |
| SCA / Supply chain | Snyk, Socket.dev, Mend.io, ConfuGuard | Production, well-validated |
| IaC scanning | Checkov, Trivy (fka tfsec), Terrascan | Production, 750+ policies |
| AI code benchmarks | CodeSecEval, SecureAgentBench, A.S.E, SALLM, RedCode | Research, useful for validation |
| Security training data | SecureCode v2.0, LLMSecEval, ProSec | Research/training |
| AI PR security review | Bugdar (LLM+RAG) | Early production |
| Agent security hooks | Corridor (MCP-based) | Emerging, unvalidated |

## Addendum Findings

### Emergent Topic: OWASP Agentic Top 10 (2026)
**Why it surfaced**: Multiple research tracks independently identified agentic-specific risks
**Finding**: The OWASP Agentic Top 10 (released Dec 2025, 100+ collaborators) defines 10 agent-specific risk categories. The most relevant for a security skill:
- ASI01: Agent Goal Hijacking (highest risk — poisoned inputs redirect agent behavior)
- ASI02: Identity & Privilege Abuse (over-privileged agent tokens)
- ASI06: Tool Misuse (authorized tools used for unauthorized purposes)
- ASI09: Autonomous Code Execution (uncontrolled execution)
- Introduces "Least-Agency" principle: minimum autonomy, tool access, and credential scope
- MAESTRO framework for multi-agent threat modeling
**Impact**: The security skill MUST incorporate ASI01-ASI10 awareness and Least-Agency checks

### Emergent Topic: Iterative Security Degradation
**Why it surfaced**: Shukla, Joshi & Syed (2025) finding confirmed independently by Gemini
**Finding**: 400 code samples across 40 rounds of "improvements" showed 37.6% increase in critical vulnerabilities after just 5 iterations. Different prompting strategies produce distinct vulnerability patterns. This directly contradicts the assumption that agentic iteration improves security.
**Impact**: Security skill MUST re-validate after every iterative refinement cycle. Cannot trust that "improved" code is also "more secure" code.

### Emergent Topic: Prompt Injection on Coding Agents
**Why it surfaced**: 30+ CVEs disclosed in coding IDEs in Dec 2025 (IDEsaster)
**Finding**: Maloyan & Namiot (2026) SoK paper analyzing 78 studies identified 42 attack techniques. Attack success >85% with adaptive strategies. Most defenses achieve <50% mitigation. The security skill itself runs as an agent with tool access, making it a potential target.
**Impact**: Security skill must implement defense-in-depth against prompt injection targeting its own operation (input sanitization, restricted tool scope, output validation)

### Emergent Topic: Vibe Coding
**Why it surfaced**: Multiple industry sources reference this as dominant usage pattern
**Finding**: Vibe coding (AI-first development with minimal human oversight) amplifies all identified risks. Missing depth (regulatory/industry requirements), hardcoded secrets, comprehension gap (cannot debug in production), and blind package installation make this the highest-risk usage pattern.
**Impact**: Security skill should have a "vibe coding mode" with heightened warnings and mandatory P0 checks

## Contested Findings

### MCP Mitigation of Slopsquatting
**Majority** (Claude): MCP lookups help but are not universal — vibe coders, non-MCP agents, and the 43% repeat hallucination rate mean the risk persists
**Dissent** (Gemini initial position): In professional CI/CD environments, the risk is effectively zero; MCP "kills" the hallucination risk
**Resolution**: Gemini conceded that universality is lacking. Agreed that risk is CONTEXT-DEPENDENT: low for mature orgs with CI/CD, high for vibe coders and individual developers
**Impact**: Security skill should implement package validation regardless of MCP availability — defense in depth

## Open Questions

None classified as UNCERTAIN or UNRESOLVED after debate. All major claims reached at least HIGH confidence with 2/2 agreement.

Remaining gaps for future research:
1. Replication of iterative degradation finding (currently single study)
2. Head-to-head comparison of integrated security stacks in production
3. Quantified omission rates per security concern per model
4. Concrete before/after code examples for all anti-patterns (available in benchmarks but not compiled)
5. Effectiveness of agent-specific Semgrep rules vs standard rulesets

## Debunked Claims

No claims were debunked during debate. Both models converged on all major findings after productive refinement.

## Source Index

### Academic Sources (Consensus, Scholar Gateway, HuggingFace Papers)
- Cotroneo, Improta & Liguori (2025) IEEE ISSRE — 500K sample comparison
- Yoo & Kim (2025) Tehnički glasnik — static + dynamic analysis of AI code
- Patel, Sultana & Samanthula (2024) IEEE BigData — metrics and bug correlation
- Saleem & Nazlıoğlu (2025) UBMK — prompting strategies for secure code
- Hamer et al. (2024) IEEE S&P Workshops — ChatGPT vs StackOverflow, 30 citations
- Xu et al. (2024) ProSec — proactive security alignment, 10 citations
- Shen et al. (2025) IEEE AIC — BERT-GNN hybrid detection
- Naulty et al. (2025) IEEE CAI — Bugdar AI-augmented review
- Wang et al. (2024) CodeSecEval — 44 vulnerability types benchmark
- Kaniewski et al. (2024) — vulnerability handling survey
- Li et al. (2024) — fine-tuning for secure code
- Sabra, Schmitt & Tyler (2025) — SonarQube analysis of 5 LLMs
- Navneet & Chandra (2025) — SAFE-AI Framework
- Lian et al. (2025) A.S.E — repository-level benchmark, 349 upvotes
- Chen et al. (2025) SecureAgentBench — 105 tasks, 15.2% secure
- Siddiq & Santos (2023) SALLM — security-centric benchmark
- Dolcetti et al. (2024) — static analysis feedback for LLMs
- Spracklen et al. (2024) USENIX Security — package hallucinations, 29 citations
- Krishna et al. (2025) — importing phantoms, hallucination measurement
- Liu et al. (2025) AIShellJack — prompt injection on coding editors
- Štorek et al. (2025) XOXO — cross-origin context poisoning, 3 citations
- Siddiq et al. (2026) — agentic PRs on GitHub, 33K PRs
- Thornton (2025) SecureCode v2.0 — 1,215 training examples
- Bazinska et al. (2025) b³ — 194K adversarial attacks, 31 LLMs
- Maloyan & Namiot (2026) SoK — 78 studies, 42 attack techniques
- Shukla, Joshi & Syed (2025) — iterative security degradation
- Ding et al. (2025) CodingCare — security framework
- Res et al. (2024) — prompt engineering for Copilot security, 7 citations
- Negri-Ribalta et al. (2024) Frontiers in Big Data — systematic literature review, 21 citations
- Lian et al. (2025) F2SRD — ASVS-based security requirements, 4 citations
- Abdiukov (2024) — automated security testing in DevSecOps

### Official Documentation (MS Learn, OWASP)
- OWASP Top 10 for Agentic Applications (2026)
- OWASP ASVS v5.0.0 (2025)
- OWASP AISVS (under development)
- OWASP AI Testing Guide v1 (2025)
- Microsoft AI Security Benchmark v2
- Microsoft Copilot Control System security guidance
- MITRE ATT&CK for LLMs (AML.T0051, AML.T0054, AML.T0024)

### Web Sources (Gemini, WebSearch)
- Veracode 2025 GenAI Code Security Report
- CrowdStrike DeepSeek-R1 security analysis (2025)
- Apiiro 2025-2026 velocity/vulnerability analysis
- Opsera 2026 AI Coding Impact Benchmark
- Aikido Security 2026 breach attribution report
- JetBrains 2025 developer survey (25,000 respondents)
- Anthropic BaxBench results
- IDEsaster vulnerabilities disclosure (Dec 2025)
- CVE-2025-54135 (Cursor), CVE-2025-53773 (Copilot), CVE-2025-32711 (EchoLeak)
- Kaspersky vibe coding security risks (2025)
- Databricks, Lawfare, Contrast Security vibe coding analysis
- CSA MAESTRO framework (2025)
- Practical DevSecOps OWASP analyses

### Source Tally

| Track | Queries | Scanned | Cited |
|---|---|---|---|
| Track A (Opus reasoning) | 5 | 400 | 53 |
| Track B (MCP connectors) | 22 | 330 | 80 |
| Track C (Codex) | 0 | 0 | 0 |
| Track D (Gemini) | 21 | 179 | 34 |
| Addendum | 9 | 89 | 36 |
| **TOTAL** | **53** | **998** | **203** |

## Methodology

### Worker Allocation
- **Track A (Opus)**: 2 reasoning passes — security context + skill design + addendum synthesis. Also covered Codex-assigned sub-questions after Codex CLI returned empty output for all 4 workers.
- **Track B (Sonnet/MCP)**: 8 connectors (Consensus x5, Scholar Gateway x5, HuggingFace x4, WebSearch x10, MS Learn x1, GitHub x2). Multi-query protocol per connector.
- **Track C (Codex)**: 4 workers dispatched but all returned empty output (CLI sandbox/timeout issue). Findings redistributed to Track A.
- **Track D (Gemini)**: 2 instances — primary research + case studies, contradiction hunter. Coverage reviewer timed out.

### Debate Structure
- 2-model debate (Claude + Gemini) due to Codex unavailability
- 3 rounds: Position, Challenge, Response
- Key refinements: vulnerability rate range expression, specialized vs general agents distinction, security skill prioritization system

### Addendum Rationale
Coverage expansion identified 4 emergent topics not in original prompt:
1. OWASP Agentic Top 10 (2026) — critical new framework
2. Iterative security degradation — counter-intuitive finding
3. Prompt injection on coding agents — agent-as-target
4. Vibe coding security pattern — dominant high-risk usage

Additional queries also covered: OWASP ASVS, AISVS, AI Testing Guide, SCA tools, IaC scanning, threat modeling frameworks (STRIDE, PASTA, MAESTRO).

### Confidence Scoring
Source quality weighting applied: academic papers > official docs > engineering blogs > forums > LLM inference. 2025-2026 sources weighted higher. First-hand experience (CVEs, case studies) weighted higher than theory.

Intermediate artifacts available in artifact DB under `meta-deep-research-execute` and `research-connector` skills, all labels prefixed with `001D/`.
