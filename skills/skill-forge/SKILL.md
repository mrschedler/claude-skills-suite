---
name: skill-forge
description: Creates or edits skills. Scaffolds directory, writes SKILL.md from template, validates against checklist. Use when building or modifying a skill.
---

# Skill Forge

Create new skills or edit existing ones following the suite's established patterns.
Auto-detects mode based on whether the skill directory already exists.

## Why This Exists

Skills encode hard-won lessons. Without this skill, each new skill risks repeating
past mistakes (always-on description loops, stale file references, platform-specific
assumptions). Skill-forge encodes the patterns so they're followed by default.

## Inputs

- **Skill name** — the user provides a name or describes what they want
- **Skill purpose** — what problem does it solve, when should it trigger
- **Existing SKILL.md** (edit mode) — the current file to modify
- `references/skill-template.md` — canonical SKILL.md structure
- `references/validation-checklist.md` — anti-patterns and validation rules

## Outputs

- `skills/<name>/SKILL.md` — the skill file (created or updated)
- `skills/<name>/references/` — reference files if progressive disclosure is needed
- Validation report showing pass/warn/fail against the checklist

## Instructions

### Phase 1: Detect Mode

Check if `skills/<name>/SKILL.md` exists.

- **Exists** → edit mode. Read the current SKILL.md. Identify what the user wants changed.
- **Does not exist** → create mode. Gather intent from the user.

Naming conventions:
- Review lenses: `*-review` (e.g., `performance-review`)
- Meta-skills: `meta-*` (e.g., `meta-deploy`)
- Driver skills: bare CLI name (e.g., `kubectl`)
- Action skills: verb-noun (e.g., `cache-warm`, `db-migrate`)

### Phase 2: Gather Intent

Ask the user (skip questions already answered):

1. **What does this skill do?** One sentence.
2. **What triggers it?** User says "X", after event Y, part of meta-skill Z.
3. **What does it need?** Inputs — files, project docs, external data.
4. **What does it produce?** Files, findings, side effects.
5. **Is it a review lens?** If yes: needs fresh-findings check, finding format, severity levels, summary.
6. **Does it need reference files?** Large catalogs or checklists that would push SKILL.md over 300 lines.

Present a brief plan before writing:
```
Mode: create | edit
Name: <name>
Type: review lens | meta-skill | driver | action | utility
Sections: [list]
References: [list of reference files, if any]
```

Wait for user approval.

### Phase 3: Scaffold (Create Mode Only)

```bash
mkdir -p skills/<name>
mkdir -p skills/<name>/references   # only if reference files needed
```

### Phase 4: Write SKILL.md

Read `references/skill-template.md` for the canonical structure. Key rules:

**Frontmatter:**
- `name:` must match directory name
- `description:` ≤150 characters, third person, trigger-focused

**Body — agent-agnostic principles:**
- Describe WHAT to do, not which model/tool to use
- If the skill benefits from parallel sub-tasks, describe the tasks — the executing agent decides delegation
- Infrastructure calls (MCP Gateway) are enhancements, not requirements
- No hardcoded model names in skill logic
- Shell commands must work in Git Bash on Windows

**Structure:**
1. Title (# Name)
2. Purpose (1-3 sentences with "why")
3. Inputs (table or list)
4. Outputs
5. Instructions (numbered phases, imperative form, exit conditions)
6. References (if reference files exist)
7. Examples (2-4 scenarios)
8. Cross-cutting footer

**Review lens specifics:**
- Fresh Findings Check as first step (see `references/review-lens-framework.md`)
- Finding format with: severity, category, location, problem, recommendation
- Severity levels (CRITICAL/HIGH/MEDIUM/LOW)
- Summarize step as final instruction

**Keep it under 300 lines.** Move overflow to `skills/<name>/references/`.

### Phase 5: Write Reference Files (If Needed)

- Create in `skills/<name>/references/`
- Add `## References (on-demand)` section to SKILL.md
- Pattern: "Read `references/X.md` for [when/why to read it]"

### Phase 6: Validate

Check against applicable rules:

1. **Frontmatter** — name matches dir, description ≤150 chars, trigger-focused
2. **Structure** — all required sections present, under 300 lines
3. **Agent-agnostic** — no hardcoded model names, no required CLIs without fallback, cross-platform shell
4. **Content quality** — imperative instructions, exit conditions, examples
5. **Anti-patterns** — no project litter, no always-on description loops, no context stuffing

Report: PASS / WARN / FAIL.

### Phase 7: Report

- Files created/modified (with paths)
- Validation result
- Whether the skill needs wiring into a meta-skill

## Examples

```
User: I need a skill that reviews database query performance.
→ Create mode. Review lens type. Scaffold, write SKILL.md. Validate.
```

```
User: /skill-forge dependency-audit
→ Create mode with name provided. Ask remaining questions. Build.
```

```
User: The security-review description is too long, fix it.
→ Edit mode. Read, trim, validate.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
