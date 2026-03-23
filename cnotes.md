# Collaboration Notes

> Newest first. Each note is locked once a newer note exists above it.
> Format: `CN-YYYYMMDD-HHMMSS-AUTHOR`

## Notes (Newest First)

---CODEX---------------------
note_id: CN-20260320-175159-CODEX
timestamp_utc: 2026-03-20T17:51:59Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Harden Codex timeout handling after another live timeout failure
files_touched: hooks/pre-commit-codex-lint.sh, cnotes.md
files_reviewed: hooks/pre-commit-codex-lint.sh, skills/codex/SKILL.md
summary: Updated the active pre-commit Codex wrapper to retry once on timeout instead of treating a single 30s timeout as the final result.
details: |
  - Replaced the one-shot `gtimeout 30 ... || echo CLEAN` path with a helper that runs Codex once at 30s and retries once at 60s if the first attempt exits 124.
  - Preserved the hook's non-blocking behavior for Codex outages: if both attempts fail or Codex exits non-zero, the semantic pass is skipped and the commit is not blocked by the Codex stage alone.
  - Left deterministic linters and secret scanning unchanged; only the Codex stage timeout handling was hardened.
validation: `bash -n hooks/pre-commit-codex-lint.sh`
risks_or_gaps: this hardens the repo-local pre-commit hook, not any external Claude wrapper that may still launch Codex with too-short timeouts or no retry path
handoff_to: none
next_actions: If the failing path was Claude's own worker wrapper rather than this hook, capture the exact spawned command and stderr so the same retry pattern can be applied there
-------------------------------

---CODEX---------------------
note_id: CN-20260320-174453-CODEX
timestamp_utc: 2026-03-20T17:44:53Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Exhaustively validate Gemini CLI subagent/headless behavior against the live local install and patch stale Gemini driver guidance
files_touched: skills/gemini/SKILL.md, skills/project-questions/SKILL.md, skills/research-execute/SKILL.md, skills/release-prep/SKILL.md, skills/meta-review/SKILL.md, skills/meta-deep-research-execute/references/protocol-detail.md, skills/deep-research-skill-audit.md, README.md, cnotes.md
files_reviewed: skills/gemini/SKILL.md, skills/project-questions/SKILL.md, skills/research-execute/SKILL.md, skills/release-prep/SKILL.md, skills/meta-review/SKILL.md, skills/meta-deep-research-execute/references/protocol-detail.md, skills/deep-research-skill-audit.md, README.md, coterie.md, features.md
summary: Live Gemini 0.33.0 testing showed the driver skill was materially stale. I rewrote the Gemini guidance to match the current CLI, updated dependent skills to stop calling the removed `--agent` flag, and corrected the README install package.
details: |
  - Verified the installed CLI is Gemini 0.33.0 and that `gemini --help` exposes `-o/--output-format`, `-y/--yolo`, `skills`, `hooks`, and `mcp`, but not `--agent`.
  - Reproduced the current failure mode for the old driver: `--agent codebase_investigator` exits with `Unknown argument: agent`, and the old hardcoded path `/Users/trevorbyrum/.npm-global/bin/gemini` does not exist on this machine.
  - Confirmed current subagent forcing uses `@subagent` prompt syntax. Built-in subagents defaulted to preview models that hit `429 MODEL_CAPACITY_EXHAUSTED` in headless mode here; an isolated `.gemini/settings.json` override restored successful `@codebase_investigator` execution.
  - Confirmed plain headless automation is reliable with pinned `-m gemini-2.5-flash-lite` plus JSON output, file-context prompts, and stdin piping. Confirmed `GOOGLE_CLOUD_PROJECT` still breaks auth flow here and that stderr always carries startup noise.
  - Updated consuming skills and the deep-research protocol reference to stop instructing `--agent generalist` / `--agent codebase_investigator`, and corrected the README install package to `@google/gemini-cli`.
validation: `gemini --version`; `gemini --help`; `gemini skills --help`; `gemini hooks --help`; `gemini mcp --help`; live prompt tests for `-o json`, `--output-format json`, `-y`, `--yolo`, stdin piping, `@codebase_investigator`, custom local subagent, `--allowed-tools`, model pinning, and negative tests for `--agent` plus the stale hardcoded path; `git diff --check`
risks_or_gaps: `project-context.md` is missing, so compliance checks were partial; built-in Gemini subagents remain capacity-sensitive on this machine unless callers pin stable models or override agent model settings
handoff_to: none
next_actions: If Claude still drives Gemini through stale syntax elsewhere, search for `/gemini` consumers outside the active skill files and convert them to the driver’s JSON-first templates
-------------------------------

