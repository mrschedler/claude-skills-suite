---
name: project-index
description: "Regenerates the project inventory in C:\\dev\\GROUNDING.md by scanning folders, reading GROUNDING files, querying the pipeline, and detecting available docs. Use when projects are added, archived, or descriptions are stale."
argument-hint: "[optional: 'check' for dry-run comparison without writing]"
---

# Project Index

Regenerate the project inventory sections of `C:\dev\GROUNDING.md`. Scans the
workspace, reads each project's GROUNDING.md, queries the pipeline, and rebuilds
the categorized tables with current data.

Preserves the hand-written sections (Who Matt Is, Foundation Projects,
Cross-Project Relationships, Anti-Patterns). Only regenerates the inventory
tables and the documentation availability table.

## Instructions

### Step 1 — Scan the Workspace

1. List all directories in `C:\dev/*/` (exclude hidden dirs like `.claude/`).
2. For each directory, check for:
   - `GROUNDING.md` — read the first `## Why` section (up to 3 sentences) to extract a one-liner
   - `CLAUDE.md` — exists? (Y/—)
   - `artifacts/project.db` — exists? (Y/—)
   - `.git` — is it a git repo?
3. Query `project_call > list_projects` and match pipeline entries to local folders by slug.
   Extract: status, tags, and first line of description for projects without a GROUNDING.md.

### Step 2 — Categorize

Assign each project to exactly one category based on existing GROUNDING.md content
and pipeline tags. Categories (in order of precedence):

| Category | Criteria |
|----------|----------|
| **Foundation** | memory-system, mcp-gateway, claude-skills-suite (always these three) |
| **QuickLinks Products** | Tags contain `quicklinks` OR name starts with `QL-` OR `usb-proxy` |
| **Patent & IP** | Tags contain `patent` OR directory name contains `patent` |
| **Research** | Tags contain `research` OR GROUNDING says "research" / "exploration" / "not commercial" |
| **Business Applications** | Revenue-generating or client-facing apps not in QuickLinks |
| **Infrastructure & Tooling** | Everything else (infra, tooling, internal systems) |

If a project fits multiple categories, use the first match in the table above.
Exception: `usb-proxy` is both QuickLinks Products AND patent-related — list it
under QuickLinks Products with a note about patent relevance.

### Step 3 — Compare (Always Do This)

Before writing, compare the new inventory against the current GROUNDING.md:

1. **New directories** not in the current index — flag for user review
2. **Removed directories** still in the current index — flag for user review
3. **Description changes** — show diff
4. **Category changes** — show diff
5. **Doc availability changes** — show diff

Present the comparison to the user. If the argument was `check`, stop here.

### Step 4 — Write

Replace these sections in `C:\dev\GROUNDING.md` (preserve everything else):

- `## QuickLinks Technologies — Products` (table)
- `## Patent & IP` (table)
- `## Research` (table)
- `## Business Applications` (table)
- `## Infrastructure & Tooling` (table)
- `## Project Documentation Availability` (table)

Use the Edit tool to replace each section's table content. Do NOT touch:
- The header block (title, quote, Who This Is For)
- `## Who Matt Is`
- `## The Three Foundation Projects`
- `## Cross-Project Relationships`
- `## What Lives Here But Isn't a Project`
- `## Anti-Patterns`

### Step 5 — Commit

If changes were written:

```bash
cd C:\dev
git add GROUNDING.md
git commit -m "Update project index — [summary of what changed]"
```

### Table Formats

**Category tables** (QuickLinks, Patent, Research, Business, Infrastructure):

```markdown
| Project | What It Is | Status |
|---------|-----------|--------|
| **project-name** | One-liner from GROUNDING.md or pipeline | Status |
```

- Status values: `Production`, `Active development`, `Active`, `Sprint N complete`,
  `Archived, reference only`, `Patent filed, [phase]`, or pipeline status
- One-liners should be 10-15 words max. Extract from the first paragraph of
  GROUNDING.md's "Why" section. If no GROUNDING.md, use pipeline description first line.

**Documentation availability table:**

```markdown
| Project | GROUNDING | CLAUDE.md | Artifact DB | Pipeline |
|---------|:---------:|:---------:|:-----------:|:--------:|
| project-name | Y | Y | — | Y |
```

Sort alphabetically within each category table. Sort the documentation
availability table alphabetically overall.

## Edge Cases

- **Directory exists but no GROUNDING.md and no pipeline entry:** Include in the
  appropriate category with description "Undocumented — needs GROUNDING.md" and
  flag to user.
- **Pipeline entry exists but no local directory:** Do NOT add to the index.
  The index reflects what's on disk. Mention in the comparison output.
- **New project detected:** Ask user for category and one-liner if GROUNDING.md
  and pipeline both lack enough context.

## What This Skill Does NOT Do

- Does not create or modify individual project GROUNDING.md files
- Does not create pipeline entries
- Does not modify CLAUDE.md at the workspace root
- Does not touch Cross-Project Relationships (that's hand-maintained context)
