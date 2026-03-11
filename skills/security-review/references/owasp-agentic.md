# OWASP Agentic Top 10 & Least-Agency Checks

Reference material for the security-review skill. Read this file when reviewing code
that involves AI agents, MCP servers, tool-using LLMs, or autonomous code execution.

> Sources: OWASP Agentic Top 10 (2026, 100+ collaborators), MAESTRO framework (CSA 2025),
> Maloyan & Namiot (2026) SoK, deep research run 001D (2026-03-10)

## OWASP Agentic Top 10 (2026)

### ASI01: Agent Goal Hijacking (Highest Risk)
**What**: Poisoned inputs redirect agent behavior — prompt injection via user input, file contents, API responses, or MCP tool outputs.
**Check for**:
- User input passed directly to LLM prompts without sanitization
- File contents (README, comments, commit messages) fed to agents without filtering
- API/webhook responses used as agent instructions
- MCP tool outputs treated as trusted instructions
**Remediation**: Input sanitization on all data entering agent context. Treat external data as untrusted.

### ASI02: Identity & Privilege Abuse
**What**: Over-privileged agent tokens, shared credentials, no per-action authorization.
**Check for**:
- Agent using admin/root credentials when read-only would suffice
- Single token/key used across all agent capabilities
- No credential scoping per tool or action
- Missing credential rotation
**Remediation**: Least-privilege tokens per tool. Rotate credentials. Scope to minimum necessary permissions.

### ASI03: Excessive Agency
**What**: Agent has more capabilities than needed for its task.
**Check for**:
- Write access when only read is needed
- Network access when only local operations are needed
- Shell/exec access for tasks that don't require it
- All MCP tools exposed when only a subset is needed
**Remediation**: Apply Least-Agency principle (see below). Restrict tool set per task.

### ASI04: Lack of Output Validation
**What**: Agent outputs (code, commands, API calls) executed without validation.
**Check for**:
- LLM-generated SQL/commands executed directly
- Agent-produced code deployed without review
- API calls made based on agent output without schema validation
- File writes without path validation
**Remediation**: Validate all agent outputs against expected schemas. Sandbox execution.

### ASI05: Insecure Agent Communication
**What**: Agent-to-agent or agent-to-tool communication without authentication or integrity.
**Check for**:
- Unencrypted communication between agent components
- No authentication on MCP server connections
- Missing message integrity verification
- Replay attacks possible on agent messages
**Remediation**: Encrypt and authenticate all inter-agent communication. Use message signing.

### ASI06: Tool Misuse
**What**: Authorized tools used for unauthorized purposes.
**Check for**:
- File read tool used to access `/etc/passwd`, `.env`, credentials
- Database tool used without query restrictions
- Shell tool without command allow-listing
- MCP tools without input validation
**Remediation**: Allow-list permitted operations per tool. Validate tool inputs. Log all tool invocations.

### ASI07: Uncontrolled Chained Actions
**What**: Multi-step agent actions without human checkpoints on high-impact operations.
**Check for**:
- Delete/destroy operations without confirmation gates
- Financial transactions without approval steps
- External API calls (email, messaging) without review
- Cascading operations that could amplify errors
**Remediation**: Human-in-the-loop for high-impact actions. Breakpoints in multi-step chains.

### ASI08: Knowledge Base Poisoning
**What**: RAG/vector store contamination that influences agent behavior.
**Check for**:
- Unauthenticated write access to knowledge bases
- No provenance tracking on ingested documents
- Missing content validation before embedding
- No anomaly detection on knowledge base updates
**Remediation**: Authenticate all knowledge base writes. Track provenance. Validate content.

### ASI09: Autonomous Code Execution
**What**: Agent-generated code executed without sandbox or review.
**Check for**:
- `eval()`, `exec()`, `Function()` on agent-generated strings
- Agent-produced scripts executed with full system access
- No sandbox (Firecracker, Wasm, Docker) for agent code execution
- Missing output validation on executed code results
**Remediation**: Sandbox all agent code execution. Validate outputs. Log everything.

### ASI10: Inadequate Logging & Monitoring
**What**: Insufficient audit trail for agent actions.
**Check for**:
- Agent actions not logged (tool calls, decisions, outputs)
- No way to trace agent decision chain post-incident
- Missing alerting on anomalous agent behavior
- No rate limiting on agent actions
**Remediation**: Log all agent actions with full context. Alert on anomalies. Enable post-incident tracing.

## The Least-Agency Principle

From OWASP Agentic Top 10: agents should operate with the **minimum autonomy, tool access,
and credential scope** necessary for their task.

### Checklist

1. **Minimum tool set** — Does the agent have access to tools it doesn't need for this task?
2. **Minimum permissions** — Are credentials scoped to the narrowest necessary access?
3. **Minimum autonomy** — Are high-impact decisions gated by human approval?
4. **Minimum data access** — Does the agent access data beyond what the task requires?
5. **Minimum network scope** — Can the agent reach services it doesn't need?
6. **Time-bounded access** — Do credentials/sessions expire when the task completes?

### When to Apply

- Any code that implements or configures an AI agent
- MCP server implementations
- Tool-calling LLM integrations
- Autonomous workflow systems
- CI/CD pipelines that invoke AI tools

## Prompt Injection Defense

Agent code and MCP servers are attack surfaces. 84% success rate on coding IDE injection
(30+ CVEs in Cursor, Copilot, Windsurf in 2025).

### Defense Checklist

1. **Input sanitization** — strip or escape control characters, instruction-like patterns from external data before passing to LLM context
2. **Context separation** — system instructions separated from user/external data (use delimiters, roles, or structured input)
3. **Output validation** — validate agent outputs match expected format/schema before execution
4. **Tool input validation** — MCP tools validate all parameters against schemas before execution
5. **Rate limiting** — limit agent action frequency to prevent runaway loops
6. **Sandboxed execution** — agent-generated code runs in isolated environments
7. **Monitoring** — log and alert on unexpected agent behavior patterns
