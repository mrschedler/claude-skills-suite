---
name: claude-deep-research
description: "Deep research using only Claude subagents with adversarial steelman debate. No external CLIs required. Triggers on deep research, exhaustive research, leave no stone unturned."
---

# claude-deep-research

Dispatcher. Clarify → validate → write prompt → dispatch Opus → present results.

## Step 1: Clarify

Ask 3-5 questions. Required:
- What exactly do you need to know? (restate precisely)
- What decision will this inform?
- Scope: narrow/focused/broad/exhaustive?

If relevant:
- Constraints, biases, assumptions to challenge?
- Time sensitivity? Specific domains?
- Prior research? (check `artifacts/research/`)

## Step 2: Read Context

Read GROUNDING.md then project-context.md if they exist. Compress to essentials.

## Step 3: Validate Prerequisites

```bash
export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
command -v sqlite3 >/dev/null 2>&1 || { echo "FAIL: sqlite3 not in PATH"; exit 1; }
```

If no `artifacts/db.sh`:
```bash
mkdir -p artifacts
cp /c/dev/claude-skills-suite/artifacts/db.sh artifacts/db.sh
```

Init:
```bash
export PROJECT_DB="$(pwd)/artifacts/project.db"
source artifacts/db.sh && db_init
```

## Step 4: Folder Number

Check `artifacts/research/` for existing folders. Both regular (`001`) and deep
(`001D`) share one sequence. Highest number + 1, append `D`.

## Step 5: Create Folders

```
artifacts/research/summary/    ← create if missing
artifacts/research/{NNN}D/     ← this run
```

## Step 6: Write Prompt

Write `artifacts/research/{NNN}D/deep_research_prompt.md` (max 200 lines):

```markdown
# Deep Research Prompt — {NNN}D
## Research Question
[precise question]
## Sub-Questions
[5-10 numbered]
## Scope
- Breadth: [narrow|focused|broad|exhaustive]
- Time: [recent only|include historical]
- Domains: [constraints]
## Project Context
[compressed — skip if no project]
## Known Prior Research
[existing folders or "none"]
## Output Configuration
- Folder: artifacts/research/{NNN}D/
- Summary: artifacts/research/summary/{NNN}D-{topic-slug}.md
## Special Instructions
[user constraints, biases to challenge]
```

## Step 7: Dispatch

One Opus subagent:

```
Execute the Claude deep research protocol.

1. Read: [path to skills/claude-deep-research-execute/SKILL.md]
2. Read: [path to skills/claude-deep-research-execute/references/protocol-detail.md]
3. Read: artifacts/research/{NNN}D/deep_research_prompt.md
4. DB setup:
   export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
   export PROJECT_DB="[absolute project path]/artifacts/project.db"
5. Summary to: artifacts/research/summary/{NNN}D-{topic-slug}.md
6. Return ONLY: summary path, source tally, claim counts, contested findings.
```

## Step 8: Present

Read summary. Show executive summary, confidence map, source counts.
Highlight CONTESTED and DEBUNKED findings.

```
Deep research complete. {N} sources scanned | {N} cited across {N} connectors.
{N} verified, {N} contested, {N} uncertain.

1. Dive deeper — re-run on contested findings
2. Narrow focus — deep-dive a sub-question
3. Apply findings — /build-plan or /evolve
4. Done
```

## Errors

- Subagent fails → read intermediate files, present partial findings
- No GROUNDING.md/project-context.md → proceed without
- No artifacts/research/ → create it

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
