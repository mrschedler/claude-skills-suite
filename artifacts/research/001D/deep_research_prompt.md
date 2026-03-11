# Deep Research Prompt — 001D

## Research Question

How do AI coding agents (Claude, Copilot, Cursor, Codex, ChatGPT, etc.) introduce or fail to catch security vulnerabilities when generating code — and what should a comprehensive security review skill or meta-skill include to counteract these failures?

## Sub-Questions

1. What empirical evidence exists (academic papers, security audits, CVEs, real-world incidents) showing that AI-generated code introduces security vulnerabilities at higher rates than human-written code?
2. Which specific vulnerability classes (OWASP Top 10, CWE categories) do AI agents most frequently introduce? What are the quantified rates?
3. What coding anti-patterns do agents produce that create security risks? (insecure defaults, missing validation, improper error handling, weak crypto, race conditions, etc.)
4. What security concerns do agents consistently skip or forget? (rate limiting, session management, secure headers, CSP, CORS, timing attacks, dependency risks, supply chain, etc.)
5. How do agents fail to understand security context — trust boundaries, data flow, privilege escalation paths, threat models — leading to contextually inappropriate code?
6. What are the known pitfalls when using AI agents themselves to perform security review? (false positives, false negatives, overconfidence, missing subtle bugs, hallucinated vulnerabilities)
7. What do the best security review processes look like — combining AI review with static analysis (Semgrep, CodeQL), DAST, threat modeling, and human review?
8. What specific checks, rules, and patterns should a security review skill enforce to catch agent-introduced vulnerabilities before they ship?

## Scope

- Breadth: exhaustive
- Time horizon: include historical but weight recent (2024-2026) heavily
- Domain constraints: framework-agnostic, covering web apps, APIs, infrastructure, and DevOps code
- Special interest: what's unique about agent-generated security bugs vs. traditional developer mistakes

## Project Context

This research informs the design of a security review skill (or meta-skill) for a Claude Code plugin suite. The existing `/security-review` skill covers 6 areas: secrets scan, dependency audit, auth/authz, input validation/injection, network/infrastructure, and findings reporting. The goal is to identify what's missing — especially agent-specific blind spots — and determine whether to upgrade the existing skill, build a new meta-skill, or both.

The existing skill currently does NOT specifically target:
- Agent-specific vulnerability patterns
- Context-aware threat modeling
- Integration with static analysis tools
- Supply chain / dependency confusion attacks
- Business logic vulnerabilities
- Cryptographic misuse beyond password hashing
- API security (broken object-level auth, mass assignment, etc.)
- Client-side security (prototype pollution, DOM-based attacks)

## Known Prior Research

None — this is the first deep research run.

## Output Configuration

- Research folder: artifacts/research/001D/
- Summary destination: artifacts/research/summary/001D-agent-security-gaps.md
- Topic slug: agent-security-gaps

## Special Instructions

- Prioritize empirical evidence and real examples over theoretical concerns
- Specifically look for studies comparing AI-generated code security vs. human-written code
- Find concrete vulnerability examples agents have produced (code snippets if possible)
- Look for existing security scanning tools, rulesets, and checklists designed specifically for AI-generated code
- Identify what a security skill can realistically catch vs. what requires human judgment or external tooling
- The end deliverable should be actionable: a blueprint for what to build