---CODEX---------------------
note_id: CN-20260320-155555-CODEX
timestamp_utc: 2026-03-20T15:55:55Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Exhaustively validate the Codex driver against the live local CLI and fix stale invocation paths
files_touched: skills/codex/SKILL.md, skill-suite-build-spec.md, skills/meta-deep-research-execute/references/protocol-detail.md, hooks/pre-commit-codex-lint.sh, cnotes.md
files_reviewed: skills/codex/SKILL.md, skill-suite-build-spec.md, skills/meta-deep-research-execute/references/protocol-detail.md, hooks/pre-commit-codex-lint.sh, ~/.codex/config.toml
summary: Live Codex testing showed the documented driver was wrong in two critical ways on this machine: NVM discovery missed the symlinked install, and the MCP disable examples used invalid server keys. Patched the docs and the active pre-commit hook to match the working invocation shape.
details: |
  - Reproduced the path-resolution failure: `command -v codex` returns an alias string in login zsh, and the NVM fallback `find ... -type f` misses the real `bin/codex` because it is a symlink. Updated the driver/spec/reference snippets to prefer `whence -p` in zsh, `type -P` in bash, then an NVM search that allows `-type l`.
  - Reproduced the MCP failure: the old overrides `mcp_servers.homelab_gateway.enabled=false` and `mcp_servers.ssh_manager.enabled=false` fail on the current `~/.codex/config.toml` with `Error loading config.toml: invalid transport`. Updated the examples and hook to the actual configured server keys: `homelab-gateway`, `ssh-tower`, and `github`.
  - Verified that disabling only `homelab-gateway` and `ssh-tower` still starts the GitHub MCP server, so the no-MCP examples now disable all three configured servers.
  - Verified runtime behavior for the driver templates: read-only review, high-reasoning review, stdin prompt, `-o` output capture, `--output-schema`, `--json` JSONL output, `--add-dir`, workspace-write file creation, non-repo failure without `--skip-git-repo-check`, and the `codex exec -a never` parse failure.
  - Updated the sandbox guidance to stop claiming a universal default. On this machine, trusted repo runs default to `read-only`, while a non-repo `--skip-git-repo-check` run came up as `workspace-write`; callers must pass sandbox mode explicitly.
validation: `codex --version`; `codex exec --help`; `bash -n hooks/pre-commit-codex-lint.sh`; live smoke tests for read-only, high reasoning, stdin, `-o`, `--output-schema`, `--json`, `--add-dir`, and workspace-write; negative tests for stale MCP keys, omitted `--skip-git-repo-check`, and `codex exec -a never`
risks_or_gaps: older historical notes and research artifacts still describe superseded Codex behavior; they are not active logic, but they can confuse future maintenance if treated as source of truth
handoff_to: none
next_actions: If Claude still fails to launch Codex after this, capture the exact spawned command and stderr from Claude's wrapper path; the repo-local driver and active pre-commit hook now match the live CLI on this machine
-------------------------------

---CODEX---------------------
note_id: CN-20260313-065430-CODEX
timestamp_utc: 2026-03-13T06:54:30Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Revalidate Vibe and Copilot driver skills against live CLIs and correct stale guidance
files_touched: skills/vibe/SKILL.md, skills/copilot/SKILL.md, cnotes.md
files_reviewed: skills/vibe/SKILL.md, skills/copilot/SKILL.md, ~/.vibe/config.toml
summary: Patched the Vibe and Copilot driver skills to match live CLI behavior on this machine, including Vibe plan/json semantics and Copilot path, headless, model, and JSON extraction guidance.
details: |
  - Verified Vibe 2.4.2 at `$HOME/.local/bin/vibe`, confirmed `--enabled-tools read_file grep` prevented writes, and confirmed `--agent plan` works in one-shot headless mode instead of requiring a separate plan file.
  - Added Vibe JSON guidance after confirming `--output json` writes a single JSON array and that the final assistant response can be extracted with `jq 'map(select(.role == "assistant")) | last.content'`.
  - Verified Copilot CLI 1.0.4 at `$HOME/.local/bin/copilot`, corrected the stale availability check that hardcoded `/opt/homebrew/bin/copilot`, and softened the over-strong claim that `--allow-all-tools` / `--no-ask-user` are mandatory for every headless prompt.
  - Confirmed Copilot JSON mode emits mixed-event JSONL where the last line is a `result` event, not the final assistant message, and updated extraction guidance to filter `assistant.message` records.
  - Removed the stale fixed-default-model implication from the Copilot skill after observing an unpinned simple prompt auto-route to `claude-haiku-4.5` on 2026-03-13.
validation: `vibe --version`; `copilot version`; disposable write tests for Vibe and Copilot; `jq -r 'map(select(.role == "assistant")) | last.content // empty' /tmp/vibe-json.out`; `jq -r 'select(.type=="assistant.message") | .data.content // empty' /tmp/copilot-json.out | tail -1`
risks_or_gaps: project-context.md is missing in this repo, so compliance checks remain partial; Copilot tests consumed premium requests; future CLI releases may change output/event shapes again
handoff_to: none
next_actions: Audit consuming skills that invoke `/copilot` or `/vibe` if they depend on the removed assumptions about Copilot defaults or Vibe `--agent plan`
-------------------------------

---CODEX---------------------
note_id: CN-20260313-064925-CODEX
timestamp_utc: 2026-03-13T06:49:25Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Correct Cursor skill safety guidance after live behavior tests
files_touched: skills/cursor/SKILL.md, cnotes.md
files_reviewed: skills/cursor/SKILL.md
summary: Updated the Cursor driver to match the current CLI's observed behavior: `--force` is not a write barrier, and `--mode ask` / `--mode plan` are not safely read-only on this build.
details: |
  - Verified with disposable git repos that plain `agent -p --trust --workspace ...` wrote file changes even without `--force`.
  - Verified that both `agent -p --trust --mode ask ...` and `agent -p --trust --mode plan ...` also wrote file changes on the current Cursor Agent build, despite `agent --help` describing those modes as read-only/planning.
  - Rewrote the skill's flag table, execution-mode descriptions, gotchas, and examples to remove the false safety guarantee and steer analysis tasks toward isolated worktrees or disposable copies.
  - Added a post-run git-status diff guard pattern for analysis tasks executed against a non-disposable checkout.
