# desktop/ — Skills packaged for Claude Desktop / Cowork

Skills in this directory are **not** loaded by Claude Code. They exist because Cowork
(Claude Desktop's local agent mode) loads no filesystem skills, hooks, or CLAUDE.md —
custom behavior reaches it only as an uploaded skill zip.

Rules for skills here:

- **Self-contained** — an uploaded zip has no `../references/`, so cross-cutting rules
  that matter must be inlined in SKILL.md, and no file may reference outside the skill folder.
- **Source of truth is the folder, not the zip.** Edit `<name>/SKILL.md`, then rebuild:
  `Compress-Archive -Path desktop\<name> -DestinationPath desktop\dist\<name>.zip -Force`
- **Upload manually** in Claude Desktop → Settings → Skills. There is no auto-sync:
  after any edit here, the zip must be rebuilt and re-uploaded on each machine.

## Skills

- `cowork-orient/` — session-start protocol for Cowork in organized project folders
  (GROUNDING reading order, gateway rehydrate, Qdrant memory sync).
