# Agent Role Definitions

Reusable subagent roles for delegated work. Canonical home: this directory.
Claude Code mounts it via the link `~/.claude/agents` → here (maintained by
`scripts/verify-symlinks.sh`, self-healed every session start). Other harnesses
(Grok, etc.) read these files directly — they are plain markdown; the frontmatter
(`name`, `description`, `model`) is Claude Code metadata and can be ignored.

## Why roles exist

Improvised helper prompts cost ~200 lines each and raw helper output pollutes the
dispatcher's context (agent-director-pattern evaluation, 2026-04-14). A role is
written once; dispatching becomes one line; returns are structured, not log dumps.

## The Return Contract

Every role returns a structured report, never a working log:

```markdown
STATUS: [role-specific enum — the one-word outcome]
[ROLE-SPECIFIC CORE FIELD: the deliverable — CHANGES / ROOT CAUSE / VERDICT / findings]
EVIDENCE or VERIFIED: [what was actually run/observed — cited, exact]
UNVERIFIED or RULED OUT: [what was NOT covered — never omitted]
NOTES: [judgment calls, adjacent observations]
RECOMMENDATION: [what the dispatcher should do next]
```

When dispatching through the Workflow tool, pass this as a JSON schema
(`agent(prompt, {schema})`) so the contract is enforced, not requested.

## Roster

| Role | Use when | Model |
|------|----------|-------|
| implementer | Delegating coding work from a spec; dispatcher reviews the diff | sonnet |
| investigator | Something failed — find root cause BEFORE any fix | sonnet |
| verifier | Attack a claim/fix/plan before trusting it | sonnet |
| review-lens | Standardized review discipline for the review skills | sonnet |
| research-connector | Topic-to-connector research fan-out (research skills) | sonnet |
| code-archaeologist | Understand an unfamiliar codebase's history and why | sonnet |
| migration-planner | Plan upgrades/schema migrations with rollback | sonnet |
| api-tester | Exercise API endpoints after build/change | sonnet |
| log-analyst | Root cause buried in log noise across services | sonnet |
| infra-debugger | Homelab containers/routes/services broken | opus |
| db-admin | DB queries, schema, health across PG/Mongo/Redis | sonnet |
| compact-reviewer | Gap-check a compact file before context clear | sonnet |

Add a role when you've improvised essentially the same helper prompt twice.
Roles define conduct + return format only — project knowledge comes from
GROUNDING.md and rehydrate, so one role works across every project.
