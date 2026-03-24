# Cross-Cutting Rules

These rules apply to every skill in this suite. Every SKILL.md must follow them.

## Rules

1. **Read GROUNDING.md first** — If a project has a GROUNDING.md, read it before doing anything. It tells you why the project exists, what decisions were made, and what not to do. If working within this skills repo itself, read the repo-level GROUNDING.md.

2. **No project litter** — Skills must NOT create framework-specific files (coterie.md, cnotes.md, etc.) in target projects. The only project files skills may create are ones explicitly described in the skill's Outputs section and confirmed by the user.

3. **Self-sufficient execution** — Every skill must work with whatever agent is running it. Skills describe WHAT to do, not which model to use. If a skill benefits from parallel sub-tasks (e.g., multiple review lenses), describe the tasks — the executing agent decides whether to use subagents, CLI tools, or run them sequentially.

4. **External CLI gating** — Any skill that can leverage an external CLI (Codex, Gemini, Vibe, Cursor, Copilot, etc.) must: (a) check availability before invoking, (b) provide a self-contained fallback that any capable agent can execute directly, and (c) never require a specific CLI to function.

5. **Infrastructure access** — MCP Gateway provides the infrastructure layer:
   - Memory (Qdrant): `mcp__gateway__memory_call`
   - Graph (Neo4j): `mcp__gateway__graph_call`
   - Documents (MongoDB): `mcp__gateway__mongodb_call`
   - Projects: `mcp__gateway__project_call`
   - Preferences: `mcp__gateway__pref_call`
   - Agents without MCP access should skip infrastructure calls gracefully — they're enhancements, not blockers.

6. **Windows + Git Bash** — All shell commands must work in Git Bash on Windows 11:
   - No `gtimeout` or `/opt/homebrew/*` paths
   - No macOS-specific tools or paths
   - Use forward slashes in paths within shell scripts
   - Test scripts with `bash` not `zsh`

7. **Context window discipline** — Skills should be concise. If SKILL.md exceeds 300 lines, move overflow to `references/`. Use progressive disclosure: metadata always loaded, SKILL.md on trigger, references on demand.

8. **Memory sync after significant work** — If a skill produces decisions, findings, or state changes worth remembering across sessions, persist them. Agents with MCP Gateway access should store to Qdrant (`memory_call` > `store`). Agents without it should note findings in their output for the user to capture.

9. **Respect existing skills** — `feature-dev` and `ralph-workflow` are established development workflows. New skills complement them. Do not duplicate their functionality without clear added value.

10. **Driver skill boundary** — If external CLIs are added, consuming skills reference the driver skill for invocation details. Consuming skills specify: task type, prompt/context, expected output, fallback behavior. They do NOT embed CLI commands, flags, or path resolution.
