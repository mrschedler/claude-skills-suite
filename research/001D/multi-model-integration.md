### Research Goal
Compare 5 multi-model integration patterns for Claude Code skills with implementation details, failure modes, mitigations, and real examples.

### Method
Parallel tracks: Claude Code docs (skills/hooks/MCP/subagents/headless/costs), process/runtime docs (Node/Python/POSIX), Git worktree docs, and file-IPC references.

### Findings by Pattern

1. **Spawn-and-pipe**
- **Implementation:** Run Claude non-interactively with `claude -p`, pipe data from another tool/process, and prefer structured output (`--output-format json` or `stream-json`). [1]
- **Failure modes:**  
  Hang from pipe backpressure if stdout/stderr aren’t drained. [8][9][10]  
  Zombie children if parent does not reap exits via wait. [11]  
  Output truncation/corruption risk when `maxBuffer` is exceeded. [8]  
  Context blowup when large piped content is injected directly. [4]
- **Mitigations:**  
  Always consume both streams (`communicate()`/stream handlers), set timeout + kill, and reap processes. [8][9][10][11]  
  Use structured JSON output and chunk/summarize before passing to Claude. [1][4]
- **Real example:** `gh pr diff "$1" | claude -p --append-system-prompt "...security..." --output-format json`. [1]

2. **File-based IPC**
- **Implementation:** Exchange data through files (temp/state/output files). In CI, GitHub Actions uses `GITHUB_OUTPUT`, `GITHUB_STATE`, `GITHUB_ENV`. [15]
- **Failure modes:**  
  Output corruption from interleaved writes / partial writes. (Inference from file-lock + atomic-replace semantics.) [12][13]  
  Parse failures if protocol output includes unexpected text (e.g., hook stdout must be pure JSON). [5]  
  Context blowup if raw files are injected unfiltered. [4]
- **Mitigations:**  
  Write temp file then atomic `rename`/replace. [12]  
  Use advisory locking (`flock`) for single-writer sections. [13]  
  Enforce UTF-8/newline protocol where required and validate payload shape. [15][5]
- **Real example:** GitHub Actions step outputs via `>> $GITHUB_OUTPUT` for downstream step routing. [15]

3. **Slash command routing**
- **Implementation:** Define SKILL-based commands (`/skill-name`), route complex tasks to isolated subagent context with `context: fork`, and route MCP prompts via `/mcp__server__prompt`. [2][6]
- **Failure modes:**  
  Misrouting/over-trigger from broad skill descriptions. [2]  
  Parse/output issues from dynamic pre-exec content if formatting is noisy. [2][5]  
  Context blowup when command results are injected directly. [2][4]
- **Mitigations:**  
  Use `disable-model-invocation: true` for explicit-only commands, tight `allowed-tools`, argument hints, and forked context for verbose tasks. [2]  
  Use `/clear` and `/compact` to control context growth. [3][4]
- **Real examples:** `/mcp__github__pr_review 456`; SKILL with `context: fork` + `agent: Explore`. [2][6]

4. **MCP bridging**
- **Implementation:** Bridge tools by adding MCP servers over HTTP (recommended), stdio (local process), or SSE (deprecated), then consume tools/prompts in Claude. [6]
- **Failure modes:**  
  Transport/auth/server availability failures (HTTP/OAuth/stdio startup). [6]  
  Context blowup from many MCP tool definitions. [6][4]  
  Inference: lingering local stdio server processes can become operational “zombies” if lifecycle cleanup is weak. [6]
- **Mitigations:**  
  Prefer HTTP over deprecated SSE. [6]  
  Use server allow/deny policy (`serverName`/`serverCommand`/`serverUrl`). [6]  
  Enable MCP Tool Search (`ENABLE_TOOL_SEARCH`) and disable unused servers. [6][4]
- **Real examples:**  
  `claude mcp add --transport http notion https://mcp.notion.com/mcp`  
  `claude mcp add --transport stdio ... -- npx -y airtable-mcp-server`  
  `/mcp__jira__create_issue "Bug in login flow" high` [6]

5. **Git worktree isolation**
- **Implementation:** Isolate agent work in linked worktrees (`git worktree add/remove/prune/repair/lock`) or Claude subagent `isolation: worktree`; `/batch` uses isolated worktrees per unit. [14][7][2]
- **Failure modes:**  
  Stale/orphaned worktree metadata after manual deletion/moves. [14]  
  Hook-driven worktree creation/removal failures. [5]  
  Context/cost blowup when many isolated agents each keep their own context window. [4][7]
- **Mitigations:**  
  Standard hygiene: `remove`, `prune`, `repair`, `lock`; avoid manual path surgery. [14]  
  Keep teams small and prompts focused; clean up idle agents quickly. [4]  
  Use Worktree hooks carefully with strict output contracts. [5]
- **Real examples:** `/batch migrate ...` (one isolated worktree per agent), and Git’s emergency-fix add/remove flow. [2][14]

---

### Sources
[1] https://code.claude.com/docs/en/headless  
[2] https://code.claude.com/docs/en/slash-commands  
[3] https://code.claude.com/docs/en/interactive-mode  
[4] https://code.claude.com/docs/en/costs  
[5] https://code.claude.com/docs/en/hooks  
[6] https://code.claude.com/docs/en/mcp  
[7] https://code.claude.com/docs/en/sub-agents  
[8] https://nodejs.org/api/child_process.html  
[9] https://docs.python.org/3.9/library/subprocess.html  
[10] https://docs.python.org/3/library/asyncio-subprocess.html  
[11] https://man7.org/linux/man-pages/man2/waitpid.2.html  
[12] https://man7.org/linux/man-pages/man2/rename.2.html  
[13] https://man7.org/linux/man-pages/man2/flock.2.html  
[14] https://git-scm.com/docs/git-worktree.html  
[15] https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands

### Source Tally
- Total unique sources: **15**
- Claude/Anthropic docs: **7**
- Runtime/process docs (Node/Python): **3**
- POSIX/Linux man pages: **3**
- Git docs: **1**
- GitHub docs: **1**
