---
name: claude-light-research
description: "Lightweight research with artifact DB storage. Claude researches naturally using available tools — no subagent fan-out, no adversarial debate. Use for everyday research, quick investigations, and building evidence for decisions."
---

# claude-light-research

Research the way Claude normally would, but with structure and receipts.
No subagents. No debate rounds. Just research → store → synthesize.

## When to use

- Everyday research questions
- "Research this for me", "look into X", "what are the options for Y"
- Building evidence before a decision
- Investigating a technology, pattern, or approach

When the user says "deep research", "exhaustive", or "leave no stone unturned"
→ use `/claude-deep-research` instead.

## Step 1: Understand

Read the question. If unclear, ask 1-2 clarifying questions — no more.

If GROUNDING.md exists, read it for project context.

## Step 2: Set Up Artifact DB

```bash
export PATH="/c/Users/matts/AppData/Local/Microsoft/WinGet/Packages/SQLite.SQLite_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
command -v sqlite3 >/dev/null 2>&1 || { echo "WARN: sqlite3 not in PATH — findings stored in files only"; }
```

If no `artifacts/db.sh`:
```bash
mkdir -p artifacts
cp /c/dev/claude-skills-suite/artifacts/db.sh artifacts/db.sh 2>/dev/null || true
```

Init (skip gracefully if sqlite3 unavailable):
```bash
export PROJECT_DB="$(pwd)/artifacts/project.db"
source artifacts/db.sh && db_init 2>/dev/null || true
```

## Step 3: Folder Number

Check `artifacts/research/` for existing folders. Regular (`001`) and deep
(`001D`) share one sequence. Use highest + 1, append `L`.

```
artifacts/research/summary/    ← create if missing
artifacts/research/{NNN}L/     ← this run
```

## Step 4: Research

Use whatever tools make sense for the question:

- **WebSearch** — general queries, recent developments
- **MCP connectors** — if available and relevant (context7 for library docs,
  github for repos, etc.)
- **WebFetch** — specific URLs, documentation pages
- **Read** — local files, prior research in `artifacts/research/`

Work through the question naturally. No prescribed connector list — use
judgment. Follow threads that look promising. Skip what's irrelevant.

**As you find things, store to artifact DB:**

```bash
source artifacts/db.sh
db_store "claude-light-research" "finding" "{NNN}L/{short-label}" \
  "$(cat <<'FINDING'
[finding content — self-contained, includes source URL/reference]
FINDING
)"
```

If sqlite3 isn't available, write findings to `artifacts/research/{NNN}L/findings.md`
as an append-only log instead.

## Step 5: Synthesize

When you have enough to answer the question, write the summary:

**File:** `artifacts/research/summary/{NNN}L-{topic-slug}.md`

```markdown
# {Topic} — Research Summary

**Date:** {YYYY-MM-DD}
**Scope:** {one line}
**Sources consulted:** {count}

## Key Findings

[Numbered findings, each with source attribution]

## Recommendation

[If the research was meant to inform a decision — state it clearly]

## Sources

[Numbered list of all sources consulted]
```

**Store summary to artifact DB:**

```bash
db_store "claude-light-research" "summary" "{NNN}L/{topic-slug}" \
  "[one-paragraph summary of findings and recommendation]"
```

## Step 6: Memory Sync

If the findings are worth remembering across sessions, store to Qdrant:

```
memory_call > store
  content: [self-contained summary with key findings and reasoning]
  tags: research, {topic-tags}, {project-name}
  category: {project-slug or "general"}
```

Skip if findings are ephemeral or project-specific with no future value.

## Step 7: Present

```
Research complete. {N} sources consulted.

[Executive summary — 3-5 sentences]

Summary: artifacts/research/summary/{NNN}L-{topic-slug}.md

1. Go deeper — /claude-deep-research on this topic
2. Apply findings — /build-plan or /evolve
3. Done
```

## Errors

- No sqlite3 → fall back to file-based findings log (Step 4 fallback)
- No MCP Gateway → use WebSearch + WebFetch only
- No GROUNDING.md → proceed without project context
- No artifacts/research/ → create it

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