validation: Disposable repo tests with `agent -p --trust`, `agent -p --trust --mode ask`, `agent -p --trust --mode plan`, and `--force` variants all appended lines to test files on 2026-03-13; `rg -n 'write barrier|reliably read-only|There is no `-o` output flag|Auto-approve commands/tool execution' skills/cursor/SKILL.md`
risks_or_gaps: project-context.md is missing in this repo, so compliance checks remain partial; the skill now reflects observed local behavior, but future Cursor releases may restore stricter read-only semantics
handoff_to: none
next_actions: If other skills still assume Cursor `ask`/`plan` are safe dry runs, audit those consumers and update them to isolate writes or detect mutations
-------------------------------

---CODEX---------------------
note_id: CN-20260313-064615-CODEX
timestamp_utc: 2026-03-13T06:46:15Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Troubleshoot Cursor headless subagent invocation and patch stale driver guidance
files_touched: skills/cursor/SKILL.md, cnotes.md
files_reviewed: skills/cursor/SKILL.md, /Users/trevorbyrum/Project/arbytr/artifacts/reviews/review-synthesis-1.md
summary: Verified that Cursor Agent works live in arbytr and narrowed the failure to stale local driver guidance that documented a non-existent `-o` flag for headless output capture.
details: |
  - Confirmed the installed Cursor CLI at `$HOME/.local/bin/agent` and verified authentication with `agent status`, which reported `Logged in as trevor.byrum@duke.edu`.
  - Ran a live read-only headless call in `/Users/trevorbyrum/Project/arbytr` with `agent -p --trust --mode ask --workspace ... "Reply with OK only."` and received `OK`.
  - Reproduced the wrapper bug by invoking the same command with `-o /tmp/cursor-invalid.md`; the CLI exited `1` with no stderr on the current build.
  - Patched the local Cursor driver skill to remove the stale `-o` guidance and document stdout redirection / `--output-format json` as the correct capture pattern.
validation: `agent status`; `gtimeout 120 "$AGENT" -p --trust --mode ask --workspace /Users/trevorbyrum/Project/arbytr "Reply with OK only."`; `"$AGENT" -p --trust --mode ask --workspace /Users/trevorbyrum/Project/arbytr -o /tmp/cursor-invalid.md "Reply with OK only."` exited 1
risks_or_gaps: project-context.md is missing in this repo, so compliance checks remain partial; this patched the repo-local driver guidance, not any external Claude wrapper that may still be hardcoding `-o`
handoff_to: none
next_actions: If Cursor still fails from Claude, capture the exact spawned `agent` command and stderr from that wrapper path and compare it to the known-good invocation
-------------------------------

---CODEX---------------------
note_id: CN-20260313-064142-CODEX
timestamp_utc: 2026-03-13T06:41:42Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Fix stale Codex CLI wrapper guidance after reproducing Arbytr worker failures
files_touched: skills/codex/SKILL.md, hooks/pre-commit-codex-lint.sh, skills/meta-deep-research-execute/references/protocol-detail.md, skill-suite-build-spec.md, cnotes.md
files_reviewed: skills/codex/SKILL.md, hooks/pre-commit-codex-lint.sh, skills/meta-deep-research-execute/references/protocol-detail.md, skill-suite-build-spec.md, /Users/trevorbyrum/Project/arbytr/artifacts/reviews/review-synthesis-1.md
summary: Patched the Codex driver and related references to use the current local CLI shape: command -v/Homebrew-first discovery, no shell-glob NVM lookup, current MCP server keys, and exec-specific flag guidance for codex-cli 0.104.0.
details: |
  - Replaced `ls ~/.nvm/versions/node/*/bin/codex` discovery with `command -v codex`, `/opt/homebrew/bin/codex`, then a filesystem NVM search that does not trip zsh's `nomatch` behavior.
  - Updated MCP disable examples from stale keys (`homelab-gateway`, `ssh-tower`, `github`) to the current config keys (`homelab_gateway`, `ssh_manager`) and documented that overrides must match actual `~/.codex/config.toml` entries.
  - Clarified approval guidance: top-level `codex --help` lists `-a`, but `codex exec --help` on 0.104.0 does not, and `codex exec -a never` fails.
  - Applied the same discovery fix to the pre-commit Codex hook, the deep-research protocol reference, and the suite build spec so the stale pattern does not get regenerated.
validation: `bash -n hooks/pre-commit-codex-lint.sh`; live smoke test succeeded with `codex exec --ephemeral --skip-git-repo-check -c 'mcp_servers.homelab_gateway.enabled=false' -c 'mcp_servers.ssh_manager.enabled=false' -s read-only -C /Users/trevorbyrum/Project/arbytr -o /tmp/codex-driver-smoke.md "Reply with OK only."`
risks_or_gaps: project-context.md is still missing in this repo, so compliance checks remain partial; Codex still warns about a stale state DB migration mismatch in ~/.codex/state_5.sqlite, but that did not block exec
handoff_to: none
next_actions: If Claude still reports transport/config failures, capture the exact spawned Codex command and stderr from that worker path rather than relying on old synthesis artifacts
-------------------------------

