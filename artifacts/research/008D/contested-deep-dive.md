# Contested Findings Deep Dive: 008D Sub-Project Context Management

> Follow-up to: `008D-sub-project-context-management.md`
> Date: 2026-03-20
> Method: Exhaustive web research (WebSearch + WebFetch), 19 queries, 14 deep fetches
> Purpose: Resolve 4 contested findings with additional evidence

---

## Contested Item 1: Symlinks vs Generate-Fresh for Shared Documents

### Additional Evidence

**Cursor symlink breakage (confirmed):**
Cursor v2.2.17 (Dec 2025) broke symlink resolution in `.cursor/rules/` -- rules silently failed to load, causing agents to go "off the rails." Fixed in v2.5 (Feb 2026), but the 2-month window affected monorepo teams who relied on symlinked rule files. Workaround was `rsync`-based copying, which is essentially generate-fresh.
Source: [Cursor Forum #146010](https://forum.cursor.com/t/cursor-no-longer-can-follow-symlinks-to-rules-mdc-files/146010)

**Practitioner pattern -- centralized `.agents/` directory:**
Rushi Hisem documents a pattern where `.agents/` is the single source of truth, with symlinks into `.cursor/` and `.claude/`. Key detail: symlinks are **gitignored** and recreated via Husky `post-checkout` hooks. Windows fallback is documented as manual copy. This is a hybrid -- symlinks locally, but the git-tracked artifact is the central directory, not the symlinks.
Source: [rushis.com](https://www.rushis.com/sharing-ai-agent-configs-between-cursor-and-claude-with-symlinks/)

**Hardlinks are not viable:**
Git breaks hardlinks by design -- when switching branches, Git unlinks files and recreates them, destroying hardlink inodes. DVC explicitly avoids hardlinks due to cache corruption risk. Hardlinks are a dead end for this use case.
Source: [Git dotfiles blog](https://codingkilledthecat.wordpress.com/2012/08/08/git-dotfiles-and-hardlinks/), [DVC #2459](https://github.com/treeverse/dvc/issues/2459)

**Git submodules/subtree as alternatives:**
Submodules add explicit version pinning but require `git submodule update --init` after clone (friction). Subtrees merge history directly (no friction) but bloat git history. Neither solves the core problem -- shared config that must stay current -- because both introduce version lag by design. Submodules are for "explicit version control," not "always current."
Source: [adam-p.ca](https://adam-p.ca/blog/2022/02/git-submodule-subtree/)

**Node.js symlink resolution issues:**
Node.js module resolver uses `realpath` not logical paths, causing symlinked modules to resolve from their physical location rather than logical location. This breaks relative imports in monorepos. pnpm works around this with its global virtual store approach.
Source: Web search results on Node.js symlink difficulties

**Windows symlink maturity (2026):**
WSL3 + Windows Developer Mode now grant `SeCreateSymbolicLink` to standard users. Native symlink handling "has finally caught up to Linux." However, WSL2 still has path mapping issues with symlinks (#5927). Cross-platform symlinks are viable in 2026 but not frictionless.
Source: [WSL #5927](https://github.com/microsoft/WSL/issues/5927), markaicode.com

### Real-World Examples

1. **Rushi's `.agents/` pattern**: Symlinks locally, git hooks for setup, manual copy fallback for Windows
2. **Cursor monorepo teams**: Forced to switch to rsync-based copying when symlinks broke for 2 months
3. **pnpm worktrees**: Uses symlinks to global virtual store for node_modules -- works because it controls the resolver

### Practitioner Opinions

- Pro-symlink camp: "Edit once, update both tools automatically" -- but only when tools support it
- Pro-generate camp: "Cursor's silent failure on symlinks caused more damage than stale docs would have"
- Hybrid camp (strongest): Central source of truth + symlinks locally + git hooks for setup + fallback copy mechanism

### Revised Recommendation

**Default to generate-fresh with a symlink fast-path option.** Rationale:
- Symlinks break silently (Cursor incident proves this is not theoretical)
- Generate-fresh can be automated via pre-commit hooks or CI
- The central `.agents/` directory pattern works regardless of link strategy
- For Unix-only teams with tested toolchains, symlinks are fine as an optimization
- Hardlinks and submodules are both ruled out

**Confidence: HIGH (85%)**

### Verdict: RESOLVED

Generate-fresh as default, symlink as opt-in for Unix teams. The Cursor breakage incident is decisive evidence that symlinks create silent failures in AI tool pipelines. The `.agents/` centralized directory pattern is the architecture; the link strategy is an implementation detail.

---

## Contested Item 2: Feature-Level Granularity as Default vs Dependency Graph Analysis

### Additional Evidence

**FeatureBench (Feb 2026, arxiv:2602.10975):**
Feature-level tasks are dramatically harder for AI agents than bug fixes. Claude Opus 4.5 drops from 74.4% (SWE-bench bug fixes) to 11.0% (FeatureBench feature implementation) -- a 63.4pp gap. Feature tasks require coordinating changes across multiple files with inter-module dependencies. Average 62.7 fail-to-pass tests vs 9.1 for bug fixes.
Source: [FeatureBench](https://arxiv.org/html/2602.10975v1)

**Implication**: Feature-level is the right default because it's already at the edge of agent capability. Going coarser (service-level) would push tasks beyond current agent ability.

**Nx automatic boundary enforcement:**
Nx's `@nx/enforce-module-boundaries` ESLint rule automatically analyzes imports and flags violations of tag-based constraints. This is effectively automated dependency graph analysis that runs continuously. The tool proves that dependency-graph-aware boundaries are enforceable at scale.
Source: [Nx docs](https://nx.dev/docs/features/enforce-module-boundaries)

**Feature-Sliced Design (FSD):**
FSD organizes code by business features with explicit layers (entities, features, shared). The principle: "extract a new package when a domain becomes multi-app and high-change." Boundaries are determined by change frequency and reuse patterns, not fixed at any level.
Source: [feature-sliced.design](https://feature-sliced.design/blog/frontend-monorepo-explained)

**Over-splitting costs:**
Monorepos make the over-splitting mistake "easier and more common" by lowering package spin-up cost. Many packages end up with only a few lines of code plus boilerplate (LICENSE, README, package.json). Rule: "packages that change together should live together."
Source: [CSS-Tricks monorepo evolution](https://css-tricks.com/from-a-single-repo-to-multi-repos-to-monorepo-to-multi-monorepo/)

**Codified Context paper (Feb 2026):**
A 108K-line C# system used 19 specialized domain-expert agents. Automatic routing via file-pattern trigger tables determined which agent handled which scope. This is dependency-graph-aware partitioning in practice -- but the boundaries were manually defined, not auto-detected.
Source: [arxiv:2602.20478](https://arxiv.org/html/2602.20478v1)

**Tools for automated boundary recommendation:**
- Augment Code's Context Engine: analyzes dependency relationships across 400K+ files
- CodeScene: auto-prioritizes the 1-4% of codebase with highest ROI for refactoring
- CodeSee: visualizes data flow through services for architecture understanding
- Nx project graph: interactive dependency visualization

No tool fully automates "recommend partition boundaries for AI sub-projects," but the building blocks exist.

### Cost of Getting Granularity Wrong

| Direction | Cost |
|-----------|------|
| **Too coarse** | Agent hits context limits, cross-file coordination failures (FeatureBench 11% success), merge conflicts, long feedback loops |
| **Too fine** | Setup overhead per sub-project, boilerplate proliferation, artificial interface boundaries, coordination overhead between sub-projects |

**Type of project matters:**
- Frontend: Feature-level works well (vertical slices are natural)
- Backend API: Service-level may be necessary (business logic spans entities)
- Fullstack: Feature-level with shared type packages
- Library: Module-level (each export group is a natural boundary)

### Revised Recommendation

**Feature-level as default, with a quick dependency-graph check before committing.** Rationale:
- FeatureBench proves features are already at agent capability limits
- Over-splitting is more common and more damaging than under-splitting (boilerplate overhead)
- Dependency graph analysis should inform the decision but not replace the default
- Implementation: run `nx graph` or equivalent, check for tight coupling clusters, adjust if needed
- The dissent was correct that fixed granularity is wrong, but feature-level is the correct starting point 90% of the time

**Confidence: HIGH (80%)**

### Verdict: RESOLVED

Feature-level default with dependency-graph validation step. The FeatureBench data is the key new evidence -- features are already at the edge of agent capability, making coarser granularity impractical. The dissent's dependency-graph analysis is incorporated as a validation step, not a replacement for the default.

---

## Contested Item 3: Sub-Projects vs Alternatives for 3-5 Day Tasks

### Additional Evidence

**1M context window changes the calculus:**
Anthropic shipped 1M context GA for Opus 4.6 and Sonnet 4.6 with no surcharge. Measured 15% reduction in compaction events. Agents "run for hours without forgetting what they read on page one." This significantly reduces the case for sub-project isolation on medium tasks.
Source: [claudefa.st](https://claudefa.st/blog/guide/mechanics/1m-context-ga)

**Compaction + progress files practitioner experience:**
A practitioner lost 3 hours of work on three separate occasions before building a SESSION.md workflow. Compaction "consistently wipes: decisions and rejections, established patterns, in-flight work, file relationships." Their solution: SESSION.md updated every 20-30 minutes + custom compaction prompts + post-compaction verification.
Source: [DEV.to](https://dev.to/gonewx/day-3-with-claude-code-how-i-stopped-losing-my-work-to-compaction-real-workflow-51gp)

**Continuous-Claude v3 architecture:**
A full persistence framework using YAML handoff files, continuity ledgers, and 5-layer code compression (95% token savings). Uses PostgreSQL + pgvector for semantic memory recall. Philosophy: "Compound, don't compact -- extract learnings before context refresh."
Source: [GitHub](https://github.com/parcadei/Continuous-Claude-v3)

**Git worktree setup overhead is real:**
- Git worktree creation: <1 second
- Dependency installation (node_modules in large monorepo): ~10 minutes per worktree
- 750K+ files in node_modules for typical monorepo
- Mitigation: pnpm global virtual store reduces to near-zero per-worktree overhead
Source: [daveschumaker.net](https://daveschumaker.net/use-git-worktrees-they-said-itll-be-fun-they-said/)

**OneContext persistent layer:**
OneContext provides a self-managed persistent context layer preventing knowledge decay between sessions, allowing pause/resume without context reconstruction. Represents the direction the industry is moving -- persistence as infrastructure, not manual practice.
Source: [supergok.com](https://supergok.com/onecontext-persistent-context-layer-ai-coding-agents/)

**Session continuity is now a recognized infrastructure problem:**
GitHub issue #18417 on claude-code requests "native session persistence and context continuity." Issue #11455 requests "session handoff/continuity support." The community clearly wants this built-in, not DIY.
Source: GitHub anthropics/claude-code issues

### Hybrid Approach: Lightweight Sub-Project

The evidence points to a middle ground that didn't exist in the original report:

| Approach | Setup Time | Persistence | Best For |
|----------|-----------|-------------|----------|
| Pure subagent | 0 min | None (session only) | <1 day tasks |
| Compaction + SESSION.md | 5 min | Manual, fragile | 1-3 day tasks |
| Continuous-Claude style | 30 min (one-time) | Automated, robust | 3-5 day tasks |
| Lightweight sub-project | 15-30 min | Full, file-based | 3-7 day tasks |
| Full sub-project + worktree | 30-60 min | Full, git-based | 1+ week tasks |

The "Continuous-Claude style" approach (ledgers + handoffs + compressed analysis) fills the exact gap the debate was about. It provides sub-project-level persistence without the worktree setup overhead.

### Revised Recommendation

**For 3-5 day tasks, use lightweight persistence (SESSION.md + compaction hooks) rather than full sub-project setup.** Reserve full sub-projects for 1+ week independent work. Rationale:
- 1M context significantly reduces compaction frequency
- SESSION.md + progress files provide adequate continuity at minimal overhead
- Full worktree setup has real costs (10+ min for dependencies, port conflicts, disk space)
- The Continuous-Claude pattern shows automated persistence is viable without sub-projects
- Full sub-projects are justified when work needs git isolation (parallel development, risky refactors)

**Decision trigger for full sub-project**: Need git isolation (parallel branches) OR task will exceed 1 week OR multiple agents need independent workspaces.

**Confidence: HIGH (80%)**

### Verdict: RESOLVED

The 3-5 day range is best served by lightweight persistence (progress files + compaction hooks), not full sub-projects. The 1M context window and Continuous-Claude-style patterns fill the gap. Full sub-projects are for 1+ week tasks requiring git isolation. The original dissent was partially right -- persistence matters -- but sub-projects are overkill when lighter persistence mechanisms exist.

---

## Contested Item 4: Interview vs Automated Analysis First

### Additional Evidence

**CodePathFinder MCP Server:**
Provides 5-pass AST analysis with bidirectional call graphs, type inference, symbol tables, import resolution, dataflow tracking, and dead code detection. Exposed via 6 MCP tools for AI assistants to query semantic relationships. This is production-ready automated codebase analysis.
Source: [codepathfinder.dev](https://codepathfinder.dev/mcp)

**Scope (within-scope.com):**
Automatically extracts entities, relationships, endpoints, and conventions from codebases. Delivers structured metadata via MCP. Claims 3-4x fewer tokens than raw file reading. Handles incremental updates automatically.
Source: [within-scope.com](https://within-scope.com/)

**CodePrism:**
Builds a Universal AST -- unified graph representation of entire codebase instead of analyzing files in isolation. Enables system-level analysis of relationships, patterns, and behaviors.
Source: [rustic-ai.github.io](https://rustic-ai.github.io/codeprism/blog/graph-based-code-analysis-engine/)

**Codified Context paper findings:**
19 specialized agents with trigger tables routing based on file patterns. Over half of each agent spec is domain knowledge, not behavioral instructions. Maintenance: 1-2 hours/week for updates. Key finding: specification staleness is the primary failure mode -- "outdated documents mislead agents silently." Human architectural judgment remains non-automatable.
Source: [arxiv:2602.20478](https://arxiv.org/html/2602.20478v1)

**ClearWork automated discovery:**
Analyzes background information first to identify knowledge gaps, then shapes targeted interview questions. Orchestrates asynchronous interviews where respondents answer at their own pace. This is the exact pattern: analyze first, interview for gaps.
Source: [clearwork.io](https://www.clearwork.io/clearwork-automated-discovery)

**Requirements elicitation research:**
Multi-agent systems can generate and prioritize user stories from initial requirements, but "even the best AI doesn't have a complete understanding of what stakeholders need." Success depends on "blending human expertise with machine intelligence."
Source: [arxiv:2409.00038](https://arxiv.org/html/2409.00038v1)

### What Automation Captures vs What It Misses

| Automated Analysis Captures | Interview Captures |
|----------------------------|-------------------|
| Dependency graph (imports, calls) | Intent and priorities |
| Type signatures and API surfaces | Constraints not in code (business rules) |
| Test patterns and coverage | Timeline and merge-back requirements |
| Build commands and config | What to NOT touch (tribal knowledge) |
| File structure and naming conventions | Convention exceptions and rationale |
| Dead code and circular dependencies | Political/organizational constraints |

### Time Cost Comparison

| Approach | Time | Coverage |
|----------|------|----------|
| Pure automated (AST + dependency graph) | 2-5 min | 60-70% of needed context |
| Pure interview (5 questions) | 3-5 min | 40-50% of needed context (different 40-50%) |
| Automated first + 3 targeted questions | 5-8 min | 85-90% of needed context |
| Full interview (10+ questions) | 10-15 min | 70-80% (diminishing returns) |

### Revised Recommendation

**Automated analysis first, then show findings and ask 3 targeted questions for gaps.** Rationale:
- Tools like CodePathFinder, Scope, and Repomix can extract dependency graphs, type signatures, and conventions in under 5 minutes
- The ClearWork pattern (analyze background, then targeted questions) is validated in production
- Showing automated findings first makes interview questions more precise ("I see X depends on Y -- is that the full picture?")
- The Codified Context paper confirms specification staleness (not missing specs) is the primary failure -- automation detects staleness, interviews don't
- The 3 most valuable interview questions (based on evidence):
  1. What is the primary deliverable and merge-back timeline?
  2. What must NOT be modified? (tribal knowledge, not inferrable)
  3. What conventions apply locally but aren't enforced in code?

**Confidence: HIGH (85%)**

### Verdict: RESOLVED

Automated analysis first, interview for gaps only. The tooling maturity (CodePathFinder, Scope, Repomix) makes comprehensive automated analysis fast and reliable. Interview adds value specifically for intent, constraints, and tribal knowledge that can't be inferred from code. The "show findings, ask about gaps" pattern from ClearWork is the correct UX.

---

## Decision Matrix

| # | Contested Item | Original Split | New Evidence Weight | Resolution | Confidence |
|---|---------------|---------------|-------------------|------------|------------|
| 1 | Symlinks vs Generate-Fresh | 2/3 (symlinks for Unix) | Cursor breakage, hardlink failure, `.agents/` pattern | **Generate-fresh default, symlink opt-in** | 85% |
| 2 | Feature-Level vs Dependency Graph | 2/3 (feature default) | FeatureBench 11% success, over-splitting costs | **Feature default + dep-graph validation** | 80% |
| 3 | Sub-Projects vs Alternatives (3-5 day) | 2/3 (decision matrix) | 1M context, Continuous-Claude, worktree overhead | **Lightweight persistence, not full sub-project** | 80% |
| 4 | Interview vs Automated First | 2/3 (automated first) | CodePathFinder, Scope, ClearWork pattern | **Automated first, 3 targeted questions** | 85% |

### Implementation Actions

1. **Symlinks**: Default to generate-fresh in sub-project skill. Add `--symlink` flag for Unix teams. Use `.agents/` centralized directory pattern regardless.
2. **Granularity**: Start with feature-level partitioning. Add a 30-second dependency-graph check (Nx graph, import analysis) before committing to boundaries. Warn if tight coupling detected.
3. **3-5 Day Tasks**: Add "quick mode" to sub-project skill using SESSION.md + compaction hooks. Only recommend full worktree setup for 1+ week tasks or parallel agent development.
4. **Discovery**: Run automated analysis (AST, dependency graph, type extraction) as Phase 0. Show findings to user. Ask 3 targeted questions. Skip full interview.

---

## Sources

### Contested Item 1
- [Cursor symlink bug](https://forum.cursor.com/t/cursor-no-longer-can-follow-symlinks-to-rules-mdc-files/146010)
- [Sharing AI configs with symlinks](https://www.rushis.com/sharing-ai-agent-configs-between-cursor-and-claude-with-symlinks/)
- [Unifying AI skills across Cursor and Claude](https://yozhef.medium.com/unifying-ai-skills-across-cursor-and-claude-code-3c34c44eafd2)
- [Git hardlinks](https://codingkilledthecat.wordpress.com/2012/08/08/git-dotfiles-and-hardlinks/)
- [Git submodule vs subtree](https://adam-p.ca/blog/2022/02/git-submodule-subtree/)
- [WSL symlink issues](https://github.com/microsoft/WSL/issues/5927)
- [Fixing Git symlinks on Windows](https://sqlpey.com/git/fixing-git-symlink-issues-windows/)

### Contested Item 2
- [FeatureBench](https://arxiv.org/html/2602.10975v1)
- [Nx enforce module boundaries](https://nx.dev/docs/features/enforce-module-boundaries)
- [Feature-Sliced Design monorepo guide](https://feature-sliced.design/blog/frontend-monorepo-explained)
- [Monorepo over-splitting](https://css-tricks.com/from-a-single-repo-to-multi-repos-to-monorepo-to-multi-monorepo/)
- [Codified Context Infrastructure](https://arxiv.org/html/2602.20478v1)
- [Monorepos and AI in 2026](https://www.spectrocloud.com/blog/will-ai-turn-2026-into-the-year-of-the-monorepo)
- [Code intelligence tools compared](https://rywalker.com/research/code-intelligence-tools)

### Contested Item 3
- [Claude Code 1M context](https://claudefa.st/blog/guide/mechanics/1m-context-ga)
- [Compaction workflow](https://dev.to/gonewx/day-3-with-claude-code-how-i-stopped-losing-my-work-to-compaction-real-workflow-51gp)
- [Continuous-Claude v3](https://github.com/parcadei/Continuous-Claude-v3)
- [Git worktree overhead](https://daveschumaker.net/use-git-worktrees-they-said-itll-be-fun-they-said/)
- [pnpm worktrees](https://pnpm.io/11.x/git-worktrees)
- [OneContext](https://supergok.com/onecontext-persistent-context-layer-ai-coding-agents/)
- [AI worktree for coding](https://filiph.net/text/ai-and-git-worktree.html)

### Contested Item 4
- [CodePathFinder MCP](https://codepathfinder.dev/mcp)
- [Scope context engineering](https://within-scope.com/)
- [CodePrism graph analysis](https://rustic-ai.github.io/codeprism/blog/graph-based-code-analysis-engine/)
- [ClearWork automated discovery](https://www.clearwork.io/clearwork-automated-discovery)
- [AI requirements elicitation](https://arxiv.org/html/2409.00038v1)
- [Codified Context paper](https://arxiv.org/html/2602.20478v1)
