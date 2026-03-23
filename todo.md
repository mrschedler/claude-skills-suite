# Todo

> Current action items. Updated by all agents as work progresses.
> Source: deep-research-skill-audit.md (2026-03-07), MEMORY.md priorities

## P0 — Do First

| # | Task | Owner | Status | Added | Notes |
|---|------|-------|--------|-------|-------|
| 1 | Trim all skill descriptions to ≤150 chars | claude | open | 2026-03-07 | Prevent silent skill exclusion from description budget |
| 2 | Make 7 review skills thin wrappers with shared logic | claude | open | 2026-03-07 | Reduce duplication; shared output format, severity, dispatch |
| 2a | Troubleshoot Codex/Gemini in subagents | claude | open | 2026-03-11 | Codex: likely stale CLI templates (prompt-before-flags, bare `timeout`, outdated `app server` assumption), not a missing daemon. Gemini: still timing out in subagents. Both worked interactively but fail in background/subagent shells. |
| 2b | Add project docs (cnotes, features, todo) to meta-init scaffold | claude | open | 2026-03-11 | meta-init should create these files during project init |
| 2c | Auto-update Homelab Tools memory after github-sync, meta-execute, and research | claude | done | 2026-03-11 | Cross-cutting rule 7 added. Inline steps in github-sync, meta-execute, research-execute, meta-deep-research-execute. |

## P1 — High Impact

| # | Task | Owner | Status | Added | Notes |
|---|------|-------|--------|-------|-------|
| 3 | Deep research: test-review skill upgrade | claude | done | 2026-03-11 | 003D complete — 45+ sources, 6 gaps found. Apply next. |
| 4 | Deep research: meta-production skill upgrade | claude | done | 2026-03-11 | 004D complete — 127 cited, 11 sub-questions, 6 contested. Apply next. |
| 4a | Connect SonarQube MCP | claude | done | 2026-03-11 | Swapped npm→official Docker image `mcp/sonarqube`. Connection verified (0 projects, fresh install). Token in Vault services/sonarqube. |
| 4b | Update meta-review Phase 1 with SAST integration | claude | done | 2026-03-11 | Phase 1.5 added: Semgrep MCP + SonarQube MCP + local CLIs (ruff/biome/oxlint/gitleaks). Results injected into all lens prompts. |
| 4c | meta-execute multi-model pipeline | claude | done | 2026-03-12 | Cross-model Best-of-2 (Vibe+Cursor) + 5-reviewer panel (Codex+Sonnet+Cursor+Copilot+Gemini). Needs real-project validation. |
| 4d | Validate Vibe/Cursor limits on real project | claude | open | 2026-03-12 | Running at conservative 2+2; may raise to 3+3 after testing |
| 4e | Write ui-design SKILL.md + wire as 8th lens in meta-review | claude | open | 2026-03-12 | Directory scaffolded (Mar 11) but SKILL.md never written. User confirmed it was intended. |
| 5 | Add fresh-findings reuse to all review skills | claude | open | 2026-03-07 | Stop duplicate scans (<24h check) |
| 6 | Add Gemini to project-questions | claude | open | 2026-03-07 | Domain/competitor research before interview |
| 7 | Add Opus subagent for meta-review synthesis | claude | open | 2026-03-07 | Better cross-lens pattern detection |

## P2 — Medium Impact

| # | Task | Owner | Status | Added | Notes |
|---|------|-------|--------|-------|-------|
| 8 | Add Codex to build-plan (skeleton generation) | claude | open | 2026-03-07 | Generate interfaces/types/stubs alongside plan |
| 9 | Add `--quick` mode to meta-join | claude | open | 2026-03-07 | Fast catch-ups without full 7-step onboard |
| 10 | Add timeout guards to meta-skill chains | claude | open | 2026-03-07 | Prevent infinite stalls on hung subagents |
| 11 | Add README.md to GitHub repo | tbyrum | open | 2026-03-11 | Public repo needs docs for external users |

## P3 — Nice to Have

| # | Task | Owner | Status | Added | Notes |
|---|------|-------|--------|-------|-------|
| 12 | Add Gemini to release-prep and meta-production | claude | open | 2026-03-07 | Competitive context, marketing copy |
| 13 | Add Codex to drift-review | claude | open | 2026-03-07 | Find undocumented code features |
| 14 | Skill description optimization via skill-creator `run_loop.py` | tbyrum | blocked | 2026-03-11 | Needs skill-creator from Claude Teams |
| 15 | Store GitHub credentials in Vault (`services/github`) | tbyrum | open | 2026-03-11 | Currently using `gh` keyring auth only |

## Missing Skills (from audit §10)

| # | Skill | Status | Added | Notes |
|---|-------|--------|-------|-------|
| 16 | Dependency audit automation | planned | 2026-03-07 | Scheduled npm/cargo audit with Mattermost alerts |
| 17 | Performance profiling | planned | 2026-03-07 | CPU/memory, flame graphs, bottleneck ID |
| 18 | Documentation audit | planned | 2026-03-07 | Verify README/API/arch docs current vs code |
| 19 | Accessibility review (a11y) | planned | 2026-03-07 | WCAG, keyboard nav, screen reader for UI projects |
| 20 | Load/stress testing | planned | 2026-03-07 | Benchmarks under simulated load, capacity planning |
| 21 | Breaking change detection | planned | 2026-03-07 | Diff versions for API contract, DB schema, imports |
| 22 | Incident postmortem | planned | 2026-03-07 | Structured capture: timeline, root cause, prevention |