---CLAUDE--------------------
note_id: CN-20260313-060000-CLAUDE
timestamp_utc: 2026-03-13T06:00:00Z
author: CLAUDE
activity_type: CODE_REVIEW
work_scope: 007D deep research — LLM agent code efficiency and over-engineering control
files_touched: artifacts/research/summary/007D-llm-agent-code-efficiency.md
files_reviewed: none
summary: Completed deep research protocol 007D on controlling LLM code over-engineering. 48 queries, ~280 sources scanned, 78 cited. 15 verified claims, 5 high confidence, 4 contested, 2 debunked. Key findings: explicit CLAUDE.md anti-over-engineering rules work; hooks beat instructions for enforcement; multi-agent review is highest-leverage quality pattern; spec-driven development is best generation-time intervention. Emergent topics: spec-driven development, AGENTS.md cross-tool standard, Rule of Least Power.
details: Ran Tracks A-D (Opus reasoning, Sonnet connectors/WebSearch, Codex validation, Gemini web grounding). 45+ WebSearch queries, 5 WebFetch deep reads, 12 academic papers, 8 industry reports. Coverage expansion added spec-driven development as highest-impact emergent topic.
validation: Cross-validated claims across Anthropic official docs, peer-reviewed studies, industry surveys, practitioner blogs
risks_or_gaps: Source count ~280 below 1000+ target. Gemini/Codex CLI background workers pending completion. Model-specific comparisons lack controlled studies. Long-term maintainability (2+ years) unstudied.
handoff_to: none
next_actions: User should review contested findings (non-developer viability, over-simplification risks). Consider encoding top findings into CLAUDE.md rules and review pipeline updates.
------------------------------

---CODEX---------------------
note_id: CN-20260313-032923-CODEX
timestamp_utc: 2026-03-13T03:29:23Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Run Vibe on a real file-scoped task and apply the result
files_touched: skills/browser-review/SKILL.md, cnotes.md
files_reviewed: skills/browser-review/SKILL.md, skills/vibe/SKILL.md, references/cross-cutting-rules.md
summary: Used the local Vibe driver to rewrite the browser-review skill description to fit the <=150 character budget without changing meaning.
details: |
  - Selected skills/browser-review/SKILL.md because it was clean in the worktree and over the description budget.
  - Ran Vibe headlessly with -p, gtimeout, read_file-only scope, and a prompt limited to rewriting that file's YAML description line.
  - Vibe returned: description: Visual QA via browser MCP tools (Playwright/browser-use). Use for UI review, visual bugs, or web interface inspection.
  - Applied the returned line directly. Final description length: 118 characters.
validation: Verified description length with a local script; placeholder/debug scan on touched files returned no matches
risks_or_gaps: project-context.md is still missing, so compliance checks remain partial at the repo level
handoff_to: none
next_actions: Continue trimming remaining over-budget skill descriptions with the same file-scoped Vibe pattern if desired
-------------------------------

---CODEX---------------------
note_id: CN-20260313-032746-CODEX
timestamp_utc: 2026-03-13T03:27:46Z
author: CODEX
activity_type: CODE_WRITE
work_scope: Run Vibe via the local driver skill and satisfy skill-suite prerequisites
files_touched: coterie.md, cnotes.md
files_reviewed: skills/vibe/SKILL.md, references/cross-cutting-rules.md
summary: Created the missing coterie.md from the local template, then executed a narrow headless Vibe smoke test against the Vibe skill and cross-cutting rules files.
details: |
  - Resolved the Vibe binary dynamically per skills/vibe/SKILL.md and used /opt/homebrew/bin/gtimeout as required by the driver skill.
  - Ran Vibe with -p, --output text, --max-turns 10, --workdir /Users/trevorbyrum/Project/claude, and read-only tools restricted to read_file and grep.
  - Prompt scope: skills/vibe/SKILL.md and references/cross-cutting-rules.md only.
  - Captured successful output at /tmp/vibe-smoke.md (289 chars).
validation: Vibe smoke test exited 0 and returned 5 bullet points; output length check passed
risks_or_gaps: Smoke test only; this did not validate Vibe file-writing flows or broader multi-work-unit orchestration
handoff_to: none
next_actions: Use the same /vibe driver pattern for a concrete file-scoped generation or review task when needed
-------------------------------

---CLAUDE--------------------
note_id: CN-20260312-203000-CLAUDE
timestamp_utc: 2026-03-12T20:30:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: New skill-forge skill — unified create/edit for skill suite
files_touched: skills/skill-forge/SKILL.md, skills/skill-forge/references/skill-template.md, skills/skill-forge/references/validation-checklist.md
summary: |
  Built /skill-forge — single skill that handles both creating new skills and editing existing ones.
  Auto-detects mode based on whether skills/<name>/SKILL.md exists.
  Two reference files encode all suite patterns and lessons learned:
  - skill-template.md: canonical SKILL.md structure (frontmatter rules, section order, progressive disclosure architecture, output patterns A/B/C, sizing guidelines)
  - validation-checklist.md: 40+ checks across 8 categories (frontmatter, structure, content, anti-patterns, DB integration, driver boundary, progressive disclosure, infrastructure)
  Anti-pattern checks encode every production bug we've hit: always-on descriptions, subagent DB writes, stale file refs, bare timeout, line-count validation, context stuffing.
  Self-validated: PASS (0 failures, 0 warnings). Description at 146 chars.
decisions:
  - Single skill (skill-forge) instead of separate skill-create + skill-edit — mode detection is trivial
  - Validation checklist uses FAIL/WARN severity — FAILs must be fixed before finishing
  - User confirms plan before writing (Phase 2 gate) — follows general.md approach-selection rule
