# Web Search — Research Findings

> Topics: Agent-friendly project layouts, root cleanliness standards, artifact organization, safe reorganization, anti-patterns, file naming for agents, context window optimization
> Run: 009
> Date: 2026-03-20

---

## Topic 1: Agent-Friendly vs Human-Friendly Project Layouts

### Queries Executed
1. `AI coding agents project layout navigation Cursor Copilot Claude Code file discovery 2025` — 10 results
2. `CLAUDE.md AGENTS.md project configuration AI agent context file best practices` — 10 results
3. `Devin SWE-agent project structure navigation challenges codebase understanding benchmarks` — 10 results
4. `cursor agent best practices project structure context files 2025 site:cursor.com` — 10 results
5. `aider repomaps codebase structure agent navigation repository map technique` — 10 results

### Finding 1: Every Major Agent Reads a Dedicated Config File
- **Source**: [CLAUDE.md, AGENTS.md, and Every AI Config File Explained](https://www.deployhq.com/blog/ai-coding-config-files-guide)
- **Key takeaway**: AI agents need a machine-readable project map at a predictable path. Each tool has its own: Claude Code reads `CLAUDE.md`, Codex CLI reads `AGENTS.md`, Gemini CLI reads `GEMINI.md`, Cursor uses `.cursor/rules/*.mdc` files, GitHub Copilot uses `.github/copilot-instructions.md`. The current Cursor best practice is a `.cursor/rules/` directory with scoped `.mdc` files (e.g., `frontend.mdc`, `backend.mdc`), activated only for relevant file contexts.
- **Confidence**: high
- **Details**: AGENTS.md was donated to the Linux Foundation's Agentic AI Foundation (AAIF) in December 2025 alongside Anthropic's MCP and Block's goose, signaling it as the emerging open standard.

### Finding 2: Aider's Repository Map — The Gold Standard for Agent Navigation
- **Source**: [Repository map | aider](https://aider.chat/docs/repomap.html), [Building a better repository map with tree sitter | aider](https://aider.chat/2023/10/22/repomap.html)
- **Key takeaway**: Aider builds a compact repository map using tree-sitter to extract symbols (classes, functions, call signatures), then uses a graph-ranking algorithm to select the most relevant subset within the active token budget. Project structures that expose clear symbol boundaries (explicit exports, well-named modules) produce better repo maps and therefore better agent navigation.
- **Confidence**: high
- **Details**: The repo map defaults to ~1K tokens. Aider dynamically adjusts this based on the chat state. Files with clear, well-defined interfaces produce map entries that are more useful to the ranking algorithm than files with flat, opaque structures.

### Finding 3: Cursor Uses RAG + Semantic Grep for Context
- **Source**: [Best practices for coding with agents](https://cursor.com/blog/agent-best-practices), [Rules | Cursor Docs](https://cursor.com/docs/context/rules)
- **Key takeaway**: Cursor indexes the entire repo via RAG and also exposes instant grep. The agent pulls context on demand — tagging specific files is only needed when you know the exact file. Including irrelevant files actively confuses the agent. The "include project structure in context" option adds the directory tree to prompts and improves navigation of large nested repos.
- **Confidence**: high
- **Details**: Cursor rules should be organized hierarchically: `project/.cursor/rules/` for global, `backend/server/.cursor/rules/` for subsystem-specific. Rules must be focused, actionable, and scoped — vague guidance is worse than no guidance.

### Finding 4: Agent Performance Degrades on Multi-File Tasks in Disorganized Repos
- **Source**: [SWE-EVO: Benchmarking Coding Agents in Long-Horizon Software Evolution Scenarios](https://www.arxiv.org/pdf/2512.18470), [Devin's 2025 Performance Review](https://cognition.ai/blog/devin-annual-performance-review-2025)
- **Key takeaway**: SWE-EVO tasks span an average of 21 files with test suites averaging 874 tests. Current top agents (GPT-5, OpenHands) achieve only 21% on SWE-EVO vs. 65% on SWE-Bench Verified — performance degrades sharply when 3+ files must be modified. Agent success is strongly correlated with how clearly the codebase signals inter-file dependencies.
- **Confidence**: high (peer-reviewed)
- **Details**: Devin is "senior-level at codebase understanding but junior at execution." BM25 retrieval is preferred over dense retrieval for code navigation due to long key/query lengths.

### Finding 5: 80% of Agent Tokens Are Wasted on File Discovery
- **Source**: [Your AI Coding Agent Wastes 80% of Its Tokens Just Finding Things](https://medium.com/@jakenesler/context-compression-to-reduce-llm-costs-and-frequency-of-hitting-limits-e11d43a26589)
- **Key takeaway**: An observed case: Claude Code read 25 files to answer a question about 3 functions because it had no structural map of the codebase. One developer built a code knowledge graph that saved 40–95% on tokens without losing accuracy. Clear project structure is the first-order token optimization.
- **Confidence**: medium (practitioner report)
- **Details**: AGENTS.md presence was associated with a 29% reduction in median runtime and 17% reduction in output token consumption in empirical measurements.

### Finding 6: Agent Skills — Anthropic's Progressive Disclosure Pattern
- **Source**: [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- **Key takeaway**: Anthropic's production pattern organizes capabilities as folder hierarchies of instructions, scripts, and resources that agents discover and load dynamically. Progressive disclosure is the core principle: load information only when needed. Structure is context engineering.
- **Confidence**: high (primary source — Anthropic engineering blog)
- **Details**: Long-running agents use a `claude-progress.txt` alongside git history so agents can quickly understand work state across fresh context windows. This externalizes context that would otherwise bloat the conversation.

---

## Topic 2: Project Root Cleanliness Standards

### Queries Executed
1. `project root cleanliness standards open source best practices what files belong at root` — 10 results
2. `12-factor app project structure config separation best practices 2025` — 10 results
3. `Google monorepo project structure standards Stripe engineering file organization` — 10 results
4. `node.js javascript project root clutter tooling config files eslint prettier babel tsconfig` — 10 results
5. `config scatter anti-pattern multiple config files dotfiles root project consolidation` — 10 results

### Finding 7: The Rule of Root Minimalism
- **Source**: [Structuring Your Project — The Hitchhiker's Guide to Python](https://docs.python-guide.org/writing/structure/), [Files every open-source project should have - DEV Community](https://dev.to/msaaddev/files-every-open-source-project-must-have-2mmm)
- **Key takeaway**: Files should exist at root only if tools require it OR if it genuinely makes life easier. The rule: if a file doesn't need to be at root for either of those reasons, it belongs in a subdirectory. Mandatory root files: `README.md`, `LICENSE`, `.gitignore`, `pyproject.toml` (or equivalent package manifest), and CI config.
- **Confidence**: high
- **Details**: Generic management scripts (e.g., `manage.py`, `fabfile.py`) belong at root. Source code and tests belong in `src/` and `tests/`, not root. A `CONTRIBUTE.md` and requirements file belong at root for open-source projects.

### Finding 8: JavaScript/Node.js Root Clutter Is an Epidemic
- **Source**: [The creeping scourge of tooling config files in project root directories | Hacker News](https://news.ycombinator.com/item?id=24066748), [Recommendation for tooling config file location/format · nodejs/tooling](https://github.com/nodejs/tooling/issues/71)
- **Key takeaway**: Single-line Node packages commonly have 10+ config files at root (`.eslintrc`, `.prettierrc`, `babel.config.js`, `tsconfig.json`, `.babelrc`, etc.). This is "information overload" for first-time visitors and for agents. The Node.js tooling group has been working on this since 2020 with no universal solution — it's a known unsolved problem.
- **Confidence**: high
- **Details**: The `.config/` subdirectory convention is gaining traction as a consolidation point. Tools using `cosmiconfig` support placement in `package.json` (under a tool-specific key) or in a dedicated config file — using `package.json` consolidation reduces root file count. ESLint's flat config (`eslint.config.mjs`) and Prettier's config consolidation in `package.json` reduce clutter.

### Finding 9: 12-Factor App — Config Is Not Code
- **Source**: [The Twelve-Factor App — Config](https://12factor.net/config)
- **Key takeaway**: 12-Factor draws a sharp line: internal app config (routes, module wiring) lives in code; deployment config (credentials, URLs, ports) lives exclusively in environment variables. This means `.env` files should never be committed and config/ directories holding deployment secrets are an anti-pattern vs. env vars.
- **Confidence**: high (canonical reference)
- **Details**: "Config does not include internal application config, such as config/routes.rb in Rails... this type of config does not vary between deploys and is best done in the code." The separation keeps root clean of deployment-specific configuration files.

### Finding 10: Google's Monorepo Enforces Uniform Directory Layout Globally
- **Source**: [How Google Does Monorepo - QE Unit](https://qeunit.com/blog/how-google-does-monorepo/)
- **Key takeaway**: Google enforces that "a Java developer from one project team instantly recognizes the directory structure for another team's application or service" across languages. The design of the directory layout is enforced globally. This is the gold standard for agent-friendliness: a developer (or agent) new to any service can immediately orient themselves.
- **Confidence**: high
- **Details**: Google uses "workspaces" — each has a team and responsible engineer. Modularization, interface, and service standards enable cross-component communication. API documentation practices and static analysis tools proactively support dependency management.

### Finding 11: Use `.config/` Directory to Consolidate Tool Configs
- **Source**: [Use `.config` to store your project configs | Lobsters](https://lobste.rs/s/wac58n/use_config_store_your_project_configs)
- **Key takeaway**: Using `.config/` as a consolidated directory for all tool configs is an emerging convention — it looks distinctive, carries the semantic meaning of "config files," and is preferable to having multiple dotfiles at root. The `.d` suffix pattern (e.g., `config.d/`) is an established Unix convention for splitting large configs into multiple files.
- **Confidence**: medium (community discussion, not a formal standard)
- **Details**: Two separate problems exist: where user-specific config files live, and where project-specific config files live. The `.config/` convention addresses project-specific configs.

---

## Topic 3: Artifact and Output File Organization

### Queries Executed
1. `build output artifact organization best practices generated files directory structure` — 10 results
2. `"artifacts" directory convention generated files gitignore build output research data best practices` — 10 results
3. `ephemeral vs persistent data storage project organization tmp cache patterns` — 10 results
4. `SQLite database file location best practices application data directory XDG base directory spec` — 10 results
5. `log file organization rotation best practices application logs separate directory naming` — 10 results

### Finding 12: Build Artifacts Belong Under `artifacts/` or `dist/` and Must Be Gitignored
- **Source**: [.gitignore Best Practices](https://gitignore.pro/guides/gitignore-best-practices), [Storing build artifacts - CircleCI Docs](https://circleci.com/docs/artifacts/)
- **Key takeaway**: Ignored files are "build artifacts and machine-generated files that can be derived from repository source." Standard gitignored output dirs: `/bin`, `/build`, `/dist`, `/target`, `/artifacts`. CI systems like CircleCI store artifacts at a defined path; later jobs fetch them by path convention. The `artifacts/` directory should be standardized and fully gitignored (or have a granular `.gitignore` within it).
- **Confidence**: high
- **Details**: .NET SDK formalizes this with an `ArtifactsPath` MSBuild property defaulting to `$(MSBuildThisFileDirectory)artifacts`. This pattern — a single top-level `artifacts/` with structured subdirectories — is the modern .NET standard.

### Finding 13: Separate Ephemeral from Persistent Data by Directory
- **Source**: [Ephemeral Data Best Practices Playbook | Speedscale](https://speedscale.com/blog/ephemeral-data/), [Designing a Storage Layer (Ephemeral or Persistent)](https://algodaily.com/lessons/design-a-storage-layer-ephemeral-persistent)
- **Key takeaway**: Ephemeral data (caches, temp files, intermediate results) should live in separate directories from persistent data (databases, research artifacts, final outputs). Best practice: combine ephemeral storage (high-IOPS local SSD) for temp/cache with persistent storage for valuable data. In project terms: `tmp/` or `.cache/` for ephemeral, `artifacts/` or `data/` for persistent.
- **Confidence**: high
- **Details**: Cache data (Redis-style) is the canonical ephemeral case. Never mix caching directories with output directories — when CI clears the cache, it should not destroy important outputs.

### Finding 14: SQLite Files Belong in XDG Data Directory, Not Project Root
- **Source**: [XDG Base Directory Specification | Alchemists](https://alchemists.io/articles/xdg_base_directory_specification), [SQLite User Forum: XDG base directory specification](https://sqlite.org/forum/forumpost/5cc6d059e9e092ed?t=h)
- **Key takeaway**: Per XDG spec: `$HOME/.local/share/<app>/` for persistent data (including SQLite DBs), `$HOME/.cache/<app>/` for cache, `$HOME/.config/<app>/` for config. For project-local SQLite (e.g., artifact stores, research DBs), the convention is to place them under `artifacts/` or `data/` and gitignore them. Do not put `.db` files at the project root.
- **Confidence**: high (XDG is a formal spec)
- **Details**: Windows: `%AppData%/<app>/`. macOS: `~/Library/Application Support/<app>/`. For project-scoped databases (not user-global), the project's `artifacts/` or `data/` directory is appropriate with a gitignore entry.

### Finding 15: Log Files Belong Under `logs/` with Date-Based Rotation
- **Source**: [Log Rotation Best Practices - Urchin Help](https://support.google.com/urchin/answer/28566), [What Is Log Rotation | Sematext](https://sematext.com/glossary/log-rotation/)
- **Key takeaway**: Application logs should live under a dedicated `logs/` directory (never at root). Naming convention: `{app}-{YYYYMMDD}.log`. Daily rotation is recommended for busy services. Retention: 30–90 days for application performance logs. Compress rotated files. The `logs/` directory should be gitignored entirely.
- **Confidence**: high
- **Details**: Use `%Y%m%d` timestamp suffix for rotated files. Keep folder names short to avoid path-length issues on Windows (259-char limit). logrotate is the standard Linux tool.

---

## Topic 4: Safe Project Reorganization Techniques

### Queries Executed
1. `safe project reorganization refactoring file moves without breaking imports git history tools` — 10 results
2. `git mv rename tracking history preservation large-scale refactoring best practices` — 10 results
3. `project reorganization pitfalls automated refactoring CI CD path references broken imports` — 10 results

### Finding 16: git filter-repo Is the Right Tool for Large-Scale Moves
- **Source**: [Git Filter-Repo: The Best Way to Rewrite Git History](https://www.git-tower.com/learn/git/faq/git-filter-repo), [Git Move Files: Practical Renames, Refactors, and History Preservation in 2026](https://thelinuxcode.com/git-move-files-practical-renames-refactors-and-history-preservation-in-2026/)
- **Key takeaway**: `git filter-repo` replaces the deprecated `git filter-branch`. It's significantly faster (single-pass processing), easier to use, and allows moving entire trees into subdirectories while preserving history. Use it for structural reorganizations (e.g., "move everything into a `src/` layout").
- **Confidence**: high
- **Details**: `git log --follow` is the tool for tracing history through renames post-move. The `-M` flag detects moved/renamed lines within a file; `-C` detects lines copied from other files. Modern Git (2.19+) can detect directory renames implicitly when a substantial subset of files move consistently.

### Finding 17: Commit Strategy for Safe Reorganization
- **Source**: [ESMITHY.NET - Preserving Git Blame History when Refactoring](https://esmithy.net/2020/08/15/preserve-git-blame-history-refactoring/), [Refactoring code and Git history! - DEV Community](https://dev.to/aamfahim/refactoring-code-and-git-history-46cl)
- **Key takeaway**: The commit ordering pattern is: (1) pure move commit, (2) structural refactor commit, (3) config update commit. Separating moves from edits lets Git recognize renames with high confidence and makes `git blame` accurate. Never mix file moves with content changes in the same commit.
- **Confidence**: high
- **Details**: A "pure move commit" is a commit that does nothing but rename/move files with no content changes. This gives Git the best chance of applying its similarity heuristics correctly. `git mv` performs the move and stages it in one step, which is preferable to `mv` + `git add` + `git rm`.

### Finding 18: Automated Reorganization Pitfalls
- **Source**: [AI Code Refactoring: Tools, Tactics & Best Practices | Augment Code](https://www.augmentcode.com/tools/ai-code-refactoring-tools-tactics-and-best-practices), [Code Refactoring: When to Refactor and How to Avoid Mistakes](https://www.tembo.io/blog/code-refactoring)
- **Key takeaway**: AI refactoring tools can touch dozens of files at once. Key pitfalls: (1) broken import statements — the most common failure mode; (2) AI "fixing" intentional patterns; (3) removing comments containing important context; (4) subtle behavioral changes that tests don't cover. Mitigation: small incremental changes, one pattern at a time, each increment independently reviewable and revertible.
- **Confidence**: high
- **Details**: AWS CDK specifically warns: `cdk refactor` fails if code includes actual resource modifications alongside structural refactoring — deploy resource changes first, then reorganize. This principle generalizes: decouple semantic changes from structural changes.

### Finding 19: Path Reference Risks in CI/CD
- **Source**: [Refactoring Home Page - refactoring.com](https://refactoring.com/), [How to Refactor Complex Codebases – freeCodeCamp](https://www.freecodecamp.org/news/how-to-refactor-complex-codebases/)
- **Key takeaway**: Legacy build scripts often hardcode paths. Moving files without auditing CI/CD configs, Dockerfiles, Makefiles, and deployment scripts is a common cause of broken pipelines post-reorganization. Always grep for old paths before committing a reorganization.
- **Confidence**: high
- **Details**: A CI pipeline that auto-tests every change dramatically reduces reorganization risk. Set up the pipeline before doing the reorganization, not after.

---

## Topic 5: Anti-Patterns — File Sprawl, Orphaned Artifacts, Duplicate Databases, Config Scatter

### Queries Executed
1. `file sprawl anti-patterns orphaned files duplicate config detection cleanup techniques` — 10 results
2. `detecting unused files dead code orphaned dependencies project audit tools 2025` — 10 results
3. `config scatter anti-pattern multiple config files dotfiles root project consolidation` — 10 results (shared with Topic 2)

### Finding 20: Knip — Best Tool for Dead Code + Orphaned File Detection in JS/TS
- **Source**: [Declutter your JavaScript & TypeScript projects | Knip](https://knip.dev/), [knip vs depcheck | npm-compare](https://npm-compare.com/depcheck,knip)
- **Key takeaway**: Knip finds unused files, unused exports, unused dependencies, and unused types across an entire JS/TS project including monorepos. It works with Next.js, Vite, NestJS. For early-stage projects, `depcheck` handles `package.json` auditing quickly. For mature projects, Knip is the gold standard. Both can be integrated into pre-commit hooks.
- **Confidence**: high
- **Details**: Knip integration into CI prevents dead code accumulation. Vue projects have `vue-unused` for equivalent detection. Go projects use `go mod tidy`. The pattern: run dead code detection on every PR, not as a quarterly cleanup.

### Finding 21: fclones — Cross-Platform Duplicate File Detection
- **Source**: [GitHub - pkolaczk/fclones](https://github.com/pkolaczk/fclones)
- **Key takeaway**: `fclones` is a CLI utility that identifies groups of identical files by checksum with configurable search scope. Can detect duplicate databases, duplicate config files, and redundant research artifacts. Useful for one-time audits before reorganizations.
- **Confidence**: high
- **Details**: Works on name or checksum matching. Large files and files not accessed/modified over a period are additional cleanup candidates.

### Finding 22: Config Scatter — Root Dotfile Proliferation
- **Source**: [The creeping scourge of tooling config files in project root directories | Hacker News](https://news.ycombinator.com/item?id=24066748), [Use `.config` to store your project configs | Lobsters](https://lobste.rs/s/wac58n/use_config_store_your_project_configs)
- **Key takeaway**: The root dotfile proliferation anti-pattern is a known, unsolved problem in JS/Node ecosystem. Mitigation strategies: (1) consolidate into `package.json` using tool-specific keys; (2) use a `.config/` subdirectory; (3) use cosmiconfig-aware tools that support the `.config/` path. Tools like ESLint (flat config), Prettier, and TypeScript are slowly adding support for consolidation.
- **Confidence**: high
- **Details**: The Node.js tooling group (issue #79) identified this as a structural problem in 2020. It is "information overload" for newcomers and agents alike. Every extra file at root increases the cognitive load and token cost for agents reading directory listings.

### Finding 23: Context Rot — Growing Instruction Files Kill Agent Performance
- **Source**: [Your agent's context is a junk drawer | Augment Code](https://www.augmentcode.com/blog/your-agents-context-is-a-junk-drawer), [Cutting Through the Noise | JetBrains Research Blog](https://blog.jetbrains.com/research/2025/12/efficient-context-management/)
- **Key takeaway**: As AGENTS.md / CLAUDE.md grows, every token loads on every request regardless of relevance — actively reducing the context the agent can use for the actual task. "Context rot" = as token count increases, model recall accuracy decreases. The anti-pattern is stuffing everything into a single instruction file. The fix is progressive disclosure and nested config files.
- **Confidence**: high
- **Details**: Best practice: keep root AGENTS.md/CLAUDE.md under 300 lines. Use nested files (e.g., `src/AGENTS.md`, `tests/AGENTS.md`) for subsystem-specific instructions. Reference files instead of copying their contents.

---

## Topic 6: File Naming Conventions That Help Agents

### Queries Executed
1. `file naming conventions coding projects predictable naming glob grep agent discoverability` — 10 results
2. `kebab-case vs snake_case file naming convention web projects agent discoverability 2025` — 10 results
3. `software project naming conventions INDEX files README agents navigation predictability` — 10 results
4. `cursor watchful headers project structure self-documenting file headers agent navigation` — 10 results

### Finding 24: Naming Conventions Directly Enable Glob-Based Discovery
- **Source**: [File Naming Conventions: Keep Your Project Clean and Readable](https://dev.to/damiansiredev/file-naming-conventions-keep-your-project-clean-and-readable-1plk), [Naming Conventions | devopedia](https://devopedia.org/naming-conventions)
- **Key takeaway**: Naming conventions lead to predictability and discoverability. CLI commands and IDE extensions rely on conventions to generate, find, and link code. Avoid spaces (break glob patterns and shell scripts). Use hyphens (kebab-case) or underscores (snake_case) consistently. The most important information belongs first in the filename for sort-based discovery.
- **Confidence**: high
- **Details**: Glob patterns use `*` wildcards. A consistent naming convention means `**/*.test.ts` reliably finds all tests, `**/SKILL.md` reliably finds all skills, etc. Inconsistent extensions or mixed casing breaks these patterns.

### Finding 25: Kebab-Case for Web/URL-Oriented Files, Snake_Case for Python/Data
- **Source**: [Snake Case VS Camel Case VS Pascal Case VS Kebab Case](https://www.freecodecamp.org/news/snake-case-vs-camel-case-vs-pascal-case-vs-kebab-case-whats-the-difference/), [From camelCase to kebab-case: Our naming convention](https://blog.nordcraft.com/from-camelcase-to-kebab-case-our-naming-convention)
- **Key takeaway**: Kebab-case: web projects, URLs, HTML attributes, CSS classes, file names in web projects. Snake_case: Python files/modules, database columns, config keys. PascalCase: React components, TypeScript classes. The key rule for agent discoverability: pick one and be consistent — mixed conventions are the worst outcome because agents cannot build reliable glob patterns.
- **Confidence**: high
- **Details**: Kebab-case is readable and URL-safe. The dash is not interpreted by grep/glob as a special character. Double-clicking kebab-case selects individual words; double-clicking snake_case selects the whole string (can help or hinder depending on context).

### Finding 26: Cursor Watchful Headers — Embedding Path in File for Agent Orientation
- **Source**: [Cursor Watchful Headers](https://forum.cursor.com/t/cursor-watchful-headers-keep-your-project-structure-clean-self-documenting/48984), [GitHub - johnbenac/cursor-watchful-headers](https://github.com/johnbenac/cursor-watchful-headers)
- **Key takeaway**: A community tool that automatically adds a file header containing the file's path within the project tree. This gives agents "clear breadcrumbs back to the correct location" when context from earlier in a conversation has degraded. The path-in-header pattern is a lightweight way to combat context drift in long agent sessions.
- **Confidence**: medium (community tool, not a formal standard)
- **Details**: Python-based file watcher that generates headers including the current project tree. Particularly useful for long-running agent sessions in complex, nested projects. The technique can be adopted manually as a comment convention without the tooling.

### Finding 27: AGENTS.md as a Machine-Readable README
- **Source**: [Agents.md: A Machine-Readable Alternative to README](https://research.aimultiple.com/agents-md/), [AGENTS.md Explained](https://particula.tech/blog/agents-md-ai-coding-agent-configuration)
- **Key takeaway**: AGENTS.md complements README.md by containing operational context that agents need but humans don't prominently require: build commands, test invocation, code conventions, and hard boundaries. A naming convention where `AGENTS.md` is at a predictable path (root and subsystem roots) reduces agent discovery overhead to zero — the agent knows exactly where to look.
- **Confidence**: high
- **Details**: In monorepos, place `AGENTS.md` inside each package root. Agents automatically read the nearest file in the directory tree, so the closest one takes precedence. This cascading override pattern is the standard for both AGENTS.md and CLAUDE.md.

---

## Topic 7: Agent Context Window Optimization via Project Structure

### Queries Executed
1. `monorepo vs polyrepo AI agent context window performance .gitignore .cursorignore optimization` — 10 results
2. `.cursorignore .clinerules patterns AI agent context optimization what to exclude` — 10 results
3. `nx monorepo ai agent context project.json workspace.json dependency graph agent productivity` — 10 results
4. `"project structure" AI agent "reduces context" OR "context window" OR "token waste" file discovery 2025` — 10 results
5. `agent context engineering file structure project organization Anthropic 2025` — 10 results
6. `repository map tree structure AI coding assistant context efficient file discovery` — 10 results

### Finding 28: Monorepo Gives Agents Cross-Service Context — Polyrepo Creates Blind Spots
- **Source**: [Monorepo vs Polyrepo: AI's New Rules for Repo Architecture | Augment Code](https://www.augmentcode.com/learn/monorepo-vs-polyrepo-ai-s-new-rules-for-repo-architecture), [Monorepos Are Back — And AI Is Driving the Comeback](https://medium.com/@dani.garcia.jimenez/monorepos-are-back-and-ai-is-driving-the-comeback-f4abbb7bb55f)
- **Key takeaway**: In a polyrepo, an AI agent "sees one project at a time and is blind to how changes ripple across the system." In a monorepo, the agent sees the whole codebase, understands dependencies, and catches downstream impacts. Airbnb compressed an 18-month migration to 6 weeks using agents in a monorepo. The tradeoff: monorepo PRs take 9x longer in review cycles, but agents more than compensate with context-aware changes.
- **Confidence**: high (benchmark data from 320 teams, Faros AI)
- **Details**: Many monorepo properties that slow humans actually help agents. The key: agents can scan and update large code volumes predictably, making "trivial library change + update all clients" tasks feasible at scale.

### Finding 29: Nx Exposes the Project Graph to Agents
- **Source**: [Teach Your AI Agent How to Work in a Monorepo | Nx Blog](https://nx.dev/blog/nx-ai-agent-skills), [Enhance Your AI Coding Agent | Nx](https://nx.dev/docs/features/enhance-ai)
- **Key takeaway**: Nx exposes the project graph and dependency metadata to agents via CLI commands (`nx show projects`, `nx graph`). Agents get structured data instead of grepping config files. This is the ideal pattern: structured machine-readable metadata exposed via a stable CLI, not inferred from file traversal.
- **Confidence**: high
- **Details**: The `nx-workspace` skill teaches agents to explore monorepo structure using the project graph. Agent can filter by type, tag, or pattern; trace dependencies; understand target configurations. This structured metadata replaces ad-hoc file scanning.

### Finding 30: .cursorignore/.cursorindexignore for Noise Reduction
- **Source**: [Optimizing Coding Agent Rules for Improved Accuracy | Arize AI](https://arize.com/blog/optimizing-coding-agent-rules-claude-md-agents-md-clinerules-cursor-rules-for-improved-accuracy/), [Cursor Docs — Rules](https://docs.cursor.com/context/rules)
- **Key takeaway**: Place `.cursorignore` and `.cursorindexignore` at project root with `.gitignore`-style syntax. Standard exclusions: `node_modules/`, `dist/`, `build/`, `.env`, `*.log`, `*.db`. For large `docs/` directories: put in `.cursorindexignore` to prevent indexing but preserve on-demand access via `@docs/file.md` tagging.
- **Confidence**: high
- **Details**: The pattern is: exclude by default, allow on-demand. This keeps the default context clean while preserving accessibility. Heavy binary files (images, PDFs) should always be excluded. Build artifacts and generated files should always be excluded.

### Finding 31: Agentic-Cursorrules — File-Tree Partitioning for Multi-Agent Systems
- **Source**: [GitHub - s-smits/agentic-cursorrules](https://github.com/s-smits/agentic-cursorrules), [Multi-agent Management System in Cursor](https://forum.cursor.com/t/multi-agent-management-system-in-cursor/29872)
- **Key takeaway**: When running multiple agents on a codebase, each agent should be confined to a clearly-defined directory slice. Agentic-cursorrules generates per-domain markdown files containing explicit file-tree boundaries. Supports up to 4 concurrent agents. The anti-pattern is giving all agents access to the entire tree — they end up making conflicting changes to shared utilities.
- **Confidence**: medium (community tool, validated by practice)
- **Details**: The tool scans project directories, identifies logical domains (e.g., `backend/`, `frontend/`, `shared/`), and generates domain-specific cursorrules files. This is a structural solution to a coordination problem.

### Finding 32: Repomix — Flatten Repo to AI-Friendly Single File
- **Source**: [GitHub - yamadashy/repomix](https://github.com/yamadashy/repomix), [Repomix | Pack your codebase into AI-friendly formats](https://repomix.com/)
- **Key takeaway**: Repomix packs an entire repository into a single AI-friendly file for feeding to LLMs. Respects `.gitignore`, `.ignore`, and `.repomixignore`. Uses tree-sitter via `--compress` to extract key code elements, reducing token count while preserving structure. Provides per-file token counts for LLM context planning.
- **Confidence**: high
- **Details**: Includes Secretlint for sensitive information detection before packaging. The output begins with an AI-oriented explanation of the codebase structure. Useful for one-shot tasks where an agent needs full repo context.

### Finding 33: Codified Context — Knowledge Graphs Beat File Scanning
- **Source**: [Codified Context: Infrastructure for AI Agents in a Complex Codebase](https://arxiv.org/html/2602.20478v1), [Understanding AI Coding Agents Through Aider's Architecture](https://simranchawla.com/understanding-ai-coding-agents-through-aiders-architecture/)
- **Key takeaway**: Hybrid indexing (AST/code graph + vector search) is the two-layer approach for making large codebases efficiently searchable. RepoGraph provides agents structured sub-graphs ("ego-graphs") around specific keywords. The research consensus: pre-built knowledge graphs save 40–95% on tokens vs. ad-hoc file scanning, with no accuracy loss.
- **Confidence**: high (arXiv, peer review in progress)
- **Details**: Tree-sitter (used by VS Code, Neovim, GitHub) is the de facto AST parsing standard. RepoMaster constructs function-call graphs, module-dependency graphs, and hierarchical code trees. The structural implication: clear module boundaries and explicit exports are prerequisites for quality code graphs.

---

## Gaps

- **Agent-specific layout benchmarks**: No published controlled study comparing "agent performance on well-organized project" vs. "agent performance on disorganized project" with identical code. The 80%-tokens-on-navigation figure is a single practitioner observation.
- **Polyrepo .cursorignore patterns**: Search returned architectural comparisons but no specific `.cursorignore` file examples for polyrepo setups.
- **Stripe/Meta prescriptive standards documents**: Both companies' engineering blogs describe tooling (Sapling, Buck2, Glean) but not published style guide documents for directory layout specifically.
- **Database file anti-patterns**: Limited data on real-world consequences of placing SQLite files at project root vs. proper data directories beyond the XDG spec guidance.
- **Windows path-length consequences**: The 259-char path limit for Windows builds was mentioned but not deeply researched as an agent-specific problem.

---

## Source Tally

| Metric | Count |
|---|---|
| Queries executed | 36 |
| Results scanned | ~360 (10 per query) |
| Sources cited | 33 |
| Topics with gaps | 5 |

---

## Key Sources Index

| # | Source | URL |
|---|---|---|
| 1 | deployhq.com — AI Config Files Guide | https://www.deployhq.com/blog/ai-coding-config-files-guide |
| 2 | aider.chat — Repository Map | https://aider.chat/docs/repomap.html |
| 3 | cursor.com — Agent Best Practices | https://cursor.com/blog/agent-best-practices |
| 4 | arxiv — SWE-EVO | https://www.arxiv.org/pdf/2512.18470 |
| 5 | medium — AI Coding Agent Token Waste | https://medium.com/@jakenesler/context-compression-to-reduce-llm-costs-and-frequency-of-hitting-limits-e11d43a26589 |
| 6 | anthropic.com — Agent Skills | https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills |
| 7 | docs.python-guide.org — Hitchhiker's Guide | https://docs.python-guide.org/writing/structure/ |
| 8 | HN — Config Files Scourge | https://news.ycombinator.com/item?id=24066748 |
| 9 | 12factor.net — Config | https://12factor.net/config |
| 10 | qeunit.com — Google Monorepo | https://qeunit.com/blog/how-google-does-monorepo/ |
| 11 | lobste.rs — .config convention | https://lobste.rs/s/wac58n/use_config_store_your_project_configs |
| 12 | gitignore.pro — Best Practices | https://gitignore.pro/guides/gitignore-best-practices |
| 13 | speedscale.com — Ephemeral Data | https://speedscale.com/blog/ephemeral-data/ |
| 14 | alchemists.io — XDG Spec | https://alchemists.io/articles/xdg_base_directory_specification |
| 15 | sematext.com — Log Rotation | https://sematext.com/glossary/log-rotation/ |
| 16 | git-tower.com — git filter-repo | https://www.git-tower.com/learn/git/faq/git-filter-repo |
| 17 | esmithy.net — Git Blame Preservation | https://esmithy.net/2020/08/15/preserve-git-blame-history-refactoring/ |
| 18 | augmentcode.com — AI Refactoring | https://www.augmentcode.com/tools/ai-code-refactoring-tools-tactics-and-best-practices |
| 19 | freecodecamp.org — Refactor Complex Codebases | https://www.freecodecamp.org/news/how-to-refactor-complex-codebases/ |
| 20 | knip.dev — Knip Dead Code Detector | https://knip.dev/ |
| 21 | github.com/pkolaczk/fclones | https://github.com/pkolaczk/fclones |
| 22 | augmentcode.com — Context Junk Drawer | https://www.augmentcode.com/blog/your-agents-context-is-a-junk-drawer |
| 23 | jetbrains.com — Efficient Context Management | https://blog.jetbrains.com/research/2025/12/efficient-context-management/ |
| 24 | dev.to — File Naming Conventions | https://dev.to/damiansiredev/file-naming-conventions-keep-your-project-clean-and-readable-1plk |
| 25 | freecodecamp.org — Naming Cases | https://www.freecodecamp.org/news/snake-case-vs-camel-case-vs-pascal-case-vs-kebab-case-whats-the-difference/ |
| 26 | github.com/johnbenac/cursor-watchful-headers | https://github.com/johnbenac/cursor-watchful-headers |
| 27 | particula.tech — AGENTS.md Explained | https://particula.tech/blog/agents-md-ai-coding-agent-configuration |
| 28 | augmentcode.com — Monorepo vs Polyrepo AI | https://www.augmentcode.com/learn/monorepo-vs-polyrepo-ai-s-new-rules-for-repo-architecture |
| 29 | nx.dev — AI Agent in Monorepo | https://nx.dev/blog/nx-ai-agent-skills |
| 30 | arize.com — Agent Rules Optimization | https://arize.com/blog/optimizing-coding-agent-rules-claude-md-agents-md-clinerules-cursor-rules-for-improved-accuracy/ |
| 31 | github.com/s-smits/agentic-cursorrules | https://github.com/s-smits/agentic-cursorrules |
| 32 | github.com/yamadashy/repomix | https://github.com/yamadashy/repomix |
| 33 | arxiv — Codified Context | https://arxiv.org/html/2602.20478v1 |
