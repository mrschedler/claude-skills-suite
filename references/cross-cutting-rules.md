# Cross-Cutting Rules

These rules apply to every skill in the suite. Every atomic SKILL.md must follow them before completing.

## Rules

1. **Follow coterie.md** — Check and respect coterie rules in the project root. If `coterie.md` does not exist, create it from the coterie template before proceeding.

2. **Log to cnotes.md** — Notable decisions, context changes, and rationale. If `cnotes.md` does not exist, create it with the header `# Collaboration Notes` and `## Notes (Newest First)` before logging. This is also enforced by the Stop hook, but skills should do this proactively.

3. **Note todo/feature changes** — If you discover new action items or feature changes, mention them in your response so the user can run `/todo-features` if needed. Do NOT auto-invoke todo-features or update those files directly.

4. *(Merged into rule 3 above)*

5. **CLI concurrency limits (MANDATORY)** — Never exceed these simultaneous process counts:
   - **Codex**: max **5** concurrent `codex exec` processes
   - **Vibe (Mistral)**: max **3** concurrent `vibe` processes
   - **Cursor**: max **3** concurrent `agent` processes
   - **Gemini**: max **2** concurrent `gemini` processes
   - **Copilot**: max **2** concurrent `copilot -p` processes
   - If a skill needs more, queue excess and launch as slots free up. Do NOT launch all at once.
   - These limits come from `general.md` and override any per-skill instructions.

6. **Driver skill boundary (MANDATORY)** — Any skill that dispatches Gemini, Codex, Copilot, Cursor, or Vibe must reference the corresponding driver skill instead of embedding CLI details locally.
   - Consuming skills may specify task type, prompt template, output path, concurrency, and fallback behavior.
   - Consuming skills must NOT inline CLI commands, flags, auth/path setup, timeout syntax, model-selection syntax, or gotcha lists for those agents.
   - If invocation details change, update the driver skill only.
   - For Vibe, keep prompts narrowly scoped to named files/directories or a single work unit with explicit deliverables. Never ask it to scope the whole project first.

7. **Homelab Tools memory sync (MANDATORY)** — Keep Qdrant memory current so home Claude stays informed across projects and sessions. Use `mcp__claude_ai_Homelab_Tools__memory_call` with `tool: 'store_memory'`.
   - **After `/meta-execute` completion**: Store execution summary (units completed/failed/blocked, retry counts, confidence scores, wave count). Tags: `meta-execute`, `execution-summary`, `{project-name}`.
   - **After `/github-sync` push**: Diff what was pushed against what memory already knows (search first, then store the delta). Include: commit hash, branch, files changed summary, commit message. Tags: `github-sync`, `commit-log`, `{project-name}`.
   - **After `/research-execute` or `/meta-deep-research-execute` synthesis**: Store the executive summary + source tally + key findings. Tags: `research`, `{NNN}` or `{NNN}D`, `{project-name}`.
   - **Format**: `{ "tool": "store_memory", "args": { "content": "<summary>", "metadata": { "tags": [...], "skill": "<skill-name>", "project": "<project-name>" } } }`
   - **Dedup rule**: Before storing, search memory with the skill name + project name. If a recent entry (same skill, same project, <24h) exists, update it instead of creating a duplicate.

## Structured Note Schema

Every note in `cnotes.md` uses this format. Insert newest first (top insertion below `## Notes (Newest First)`). Once a newer note exists above yours, your note is locked — do not modify it.

### Delimiter Format

Each agent uses its own delimiter:
```
---CLAUDE--------------------
[note body]
------------------------------

---CODEX---------------------
[note body]
-------------------------------

---GEMINI-------------------
[note body]
------------------------------

---COPILOT------------------
[note body]
------------------------------
```

### Required Fields (all 13)

1. `note_id`: `CN-YYYYMMDD-HHMMSS-AUTHOR` (e.g., `CN-20260306-143022-CLAUDE`)
2. `timestamp_utc`: ISO-8601 UTC
3. `author`: `CLAUDE`, `CODEX`, `GEMINI`, or `COPILOT`
4. `activity_type`: `CODE_WRITE` or `CODE_REVIEW`
5. `work_scope`: Short statement of task intent
6. `files_touched`: Files edited (or `none`)
7. `files_reviewed`: Files reviewed (or `none`)
8. `summary`: Concise outcome summary
9. `details`: Specific changes or findings
10. `validation`: Tests/checks executed (or `not run`)
11. `risks_or_gaps`: Known risks, assumptions, or unresolved items
12. `handoff_to`: `CODEX`, `CLAUDE`, `GEMINI`, `COPILOT`, or `none`
13. `next_actions`: Immediate follow-up steps