handoff_to: CLAUDE
next_actions: Consider adding skill-forge to meta-init scaffold chain; update todo/features if needed
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-193000-CLAUDE
timestamp_utc: 2026-03-12T19:30:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Counter-review upgrade — adversarial red-team capabilities
files_touched: skills/counter-review/SKILL.md, skills/counter-review/references/abuse-cases.md, skills/counter-review/references/attack-chains.md, skills/counter-review/references/what-if-scenarios.md
summary: |
  Upgraded counter-review from 4 attack vectors to 7. Added 3 adversarial sections + 3 progressive-disclosure reference files.
  New sections: §6 Adversarial Abuse Cases (business logic, input boundaries, state manipulation, agentic abuse), §7 Attack Chain Construction (trust boundary mapping, escalation paths, chain severity scoring), §8 "What If" Scenarios (infrastructure failure, security breach, scale, operational).
  Added boundary table vs security-review — counter-review owns creative adversarial thinking, security-review owns checklist/pattern compliance.
  Finding template extended with Attack Chain format (entry point, path, prerequisites, likelihood) and Scenario format (assumption challenged, current behavior, verdict).
  3 reference files follow security-review's progressive disclosure pattern.
decisions:
  - Counter-review absorbs red-team functionality (no separate red-team skill)
  - Clear boundary: security-review = known patterns/checklists, counter-review = creative adversarial thinking
  - Attack chains are counter-review's unique capability — chaining findings across lenses
