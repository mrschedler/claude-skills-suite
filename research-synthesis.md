# Skill Suite Research Synthesis

> Compiled from 4 parallel research agents. Covers: Gemini CLI, Codex CLI, installed plugin patterns, community skill landscape.

---

## Part 1: CLI Corrections (Your general.md Is Wrong)

### Gemini CLI — Current rules say: `gemini -p "..." -o text -y`

| What rules say | What's correct | Why |
|---|---|---|
| `-o text` | `--output-format text` | No `-o` short flag exists. Only long form. |
| `-y` | `--yolo` | No `-y` short flag exists. Only long form. |
| `-p "..."` | `-p "..."` | Correct. Also accepts positional: `gemini "prompt"` |

**Corrected command**: `gemini -p "..." --output-format text --yolo`

But `--yolo` is usually wrong for headless research. It auto-approves ALL tool calls (shell commands, file writes). For pure text Q&A, tools aren't invoked anyway, so `--yolo` is harmless but unnecessary. For safety:
- Pure research/analysis: `gemini -p "..."` (no flags needed — text output is default)
- Needs file access: `gemini -p "Review @src/main.ts"` (@ syntax reads files client-side)
- Needs tools: `timeout 120 gemini -p "..." --yolo` (MUST wrap with timeout — hangs if tool denied)

### Codex CLI — Current rules say: `codex exec "..." --json -C /tmp`

| What rules say | What's correct | Why |
|---|---|---|
| `-C /tmp` | `--cd /tmp` | `-C` doesn't exist. Use `--cd <DIR>`. |
| `--json` | Works but outputs JSONL stream | Not a single JSON object. Each line is a typed event. Hard to parse. |

**Corrected command**: `codex exec "..." --cd /tmp`

Better patterns for capturing output:
- Simple text capture: `RESULT=$(timeout 120 codex exec "prompt" 2>/dev/null)` — stdout is final message
- Write to file: `codex exec "prompt" -o /tmp/output.txt`
- Structured output: `codex exec "prompt" --output-schema schema.json -o /tmp/result.json`

### Critical Gotchas for Both CLIs

**Gemini:**
- MUST wrap with `timeout` — hangs indefinitely if tool call denied in `-p` mode
- `DEBUG` env var causes hang — `unset DEBUG` before calling
- `CI_*` env vars trigger CI mode detection — unset if present
- `GOOGLE_CLOUD_PROJECT` env var triggers org subscription check — unset for personal
- `--allowed-tools` is broken in non-interactive mode (known regression, P2)
- `--output-format json` has regressions in some versions (returns help text instead)
- Rate limits: officially 60 RPM / 1,000 RPD free tier, but actual may be lower
- `@file.ts` syntax for file references (client-side, before API call)
- No `--timeout` flag — OS-level `timeout` command only
- Exit codes: 0=success, 41=auth fail, 42=input error, 130=cancelled

