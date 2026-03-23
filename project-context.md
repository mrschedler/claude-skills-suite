# Project Context

## Overview

**Claude Skills Suite** — a production skill suite for Claude Code that orchestrates multi-model development workflows. 42+ skills, 10 specialized agents, 7 lifecycle hooks. Designed for projects where AI writes, reviews, and ships code with human oversight at every gate.

## Architecture

- **Meta-skills (6)**: Orchestrators that chain atomic skills + models (meta-init, meta-execute, meta-review, meta-research, meta-deep-research, meta-production)
- **Atomic skills (21)**: scaffold, plan, research, build, sync, release, evolve, etc.
- **Review lenses (8+)**: security, test, counter, drift, refactor, completeness, compliance, browser
- **Driver skills (5)**: codex, gemini, vibe, cursor, copilot — CLI syntax & path discovery
- **Infrastructure**: hooks, agents, artifact DB (SQLite+FTS5), cross-cutting rules

## Tech Stack

- Claude Code CLI (orchestrator)
- External AI CLIs: Codex (OpenAI), Gemini (Google), Cursor, Copilot (GitHub), Vibe (Mistral)
- Shell scripts (bash), SQLite+FTS5 for artifacts, Git/GitHub for VCS
- Homelab: Unraid tower, Docker, Traefik, Vault, Mattermost, GitLab CE

## Key Patterns

- **Progressive disclosure**: metadata (always) -> SKILL.md body (on trigger) -> bundled references (on demand)
- **Subagent delegation**: meta-skills spawn subagents for heavy work, main thread orchestrates
- **Artifact DB**: `artifacts/project.db` via `artifacts/db.sh` helper functions
- **Cross-cutting rules**: `references/cross-cutting-rules.md` applied by all skills
- **Driver skill boundary**: consuming skills reference driver skills, never embed CLI details

## Constraints

- Codex max 5 concurrent, Vibe max 3, Cursor max 3, Gemini max 2, Copilot max 2
- No hardcoded secrets — Vault for credentials, env vars with empty-string fallbacks
- Context-minimal design for meta-skills — heavy work in subagents
- All skill output under `artifacts/` in project roots

## Owner

Trevor Byrum (tbyrum) — solo developer, data scientist background, deep Go expertise, building AI-assisted development tooling