handoff_to: CLAUDE
next_actions: Update description (currently >150 chars — needs trim per todo #1)
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-190000-CLAUDE
timestamp_utc: 2026-03-12T19:00:00Z
author: CLAUDE
activity_type: BUG_FIX
work_scope: Fix stale "output file" references in 5 review lens skills + meta-review description
files_touched: skills/counter-review/SKILL.md, skills/completeness-review/SKILL.md, skills/refactor-review/SKILL.md, skills/compliance-review/SKILL.md, skills/drift-review/SKILL.md, skills/meta-review/SKILL.md
summary: |
  1. Fixed 5 lens skills that still said "Write findings to the output file" despite Outputs section correctly using db_upsert. Changed to "Format each finding using this structure (store via db_upsert as shown in Outputs above)". security-review and test-review were already clean.
  2. Fixed meta-review description: "8 lenses" → "7 lenses". The 8th was never wired in.
  3. Discovered skills/ui-design/ — directory scaffolded (Mar 11 23:16) but SKILL.md never written. Empty references/ dir only. Not wired into meta-review or meta-research.
decisions:
  - Only review-synthesis.md stays on disk as a file. All lens findings go to artifact DB only.
risks_or_gaps: ui-design skill needs to be written and wired into meta-review as 8th lens (user confirmed this was intended)
handoff_to: CLAUDE
next_actions: Write ui-design SKILL.md, wire as 8th lens in meta-review
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-150000-CLAUDE
timestamp_utc: 2026-03-12T15:00:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Vibe skill overhaul, context estimation removal, github-pull skill, CLI dedup rule
files_touched: skills/vibe/SKILL.md, skills/meta-execute/SKILL.md, rules/general.md, hooks/stop-check.sh, skills/meta-context-save/SKILL.md, skills/project-scaffold/templates/claude-md-template.md, skills/github-pull/SKILL.md
summary: |
  1. Removed context window estimation from stop hook, meta-context-save, and claude-md-template. Context save is now manual-only via /meta-context-save.
  2. Created /github-pull skill (git fetch --prune + git pull --ff-only, --rebase/--stash options).
  3. Full rewrite of /vibe skill — old syntax was 100% wrong (--headless, --no-prompt, generate/review subcommands don't exist). Correct: `-p "PROMPT" --output text --max-turns N`. Verified against --help, live testing, official Mistral docs.
  4. Removed duplicated CLI syntax from meta-execute and general.md — driver skills are now single source of truth. Saved feedback memory for this rule.
decisions:
  - Driver skills (/vibe, /codex, /gemini, /copilot, /cursor) are the ONLY place CLI syntax lives. Consuming skills say "load /vibe for syntax" instead of inlining commands.
  - 9 other consuming skills still have duplicated CLI syntax — needs future sweep.

---CLAUDE--------------------
note_id: CN-20260313-120000-CLAUDE
timestamp_utc: 2026-03-13T12:00:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: SAST pre-scan integration into meta-review (todo #4b)
files_touched: skills/meta-review/SKILL.md, todo.md
files_reviewed: skills/meta-review/SKILL.md
summary: Added Phase 1.5 "SAST Pre-Scan" to meta-review. Claude main thread calls Semgrep MCP, SonarQube MCP, and local CLIs (ruff/biome/oxlint/gitleaks) before LLM reviews. Results injected into all lens prompts.
details:
  - Phase 1.5 has 4 parallel steps: Semgrep MCP scan_directory, SonarQube search_sonar_issues (if project exists), local CLIs (language-detected), gitleaks secrets scan
  - $SAST_SUMMARY assembled and truncated to ~5000 chars (HIGH/BLOCKER/CRITICAL only)
  - All 3 dispatch sections (Sonnet, Codex, Gemini) updated to include SAST context
  - Sonnet subagents now cross-reference SAST findings (confirm/dispute/expand)
  - Synthesis template updated with SAST Findings section (machine-verified, not LLM opinion)
  - Architecture diagram updated to show pre-scan flow
  - Graceful degradation: if ALL tools unavailable, LLM reviews still run
  - SonarQube query only runs if project already exists — does NOT create projects or run sonar-scanner
  - Updated Step 2: SonarQube now auto-creates project + runs sonar-scanner if no project exists (derives key from folder name)
  - Requires JDK 21 (already installed via Homebrew), token from Vault services/sonarqube or $SONARQUBE_TOKEN env var
  - Graceful skip if JDK missing or SonarQube unreachable
validation: structural review of SKILL.md edits — needs real /meta-review run to validate end-to-end
risks_or_gaps: Not tested on a real project yet; SAST summary truncation at 5000 chars may lose findings on large codebases; sonar-scanner adds ~60s to Phase 1.5
handoff_to: CLAUDE
next_actions: Run /meta-review on Arbytr to validate Phase 1.5 end-to-end
------------------------------

---CLAUDE--------------------
note_id: CN-20260313-110000-CLAUDE
timestamp_utc: 2026-03-13T11:00:00Z
author: CLAUDE
activity_type: SETUP
work_scope: SonarQube MCP verification + first full project scan
files_touched: ~/.mcp.json, todo.md
files_reviewed: Arbytr project (369 files indexed, 156 TS/JS analyzed)
summary: Confirmed SonarQube MCP Docker swap working. Ran first full scan on Arbytr project — 36.9k LOC, quality gate PASSED, 27 bugs, 517 code smells, 32 security hotspots, 0 vulnerabilities.
details:
  - MCP connection verified: `search_my_sonarqube_projects` returned empty (fresh install) — confirmed live
  - `analyze_code_snippet` tested on extension.ts — returned 5 issues (works without projectKey for local analysis)
  - Created `arbytr` project via SonarQube API (`/api/projects/create`)
  - JDK 21 already installed via Homebrew but not on PATH — used `JAVA_HOME` export to enable sonar-scanner
  - Full scan via `npx sonar-scanner` — 369 files, 8 languages detected, 62s total
  - 1 BLOCKER: infinite loop in `poll-history.mjs:214` (`stopped` not modified)
  - 35 CRITICAL cognitive complexity violations (worst: `config.ts:165` at 120, limit is 15)
  - `ChatPanelProvider.ts:83` complexity 70, `StatusPage.tsx:119` complexity 44
  - `agora-core/src/types.ts` has 11 functions over complexity limit
  - GUI accessible at http://tower:9000/dashboard?id=arbytr via Tailscale
  - Todo #4a updated to reflect Docker swap + verification
validation: Quality gate PASSED, all MCP tools functional, scan results visible in GUI
risks_or_gaps: 0% test coverage reported (no lcov configured); security hotspots need manual triage
handoff_to: CLAUDE
next_actions: Triage 32 security hotspots; configure test coverage reporting; wire SonarQube into meta-review Phase 1 (todo #4b)
------------------------------

---CLAUDE--------------------
note_id: CN-20260313-100000-CLAUDE
timestamp_utc: 2026-03-13T10:00:00Z
author: CLAUDE
activity_type: SETUP
work_scope: SonarQube MCP wiring (in progress)
files_touched: none yet
files_reviewed: ~/.mcp.json, cnotes.md
summary: Verified all 5 local SAST tools installed. Researched SonarQube MCP server (official Docker image mcp/sonarqube). Waiting on user's SonarQube token to complete wiring.
details:
  - Tower Tailscale address: http://tower:9000 (SonarQube)
  - User plans to expose SonarQube GUI through Cloudflare
  - MCP server will connect via Tailscale directly (not Cloudflare)
  - Official Docker image: mcp/sonarqube (Java/Gradle, JDK 21+)
  - Env vars needed: SONARQUBE_TOKEN (user token), SONARQUBE_URL, STORAGE_PATH
  - Default SonarQube creds: admin/admin (forces change on first login)
  - Flagged: ~/.mcp.json has GitHub PAT + GitLab token in plaintext (todo #15)
  - SonarQube container confirmed running on tower (since 2026-03-11, sonarqube:community v26.3.0, traefik_proxy network, no Traefik labels = no web exposure)
  - Tower Tailscale IP: 100.127.173.50 (tower.elk-bangus.ts.net), 68ms from Mac
  - SonarQube does NOT need public web exposure for MCP — Tailscale IP sufficient
  - Docker Desktop NOT running on this Mac — can't run mcp/sonarqube Docker image until started
  - No Vault recipe exists yet at services/sonarqube (404)
  - Options presented: A) Docker Desktop, B) JDK build, C) tower-side (rejected). No JDK or Docker — used npm package instead
  - npm package `sonarqube-mcp-server` (deprecated but functional) works as stdio MCP server
  - Added to ~/.mcp.json with SONARQUBE_BASE_URL=http://100.127.173.50:9000
  - Token stored in Vault at services/sonarqube (v1)
  - Needs Claude Code restart to pick up new MCP server
validation: All 5 tools confirmed installed; npm MCP server tested (starts without errors); Vault store confirmed (v1)
  - User started Docker Desktop — swapped npm package for official mcp/sonarqube Docker image
  - Docker 29.1.3 confirmed running, image pulled successfully
risks_or_gaps: Need to test actual SonarQube queries after Claude Code restart
handoff_to: CLAUDE
next_actions: Restart Claude Code → verify sonarqube tools appear → test a query → wire into meta-review Phase 1
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-162434-CLAUDE
timestamp_utc: 2026-03-12T16:24:34Z
author: CLAUDE
activity_type: CODE_REVIEW
work_scope: Design meta-execute multi-model pipeline (Vibe + Cursor + Codex)
files_touched: none (design phase)
files_reviewed: meta-execute/SKILL.md, vibe/SKILL.md, cursor/SKILL.md, copilot/SKILL.md
summary: Agreed on cross-model Best-of-N generation + 5-reviewer panel for meta-execute
details:
  - Generation: 1 Vibe + 1 Cursor per WU (cross-model Best-of-2), 2 WUs at a time (conservative start)
  - Review panel (5 per WU, 2 WUs concurrent): Codex (fixes), Sonnet (rubric), Cursor --mode ask, Copilot, Gemini
  - Codex role shifts from coder to editor+reviewer — reads Vibe/Cursor output, reviews against rubric, applies fixes
  - Staggered pipeline (option B) to keep Cursor at ≤3 concurrent
  - Synthesis: 3/5 ACCEPT → merge; any REJECT → Codex fixes informed by all 5; disagreement → Claude synthesizes
  - Pending: implementation into meta-execute SKILL.md, worker.md, reviewer.md
validation: not run (design only)
risks_or_gaps: Vibe/Cursor output quality unknown until first real run; conservative 2+2 limits may need adjustment
handoff_to: CLAUDE
next_actions: Implement pipeline into meta-execute upon user approval
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-154500-CLAUDE
timestamp_utc: 2026-03-12T15:45:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Add Copilot as Gemini fallback + fix concurrency limits
files_touched: general.md, cross-cutting-rules.md, copilot/SKILL.md, gemini/SKILL.md, meta-review/SKILL.md, research-execute/SKILL.md, meta-production/SKILL.md, release-prep/SKILL.md, project-questions/SKILL.md, build-plan/SKILL.md, meta-deep-research-execute/SKILL.md
files_reviewed: All 13 skills referencing Gemini
summary: Copilot is now Gemini's primary fallback across all skills. Concurrency fixed 3→2.
details:
  - Fallback chain everywhere: Gemini → Copilot → WebSearch/skip (8 skill files updated)
  - Copilot concurrency 3→2 in general.md, cross-cutting-rules.md, copilot/SKILL.md
  - New CLI landscape: Gemini (free), Codex ($20/mo), Copilot (premium requests), Cursor (Pro+ student free)
validation: grep scan confirmed all Gemini call sites now have Copilot fallback
risks_or_gaps: Copilot/Cursor not yet tested in subagent/background shells — may need path fixes like Codex/Gemini needed
handoff_to: none
next_actions: Test Copilot fallback in real meta-review run; verify Cursor Agent CLI path
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-153000-CLAUDE
timestamp_utc: 2026-03-12T15:30:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Fix infinite skill loop in Cursor IDE
files_touched: skills/todo-features/SKILL.md, skills/github-sync/SKILL.md, skills/evolve/SKILL.md, references/cross-cutting-rules.md
files_reviewed: All 39 skill SKILL.md frontmatter blocks
summary: Diagnosed and fixed infinite loop caused by 3 skill descriptions acting as always-on rules + cross-cutting-rules amplifying them
details:
  - Root cause: todo-features ("Runs after completing work"), github-sync ("Applies whenever uncommitted changes"), evolve ("project changed") — these descriptions read as standing instructions, not slash-command triggers
  - cross-cutting-rules forced every skill to update todo.md/features.md on completion, re-triggering the chain
  - Fix: rewrote all 3 descriptions to require explicit /slash-command invocation
  - Fix: cross-cutting-rules now says "mention changes in response" instead of "update files directly"
validation: Grep scan of all SKILL.md descriptions confirmed no other always-on trigger language remains
risks_or_gaps: Skills that explicitly call /github-sync or /todo-features as steps (meta-execute, review-fix, meta-context-save) still work — those are intentional inline calls, not description-driven auto-triggers
handoff_to: none
next_actions: Test in Cursor to confirm loop is broken; related to todo #1 (trim descriptions ≤150 chars)
------------------------------

### CN-20260312-093000-CLAUDE
- Moved repo from iCloud (`~/Library/Mobile Documents/.../Shared/claude`) → `/Users/byrum_work/Projects/claude`
- Reason: iCloud kept corrupting `.git/index` (all files showed as D + ?? on session start)
- Fixed git index corruption via `git reset` before the move
- Repointed 4 symlinks in `~/.claude/`: agents, hooks, rules, skills → new location
- Migrated project config + memory to `~/.claude/projects/-Users-byrum-work-Projects-claude/`
- GitHub remote unchanged: `trevorbyrum/claude-skills-suite`
- Old iCloud copy still exists — user should delete after confirming new location works

### CN-20260311-221000-CLAUDE
- Pushed to GitHub: 435099f (27 files, +5513 lines)
- Semgrep MCP added to ~/.mcp.json (local, no API cost)
- Handoff stored in qdrant memory for home Claude pickup
- Remaining for next session: SonarQube MCP connection (needs tower IP + token), meta-review SAST integration, pre-commit hook test

### CN-20260311-220000-CLAUDE
- Installed 5 local tools: ruff 0.15.5, semgrep 1.154.0, gitleaks 8.30.0, biome 2.4.6, oxlint 1.53.0
- Deployed SonarQube Community Edition on Unraid (container: sonarqube, port 9000, no web exposure)
- Recipe stored in Vault for redeployment
- Rewrote pre-commit hook: 3-phase (Gitleaks → Ruff/Biome/oxlint → Codex)

### CN-20260311-213500-CLAUDE
- Deep research 005D (free tools augmentation) completed — 66 queries, ~654 scanned, ~256 cited
- 10 sub-questions: static analysis, MCP servers, bug detection, testing, drift, security, emerging tools, observability, underutilized MCPs, tool pipelines
- 6 verified: Rust tools 10-100x faster, Hypothesis PBT 50x mutations, dual secret scanners, slopsquatting real, LLM+SAST hybrid 85-98% FP reduction
- 3 contested: "more tools = fewer bugs" (curated yes, uncurated no), MCP ecosystem maturity (vendor OK, community risky), ty replacing mypy (too early)
- 5 emergent topics: Rust tool revolution, SARIF unification, slopsquatting, LLM+SA hybrid, danger.js
- Underutilized existing MCPs: n8n, qdrant-memory, lmstudio, neo4j-plc, Playwright
- New MCP servers: SonarQube MCP (official), Semgrep MCP (official)
- Summary at: artifacts/research/summary/005D-free-tools-augmentation.md
- Next: user decides which tools/integrations to pursue

### CN-20260311-190000-CLAUDE
- Configured global permissions in ~/.claude/settings.json: Bash(*), Read(*), Write(*), Edit(*), Glob(*), Grep(*), WebFetch(*), WebSearch, mcp__* all auto-approved
- Deny list empty — no silent blocks. Claude's own guardrails + general.md rules handle safety
- Added availableModels: ["opus", "sonnet", "haiku"]
- Wiped project settings.local.json (160 lines of one-off approvals → empty)
- Wiped project settings.json allow list (3 MCP tools → empty, global handles it)
- User was frustrated with click-yes-all-day permission model. This fixes it permanently.

### CN-20260311-180000-CLAUDE
- Applied 004D research to meta-production skill: 10→12 dimensions, 4 reference files
- New dims: 11 Reliability (SLO/SLI, error budgets, chaos readiness), 12 Capacity (load tests, auto-scaling, capacity model)
- Service criticality tiers (Critical/Standard/Low) weight Dims 11-12 — batch jobs aren't penalized for missing SLOs
- Expanded Dim 8: +SLI-based alerting, trace sampling, cardinality control, correlation IDs, cost-aware observability
- Expanded Dim 9: +progressive delivery, supply chain security (SLSA, SBOM, cosign), network policies, secrets rotation
- Expanded Dim 10: +incident maturity model, on-call health metrics, DORA measurement infrastructure (validate infra not scores)
- Scoring: /120 total, thresholds at 85%/70%/50%. Chaos = maturity indicator, not hard gate. DORA = infrastructure check, not fixed tiers
- New files: references/reliability-capacity-prompts.md, references/slo-chaos-dora-checks.md
- Updated files: SKILL.md, references/production-scan-prompts.md, references/report-template.md
- 6 contested findings resolved per user approval (12 dims, validate infra, maturity indicator, tier weighting, tool-agnostic, automation+human)

### CN-20260311-170000-CLAUDE
- Deep research 004D (meta-production upgrade) completed — 35 queries, 580+ scanned, 127 cited
- 11 sub-questions researched: SLO/SLI, chaos engineering, DORA metrics, deployment patterns, on-call readiness, observability gaps, security hardening, capacity planning, compliance, PRR framework comparison, dimension restructuring
- 2 debunked: DORA Elite thresholds as gates (methodology changed), 10 dims cover everything (3 gaps found)
- 6 contested findings awaiting user decision (12 vs 10 dims, chaos as hard gate, SLO universality, etc.)
- 3 emergent topics: continuous PRR, modern incident platforms (incident.io/Rootly), Tetragon as Falco alt
- Codex + Gemini unavailable during run (Bash permission denials) — 580 vs 1000 target scanned
- Summary at: artifacts/research/summary/004D-meta-production-upgrade.md
- Next: apply findings to upgrade meta-production SKILL.md + references

### CN-20260311-160000-CLAUDE
- Applied 003D research to test-review skill: SKILL.md 170→273 lines, 6 new reference files
- Matched security-review progressive disclosure structure (SKILL.md scannable, detail in references/)
- 3 existing checks refined: mock overuse (scope to SUT-owned types), fragile tests (+datetime/network/filesystem), error paths (+exception hierarchy/timeout/batch)
- 6 new sections: mutation testing adequacy, PBT assessment, contract testing, coverage gaps (CC/CRAP), strategy shapes, LLM anti-patterns
- Raw research agent dumps moved from references/ to artifacts/research/003D/
- features.md updated: test-review upgrade → done

### CN-20260311-150000-CLAUDE
- Deep research 003D (test-review upgrade) completed — 60+ queries, 45+ cited sources
- All 8 current skill categories validated against Google SWE Book, Meta ACH, ISO 29119
- 3 existing checks need refinement: mock overuse, fragile tests, error paths
- 6 new sections identified: mutation testing (P0), CC thresholds (P0), PBT (P1), contract testing (P1), strategy shapes (P1), LLM anti-patterns (P2)
- Key insight: mutation testing is ground truth — AI tests hit 100% coverage / 4% mutation score
- Summary at: artifacts/research/summary/003D-test-review-upgrade.md
- Next: apply findings to upgrade SKILL.md + create reference files

### CN-20260311-140000-CLAUDE
- Pushed skill suite to GitHub: https://github.com/trevorbyrum/claude-skills-suite
- Initialized git repo from iCloud shared directory (was not previously a git repo)
- Force-pushed over stale remote commit (`e404487`) with current local state
- Git identity set to `Trevor Byrum <tbyrum@8-bit-byrum.com>` (repo-local, not global)
- `.gitignore` excludes: `.claude/`, `artifacts/project.db`, `compact/`, `.DS_Store`
- No GitHub credentials in Vault — using `gh` CLI auth (keyring-based, `trevorbyrum` account)