**Codex:**
- MUST wrap with `timeout` — hangs indefinitely if out of credits
- Default sandbox is READ-ONLY in exec mode — need `--full-auto` for file writes
- Network blocked by default in `workspace-write` sandbox
- Requires git repo by default — `--skip-git-repo-check` for non-repo
- `--ephemeral` for one-shot tasks (don't persist session)
- macOS seatbelt silently ignores `network_access = true`
- `codex exec fork` doesn't exist — use `codex exec resume --last`
- Flag placement: global flags go AFTER `exec`: `codex exec --full-auto "prompt"`
- Auto-cancels all elicitation requests in exec mode
- Long prompts: prefer `codex exec - < file.md` over inline quoting
- Model: `gpt-5.3-codex` (current), reasoning effort: `minimal|low|medium|high|xhigh`
- For headless: use `OPENAI_API_KEY` env var, not ChatGPT subscription OAuth

---

## Part 2: /gemini Skill Design

### Purpose
Utility skill that encodes exact Gemini CLI syntax so other skills reference it instead of guessing.

### Availability Check
```bash
which gemini >/dev/null 2>&1 || { echo "GEMINI_UNAVAILABLE"; exit 1; }
```

### Task-Type Command Templates

**Research / Analysis (no tools needed):**
```bash
timeout 120 gemini -p "PROMPT" 2>/dev/null
```

**With file context:**
```bash
timeout 120 gemini -p "Review @path/to/file.ts for CONCERN" 2>/dev/null
```

**Long prompt (exceeds shell limits):**
```bash
cat /path/to/prompt.md | timeout 120 gemini 2>/dev/null
```

**JSON output (when parseable response needed):**
```bash
timeout 120 gemini -p "PROMPT" --output-format json 2>/dev/null | jq -r '.response'
```

**Model selection:**
```bash
timeout 120 gemini -m gemini-2.5-pro -p "PROMPT" 2>/dev/null
```

### Environment Safety
```bash
# Unset vars that cause hangs or mode changes
unset DEBUG 2>/dev/null
# If CI_* vars present, they force non-interactive mode (usually fine, but be aware)
```

### Fallback
If Gemini unavailable or times out → fall back to Claude WebSearch for web research tasks, or skip and note "Gemini unavailable" for review tasks.

### What Gemini Is Good At
- Web research with native Google Search grounding
- Devil's advocate / counter-review (different model family = genuinely different perspective)
- Large document analysis (1M token context)
- Math-heavy reasoning
- Competitive landscape / market analysis

### What Gemini Is Bad At
- Tool-mediated tasks in headless mode (hangs on denial)
- Anything requiring file writes (needs --yolo, risky)
- Reliability (known hang issues, rate limit uncertainty)

---

## Part 3: /codex Skill Design

### Purpose
Utility skill that encodes exact Codex CLI syntax so other skills reference it instead of guessing.

### Availability Check
```bash
which codex >/dev/null 2>&1 || { echo "CODEX_UNAVAILABLE"; exit 1; }
```

### Task-Type Command Templates

**Code review (read-only, safest):**
```bash
RESULT=$(timeout 120 codex exec --ephemeral --sandbox read-only \
  "PROMPT" 2>/dev/null)
```

**Code review with high reasoning:**
```bash
RESULT=$(timeout 120 codex exec --ephemeral --sandbox read-only \
  -c model_reasoning_effort="high" \
  "PROMPT" 2>/dev/null)
```

**Code generation / file writes:**
```bash
timeout 120 codex exec --full-auto --ephemeral --cd /path/to/project \
  "PROMPT" 2>/dev/null
```

**Structured output (for downstream parsing):**
```bash
timeout 120 codex exec --ephemeral --output-schema /path/to/schema.json \
  -o /tmp/result.json \
  "PROMPT" 2>/dev/null
```

**Write final message to file:**
```bash
timeout 120 codex exec --ephemeral -o /tmp/output.txt \
  "PROMPT" 2>/dev/null
```

**Long prompt via stdin:**
```bash
timeout 120 codex exec --ephemeral - < /path/to/prompt.md 2>/dev/null
```

**With additional read-only directories:**
```bash
timeout 120 codex exec --ephemeral --cd /project --add-dir /shared/libs \
  "PROMPT" 2>/dev/null
```

### Environment Safety
```bash
# Use API key for headless (not ChatGPT OAuth)
export OPENAI_API_KEY="$OPENAI_API_KEY"
```

### Fallback
If Codex unavailable or times out → skip and note "Codex unavailable". No direct substitute (Codex's strength is code-specific analysis from a different model family).

### What Codex Is Good At
- Code review and quality analysis
- Test generation suggestions
- Efficiency/refactoring recommendations
- Fast code generation and iteration
- Structured output via --output-schema (unique capability)
- Code pattern detection

### What Codex Is Bad At
- Web research (network blocked by default)
- Non-code tasks
- Long-running tasks (no timeout flag, can hang on credit exhaustion)
- Interactive workflows (exec mode auto-cancels all elicitations)

---

## Part 4: Patterns to Adopt from Installed Plugins

### 1. Confidence Scoring (from pr-review-toolkit)
- Score every review finding 0-100
- Threshold at 80+ (filters ~95% false positives)
- Rubric: 0=not confident, 25=somewhat, 50=moderate, 75=highly, 100=certain
- Apply to: counter-review, security-review, test-review, refactor-review, completeness, compliance

### 2. Ralph-Loop Stop Hook Pattern (from ralph-loop)
- Stop hook intercepts Claude's exit via `decision: "block"` + `reason`
- Check `stop_hook_active` to avoid infinite loops
- This is EXACTLY the mechanism for stop-docs-check and stop-context-check
- First stop: block + inject reason → Claude does the check
- Second stop: `stop_hook_active=true` → exit 0 → Claude stops

### 3. Progressive Disclosure (from plugin-dev)
- SKILL.md: ~2,000 words max (lean core)
- references/: detailed guides, patterns, advanced techniques
- examples/: working code samples
- scripts/: validation and test utilities
- Metadata always loaded; SKILL.md on trigger; references on demand

### 4. Example Blocks for Triggering (from all plugins)
```
<example>
Context: [Situation]
user: "[Exact user message]"
assistant: "[Response before triggering]"
<commentary>
[Why this triggers the skill]
</commentary>
</example>
```
Include 2-4 examples per skill showing different trigger scenarios.

### 5. Phase-Based Workflows with Confirmation Gates (from feature-dev)
- Break complex tasks into numbered phases
- Critical phases marked "DO NOT SKIP"
- User confirmation required before proceeding past design/architecture decisions
- TodoWrite tracks progress across phases

### 6. Clarifying Questions Phase (from feature-dev Phase 3)
- Mandatory — never skip
- Maps directly to our project-questions skill
- Ask probing questions, challenge assumptions, find gaps BEFORE committing to a plan

### 7. Focused File Reading Strategy (from feature-dev)
- Agents return "essential files to read" first
- Then Claude reads those specific files
- Beats undirected codebase exploration

---

## Part 5: Patterns to Adopt from Community Landscape

### 1. Knowledge-Driven Development (from metaswarm)
- Learnings from every session feed back into a knowledge base
- Agents get selective retrieval (only relevant facts, not everything)
- Our cnotes.md is session-scoped; this is project-lifetime-scoped
- Consider: evolve cnotes.md into a compound knowledge base, not just a log

### 2. "Compound, Don't Compact" (from Continuous-Claude-v3)
- Instead of overwriting c-compact.md each time, accumulate learnings
- Extract patterns, decisions, and insights across sessions
- Start fresh sessions with full signal (not compressed noise)
- Their continuity ledgers: goal/constraints, done/next, decisions, working files

### 3. TDD for Skills (from Superpowers + Anthropic Skill Creator)
- Write eval cases for skills
- If you didn't watch an agent fail without the skill, you don't know if it teaches the right thing
- Four modes: Create, Eval, Improve, Benchmark

### 4. Audit-Context-Building Phase (from Trail of Bits)
- Before reviewing, systematically build deep understanding
- Block-by-block analysis, not just "skim and find issues"
- Our reviews go straight to findings — adding a context-building phase would improve quality

### 5. Parallel Review Execution (from hamy.xyz 9-agent pattern)
- Our project-review chains reviews sequentially
- Running all review subagents in parallel would be much faster
- Synthesize findings with severity ranking at the end

### 6. Spec Compliance Review (from Three-Stage Code Review)
- Dedicated lens: does implementation match the spec?
- Our counter-review partially does this but is broader
- A focused "code vs project-context.md/features.md" drift check would be cleaner

### 7. Structured Output Schemas (from Codex --output-schema)
- Define JSON schemas for review findings, research results, etc.
- Forces consistent structure from Codex subagent
- Can be validated programmatically

---

## Part 6: New Skill Ideas from Landscape Research

### Strong candidates (fill real gaps):

1. **skill-doctor** — Self-diagnostic. Checks if skill suite is properly installed, hooks configured, templates accessible, CLIs available. Run after install or when things break.

2. **drift-detector** — Periodic check that code, docs, features.md haven't drifted from project-context.md. Currently buried in reviews; could be standalone and hook-triggered.

3. **release-prep** — Automated changelog generation, version bumping, release notes from git history and cnotes.md. Several suites include this.

4. **onboarding** — Generate a "getting started" guide for a new contributor based on project-context.md, codebase structure, and collab.md.

5. **parallel-implement** — Decompose build plan into independent work units, spawn worktree-based agents for each. (metaswarm and ccpm both do this.)

### Nice-to-have (not core lifecycle):

6. **dependency-audit** — Analyze dependency tree for vulnerabilities, licenses, bloat.
7. **architecture-decision-record** — Formalize decisions into proper ADR format from cnotes.md.
8. **session-stats** — Track token usage, skill invocations, cost per session.

---

## Part 7: Updated Research Counter-Review Design

Original spec: 10 MCP subagents → synthesis → 1 Sonnet counter subagent

### Proposed: Triple-Counter with 3 Model Families

```
10 MCP subagents → raw findings → Claude compiles synthesis →
  Fan out 3 counter-reviewers in parallel:
    1. Sonnet subagent — fresh-eyes, no context bleed, challenges completeness
    2. Gemini CLI — different model family, web-grounded fact check, devil's advocate
    3. Codex CLI — code-focused feasibility check, implementation gap analysis
  → Claude reads all 3 counter reports
  → Decides: real gaps → run 002, or sufficient → finalize
```

### Gemini counter prompt pattern:
```bash
cat research/research_synthesis.md | timeout 120 gemini -p \
  "You are a research reviewer. Read this synthesis and challenge it:
   1. What claims lack sufficient evidence?
   2. What important perspectives are missing?
   3. What contradictory evidence exists that was ignored?
   4. What's the weakest section and why?
   Be specific. Cite what's missing, not just 'needs more research.'" \
  2>/dev/null > research/runs/NNN/gemini_counter.md
```

### Codex counter prompt pattern:
```bash
timeout 120 codex exec --ephemeral --sandbox read-only \
  -c model_reasoning_effort="high" \
  "Read the research synthesis and evaluate from an implementation perspective:
   1. Are the proposed approaches actually feasible to build?
   2. What technical gaps exist between research findings and implementation?
   3. What code patterns or libraries were mentioned but not validated?
   4. What's missing that a developer would need to know?
   Be specific. Reference concrete implementation concerns." \
  -o research/runs/NNN/codex_counter.md 2>/dev/null
```

---

## Part 8: Codex/Gemini Integration Map (Updated)

| Skill | Gemini Use | Codex Use | How to call |
|---|---|---|---|
| research-execute | Counter: challenge synthesis, web fact-check | Counter: implementation feasibility | Parallel fan-out after synthesis. Pipe synthesis via stdin. |
| counter-review | Devil's advocate on architecture | Code-level gap analysis, truncated code detection | Parallel. Pass codebase summary + project-context.md. |
| security-review | Web research on CVEs, recent advisories | Static analysis patterns, dependency audit | Parallel. Gemini: web search. Codex: read-only code review. |
| test-review | — | Test generation suggestions, coverage gap ID | Codex only. Read-only sandbox + --output-schema for structured findings. |
| refactor-review | — | Efficiency patterns, redundancy detection | Codex only. Read-only sandbox. |
| review-completeness | — | Scan for stubs, placeholders, incomplete impl | Codex only. Read-only sandbox. |
| review-compliance | — | Check code against rules (fast pattern match) | Codex only. Read-only sandbox. |
| build-plan | Competitive landscape, similar approaches | Technical feasibility of proposed architecture | Parallel. Gemini: web research. Codex: code analysis. |
| project-questions | Research user's domain for better probing | — | Gemini only. Quick web grounding before asking questions. |

### Per-skill instruction pattern:
Each skill that uses Gemini/Codex includes a section like:
```
## External Review (Gemini + Codex)
Before finalizing findings, call the /gemini and /codex utility skills:
- Gemini task type: counter-review
- Gemini prompt: [specific prompt template]
- Codex task type: read-only review
- Codex prompt: [specific prompt template]
- Timeout: 120s each
- Fallback: if unavailable, note "External review skipped — [CLI] unavailable"
- Output: write to [specific file path]
```

---

## Part 9: Existing Skills — Remove vs Keep vs Fold In

### Remove from ~/.claude/skills/ (absorbed into spec):
- `review-efficiency` → becomes `refactor-review` (adds drift detection + Codex integration)
- `review-all` → absorbed into `project-review` meta-skill (parallel execution + Codex/Gemini)
- `research` → superseded by `research-plan` + `research-execute` (MCP connectors + triple counter)

### Keep in ~/.claude/skills/ (genuinely different):
- `review-completeness` → add as spec skill #18 (catches stubs/TODOs/placeholders — unique lens)
- `review-compliance` → add as spec skill #19 (checks against documented rules — unique lens)

### Keep in ~/.claude/skills/ (infra-specific, out of scope):
- backup-verify, deploy-gateway, infra-health, patch-dify, plan, powerapps, project-dashboard, sync-config, sync-to-github

---

## Part 10: Updated Spec Skill Count

### Atomic skills: 21
1-17: Original spec skills
18: review-completeness (from existing)
19: review-compliance (from existing)
20: gemini (NEW utility skill)
21: codex (NEW utility skill)

### Potential additions: 2-5 (from landscape research)
22: skill-doctor (self-diagnostic)
23: drift-detector (standalone drift check)
24: release-prep (changelog + versioning)
25: onboarding (contributor guide generation)
26: parallel-implement (worktree-based parallel execution)

### Meta-skills: 3 (unchanged)
- project-init
- project-review (updated: parallel execution + Codex/Gemini + 6 review lenses)
- project-evolve

### Hooks: 6 (was 5)
1-5: Original spec hooks (with corrected Stop hook mechanism)
6: PreCompact safety-net hook (writes minimal c-compact.md before auto-compaction)
