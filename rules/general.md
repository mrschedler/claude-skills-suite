# General Development Rules

## Communication Style

- **Answer questions first** — don't start building until told to. Present analysis, then wait.
- Concise and direct. Bullet points over prose.

## Approach Selection

- **Before implementing anything non-trivial**, present 2-3 approaches (name, how, limitations, confidence). Wait for pick.
- For infrastructure/deployment especially, propose before executing.

## Plan Mode

- Do NOT exit plan mode until user explicitly approves ("approve", "implement", "go").
- Track change requests as numbered checklist. Re-read before finalizing.

## Security

- NEVER hardcode secrets. Use env vars + empty-string fallbacks.
- `.env` (gitignored) for runtime, `.env.example` (committed) for docs.
- Secret scan before any public/shared commit.

## Task Delegation

When a skill involves parallel or delegated work (multiple review lenses, parallel implementation units, research fan-out):

- **Describe the task, not the tool.** Say "run a security review on X" not "spawn a Sonnet subagent to review X."
- **The executing agent decides how.** Subagents, CLI tools, sequential execution — that's an implementation choice, not a skill concern.
- **Heavier models for judgment, lighter models for mechanical work.** Architecture decisions, security review synthesis, and final verdicts warrant the most capable model available. File searches, simple transforms, and repetitive edits can use whatever is fastest.
- Context >200K tokens = cost doubles — fork/compact proactively.

### Polling (MANDATORY)

- **NEVER sleep+poll loops** — burns context tokens per round trip
- Use background execution and check results when notified
- Only background fire-and-forget work; inline if output needed for next step

### Large Output Management

- Pipe 50KB+ responses to files, summarize.
- Redirect stdout to files and read selectively.

## Infrastructure

- Unraid (DeepThought, 192.168.0.129) via MCP Gateway (`mcp__gateway__*`)
- Docker on `traefik_proxy`. Cloudflare DNS+SSL.
- GitHub (mrschedler) = source of truth.
- Vault for credentials.
- Memory stack: Qdrant, Neo4j, MongoDB, PostgreSQL, Redis — all via MCP Gateway.
- Agents without MCP access can still execute skills — infrastructure calls are enhancements, not hard requirements.

## Environment

- **OS**: Windows 11 Pro, Git Bash shell
- **Shell**: bash (not zsh, not PowerShell for scripts)
- **Paths**: Forward slashes in scripts. No Homebrew, no macOS paths.
- **Timeout**: Use `timeout` from Git Bash if needed. No `gtimeout`.

## External CLI Delegation

External AI CLIs (Codex, Gemini, Vibe, Cursor, Copilot) may be available. Rules:

- Check availability before invoking. Never assume a CLI is installed.
- Load the corresponding driver skill for invocation details — don't guess at flags or paths.
- The primary orchestrating agent retains final say on architecture and security decisions. External CLIs provide input, not verdicts.
- Graceful degradation: if a CLI is unavailable, the skill must still produce useful output through its own capabilities.
- Consuming skills specify task type, prompt/context, and expected output. They do NOT embed CLI commands, flags, or path resolution.

## Parallel Patterns

These patterns describe the WHAT, not the HOW. The executing agent chooses its delegation strategy.

- **Research**: Multiple concurrent searches with different query angles, then synthesize
- **Review**: 3-4 review lenses running independently, then synthesize findings
- **Implementation**: Independent work units in isolated worktrees, then sequential merge
