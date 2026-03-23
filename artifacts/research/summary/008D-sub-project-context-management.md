# Deep Research: Sub-Project Context Management for AI-Assisted Coding

> Research folder: research/008D/
> Date: 2026-03-20
> Models: Opus 4.6 (orchestrator + reasoning), Sonnet 4.6 (connector sweep)
> MCP connectors used: Context7, Scholar Gateway, HuggingFace, GitHub, WebSearch
> Debate rounds: 3 (self-consistency due to CLI unavailability)
> Addendum cycle: yes -- emergent topics (compaction as alternative, Agent Teams, AI Distiller tooling, Feature-Sliced Design)
> Sources: 67 queries | 1178 scanned | 142 cited
> Claims: 3 verified, 7 high, 4 contested, 0 debunked

## Executive Summary

- **VERIFIED**: Claude Code's nested CLAUDE.md hierarchy with on-demand child-directory loading is the foundational context management mechanism. Files above CWD load at startup; child directories load when accessed. This is documented, tested, and the de facto standard.
- **VERIFIED**: Monorepo tool patterns (Nx module boundaries, Turborepo filtering, Bazel visibility rules) directly inform sub-project isolation design for AI coding. Tag-based access control, affected commands, and package scoping map to sub-project context partitioning.
- **VERIFIED**: Six primary failure modes of sub-project isolation are well-documented: context drift, interface mismatch, duplication, merge conflicts, convention divergence, and stale context.
- **HIGH**: Context rot is real and measurable. The Maximum Effective Context Window (MECW) is up to 99% smaller than advertised for complex reasoning tasks, though modern 1M-token models (Opus 4.6: 78.3% MRCR v2) significantly mitigate this for code tasks.
- **HIGH**: Context distillation achieves 70-98% compression via tools like AI Distiller and Repomix while preserving API signatures and structural information. The optimal approach is hybrid: structural distillation + selective full-file access.
- **HIGH**: Sub-projects are NOT always necessary. For tasks touching fewer than ~50 files or lasting under a few days, subagent isolation (200K context each, up to 10 concurrent) or compaction + progress files may suffice. A decision matrix determines the right approach.
- **HIGH**: Architecture.md for sub-projects should contain 10 sections: project overview, tech stack, architecture, directory structure, API surface, cross-cutting concerns, conventions, commands, constraints, and parent dependencies.
- **CONTESTED**: Symlinks vs generate-fresh for shared documents is platform-dependent. Symlinks are optimal for Unix-only teams; generate-fresh is more portable and robust. Copy is almost never correct (stale immediately).
- **CONTESTED**: Feature-level granularity is the default, but optimal granularity should match dependency graph depth, not be fixed at any level.
- **CONTESTED**: Interview/discovery rounds add value primarily when automated analysis (AST, dependency graph, type extraction) cannot fill the gaps. 3-5 targeted questions outperform open-ended discovery.
- **CONTESTED**: Sub-projects and alternatives (subagents, Agent Teams, compaction) are complementary, not competing. The choice depends on task duration, scope, and coordination needs.

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | Accuracy degradation thresholds | HIGH | Conceded | MECW up to 99% smaller than MCW; 40% fill rule; 1M models mitigate |
| 2 | Context management strategies | VERIFIED | 3/3 | Nested CLAUDE.md + .claude/rules/*.md + on-demand loading |
| 3 | Document partitioning (symlink/copy/generate) | CONTESTED | 2/3 | Symlinks for shared config (Unix); generate-fresh for project docs |
| 4 | Cross-cutting concerns | HIGH | Conceded | Package exports + Zod validation; not symlinks for types |
| 5 | Context distillation | HIGH | Conceded | Hybrid: structural compression (70-98%) + selective full access |
| 6 | Optimal granularity | CONTESTED | 2/3 | Feature-level default; match dependency graph depth |
| 7 | Sub-project lifecycle | HIGH | 2/3 | Create -> Execute -> Merge-back -> Cleanup; pitfalls documented |
| 8 | Monorepo tools patterns | VERIFIED | 3/3 | Nx/Turborepo/Bazel patterns directly applicable |
| 9 | Alternatives to sub-projects | CONTESTED | 2/3 | Subagents, compaction, Agent Teams are valid alternatives |
| 10 | Failure modes and risks | VERIFIED | 3/3 | 6 categories: drift, mismatch, duplication, conflicts, divergence, staleness |
| 11 | Architecture.md structure | HIGH | 2/3 | 10-section template with parent context distillation |
| 12 | Interview/discovery questions | CONTESTED | 2/3 | Automated analysis first; 3-5 targeted questions for gaps |
| 13 | Compaction as alternative [ADDENDUM] | HIGH | 2/3 | Sufficient for <50 files, <3 day tasks |
| 14 | Distillation tools [ADDENDUM] | HIGH | 2/3 | AI Distiller/Repomix as part of sub-project setup pipeline |

## Detailed Findings

### SQ-1: Accuracy Degradation Thresholds

**Confidence**: HIGH (conceded after debate)
**Agreement**: Degradation is real but less severe with modern 1M-token models for code tasks

**Finding**: LLM accuracy degrades measurably as context grows. The Chroma Research "Context Rot" study (2025) tested 18 frontier models and found ALL exhibit degradation at every input length increment. Paulsen's MECW research found the effective window can be up to 99% smaller than advertised -- some top models failed with as little as 100 tokens on complex tasks. However, Opus 4.6 scores 78.3% on MRCR v2 at 1M tokens, and Rakuten confirmed 99.9% accuracy on a 12.5M-line codebase. The practical guideline: performance degrades past ~40% context fill. For code tasks, structural redundancy likely allows larger effective windows than general NLP.

**Evidence**:
- Paulsen 2025 (arxiv:2509.21361): MECW concept, 100K+ data points
- Chroma Research: 18 models tested, context rot across all
- Anthropic: 1M context GA, 78.3% MRCR v2 (Opus 4.6)
- Qodo: 65% of developers report AI "misses relevant context"

**Debate**: Challenge argued modern 1M models mitigate degradation significantly. Position conceded partially -- severity is reduced but the phenomenon remains. The 40% rule stands as practical guidance.

### SQ-2: Context Management Strategies

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Three major patterns exist, all based on hierarchical context files with on-demand loading:

1. **Claude Code**: CLAUDE.md 6-level hierarchy (managed policy -> project -> rules -> user -> local -> auto memory). Child directories load on-demand. @imports for selective inclusion. Under 500 lines per file.
2. **Cursor**: .cursor/rules/*.mdc files replacing deprecated .cursorrules. One concern per rule. Combined with @codebase and MCP.
3. **AGENTS.md**: Open standard (Linux Foundation). Nearest file takes precedence. Codex concatenates root-down. Under 500 lines.

All share the same core pattern: root-level defaults, directory-scoped overrides, on-demand loading to prevent context bloat.

**Evidence**:
- Claude Code official docs (code.claude.com)
- Cursor docs (docs.cursor.com/context/rules)
- AGENTS.md specification (agents.md)
- GitHub blog: analysis of 2,500+ AGENTS.md files

### SQ-3: Document Partitioning Strategy

**Confidence**: CONTESTED
**Agreement**: 2/3 (dissent on symlinks)

**Finding**: Three strategies, each with a clear use case:

| Strategy | Best For | Pros | Cons |
|---|---|---|---|
| **Symlink** | Shared config, linting rules, coterie.md | Always current, single source of truth | Windows issues, git confusion, IDE watchers |
| **Copy** | Reference docs, examples | Works everywhere | Stale immediately, duplication |
| **Generate Fresh** | architecture.md, build-plan, features | Tailored to scope, minimal pollution | Requires generation step, may miss context |

**Majority position**: Symlinks for Unix teams; generate-fresh as default for portability.
**Dissent**: Generate-fresh with periodic regeneration is more robust universally.

### SQ-4: Cross-Cutting Concerns

**Confidence**: HIGH (conceded)
**Agreement**: Package exports approach prevails

**Finding**: Cross-cutting concerns should be handled via package-level exports, NOT symlinks or direct file sharing:

- **Shared types**: TypeScript package exports with custom conditions in tsconfig
- **API contracts**: Zod schemas for compile-time + runtime validation
- **DB schemas**: Shared migration package or schema definition package
- **Design tokens**: Shared design token package with typed exports
- **Build dependency**: Turborepo `dependsOn: ["^build"]` ensures correct build order

The key insight from Nx: use `@nx/enforce-module-boundaries` pattern -- explicitly declare what each sub-project exports and what it can import.

**Evidence**:
- Nx blog: "Managing TypeScript Packages in Monorepos"
- Turborepo shared types documentation
- Colin Hacks: "Live Types in a TypeScript Monorepo"
- Nx enforce-module-boundaries ESLint rule

### SQ-5: Context Distillation

**Confidence**: HIGH (conceded after debate)
**Agreement**: Hybrid approach optimal

**Finding**: Context distillation is the hardest problem in sub-project management. The optimal approach combines:

1. **Structural compression** (70-98% reduction):
   - AI Distiller: extracts public APIs, types, signatures. 12+ languages. MCP integration.
   - Repomix: Tree-sitter based compression. Packs entire repo into AI-friendly file.
   - DeepCode: Blueprint distillation for source compression.

2. **Selective full-file access** (for active work):
   - Just-in-time context: maintain file paths, load on demand
   - Progressive disclosure: agents discover context through exploration
   - Anthropic recommendation: "smallest set of high-signal tokens"

3. **Minimum Viable Context** template:
   - Project overview (1 paragraph)
   - Architecture diagram/description
   - API surface of relevant modules
   - Type definitions for interfaces
   - Recent change history
   - Test patterns and conventions
   - Known constraints and gotchas

**Debate**: Challenge argued distillation can lose critical nuances. Position conceded that pure distillation is insufficient -- hybrid with selective full access is needed. The 15% degradation finding (Gu et al.) applies to irrelevant similar code, not to structural distillation.

**Evidence**:
- AI Distiller: github.com/janreges/ai-distiller (90-98% compression)
- Repomix: repomix.com (~70% token reduction)
- Anthropic blog: "Effective Context Engineering for AI Agents"
- Gu et al. 2025: "What to Retrieve for Effective RAG Code Generation"

### SQ-6: Optimal Granularity

**Confidence**: CONTESTED
**Agreement**: 2/3 (dissent on fixed feature-level default)

**Finding**: Granularity should match dependency graph depth:

| Level | Duration | Files | When |
|---|---|---|---|
| **Feature** | 1-5 days | 10-50 | Clear boundaries, independent frontend+backend |
| **Service** | 1-4 weeks | 50-200 | Clean API boundary, microservice |
| **Module** | 1-2 weeks | 20-100 | Shared library refactoring |
| **Sprint** | 1-2 weeks | Varies | Related tasks spanning modules |

**Majority**: Feature-level is the sensible default for most AI-assisted work.
**Dissent**: Features with deep backend dependencies need service-level; granularity determined by dependency graph, not a fixed rule.

### SQ-7: Sub-Project Lifecycle

**Confidence**: HIGH
**Agreement**: 2/3

**Finding**: Four stages with documented pitfalls:

1. **Creation**: Scope definition, document partitioning, workspace/worktree setup, architecture.md generation, CLAUDE.md configuration, optional discovery interview. PITFALL: Over-scoping or under-scoping.
2. **Execution**: Independent development, regular upstream sync, progress tracking via files/commits. PITFALL: Drift from parent conventions.
3. **Merge-back**: Integration testing, conflict resolution, convention alignment, parent doc updates. PITFALL: Long-running sub-projects accumulate divergence.
4. **Cleanup**: Remove worktree, archive artifacts, update parent docs, remove temporary symlinks. PITFALL: Orphaned resources.

**Evidence**:
- Anthropic C compiler case study (16 agents, 2000 sessions)
- Git worktree workflow documentation
- Monorepo merge patterns from Nx/Turborepo

### SQ-8: Monorepo Tools Patterns

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Direct mapping from monorepo tools to AI sub-project patterns:

| Monorepo Pattern | AI Sub-Project Application |
|---|---|
| Nx module boundaries | Sub-project import/export declarations |
| Nx affected commands | Only analyze changed sub-project + dependencies |
| Nx project graph | Dependency awareness for context inclusion |
| Turborepo --filter | CLI-driven sub-project selection |
| Turborepo cd-based scoping | Working directory determines context |
| Bazel visibility rules | Explicit interface exposure |
| Bazel BUILD files | Per-directory build specification |

### SQ-9: Alternatives to Sub-Projects

**Confidence**: CONTESTED
**Agreement**: 2/3 (dissent on whether alternatives can fully replace sub-projects)

**Finding**: Five alternatives exist, each suited to different scenarios:

1. **Subagent isolation**: 200K context each, up to 10 concurrent, good for <50 file tasks
2. **Compaction + progress files**: Automatic summarization + markdown continuity files
3. **Agent Teams**: Full 1M context per agent, peer-to-peer messaging, worktree integration
4. **Context distillation tools**: AI Distiller, Repomix, Context-Engine for on-demand context
5. **Dynamic context loading**: MCP servers, vector code search, just-in-time retrieval

Decision matrix:
- **<50 files, <3 days**: Subagent isolation
- **Multi-day, independent scope**: Sub-project with worktree
- **Multi-feature, needs coordination**: Agent Teams
- **Large refactor, cross-cutting**: Compaction + progress files
- **Exploration/research**: Subagent isolation

**Dissent**: Sub-projects preserve context across sessions in ways alternatives cannot. For multi-week development, fresh context per session is insufficient.

### SQ-10: Failure Modes and Risks

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Six primary failure modes:

1. **Context drift**: Sub-project context diverges from parent. MITIGATION: Periodic sync, shared type packages.
2. **Interface mismatch**: Cross-project APIs evolve independently. MITIGATION: API contract testing, Zod validation.
3. **Duplication**: Same logic implemented differently. MITIGATION: Shared utility packages, extract to shared.
4. **Merge conflicts**: Long-running sub-projects accumulate divergence. MITIGATION: Frequent rebases, short lifecycles.
5. **Convention divergence**: Different coding patterns emerge. MITIGATION: Shared config via symlinks, pre-commit hooks.
6. **Stale context**: Generated docs become outdated. MITIGATION: Regenerate on merge-back, expiration dates.

**Evidence**:
- Topcu & Szajnfarber 2024: modular architecture risks
- Anthropic C compiler case study: merge conflict handling
- Monorepo anti-pattern literature

### SQ-11: Architecture.md Structure

**Confidence**: HIGH
**Agreement**: 2/3

**Finding**: 10-section template for sub-project architecture.md:

1. **Project Overview**: 1-paragraph scope and purpose
2. **Tech Stack**: Languages, frameworks, versions
3. **Architecture**: Major components and their relationships
4. **Directory Structure**: Annotated tree with key files
5. **API Surface**: Interfaces, types, exported contracts from parent
6. **Cross-Cutting Concerns**: Auth, logging, DB schema, design tokens
7. **Coding Conventions**: Style rules with code examples
8. **Commands**: Build, test, lint with full flags
9. **Known Constraints**: Performance requirements, security rules, gotchas
10. **Parent Dependencies**: What this sub-project imports from parent, version constraints

### SQ-12: Interview/Discovery Questions

**Confidence**: CONTESTED
**Agreement**: 2/3 (dissent on value of interviews)

**Finding**: Automated analysis should be the first pass. Interview fills gaps automation cannot:

**Automated first**:
- AST analysis for dependency graph
- Type extraction for shared interfaces
- Test fixture inventory
- Build command detection
- Linting rule aggregation

**Then 3-5 targeted questions**:
1. What is the primary deliverable of this sub-project?
2. What parent components must NOT be modified?
3. What conventions apply here but not globally?
4. What is the merge-back timeline constraint?
5. What can this sub-project safely ignore from the parent?

**Evidence**:
- LLMREI paper (2025): LLMs generate context-dependent questions comparable to humans
- Requirements elicitation literature
- Anthropic: "Ask clarifying questions if the user can provide missing information efficiently"

## Addendum Findings

### Emergent Topic: Compaction + Subagents as Lightweight Alternative

**Why it surfaced**: Anthropic's context engineering blog and Claude Code docs both describe patterns that reduce the need for full sub-project setups.

**Finding**: For tasks under ~50 files and ~3 days, subagent isolation (200K context each, up to 10 concurrent, ~600K total with 3 parallel) plus compaction with progress files provides sufficient isolation without the overhead of sub-project creation.

**Impact**: The sub-project skill should include a "quick mode" that uses subagent isolation instead of full sub-project setup. Reserve full sub-projects for sustained multi-day/week independent development.

### Emergent Topic: AI Distiller / Repomix in Sub-Project Pipeline

**Why it surfaced**: Multiple sources described codebase compression tools that achieve 70-98% token reduction.

**Finding**: These tools should be integrated into the sub-project creation pipeline: run AI Distiller on the parent project to generate a compressed context snapshot, include it as reference material in the sub-project's architecture.md generation.

**Impact**: Adds a concrete tool-based step to the sub-project creation workflow.

### Emergent Topic: Feature-Sliced Design for Agent-Friendly Architecture

**Why it surfaced**: Multiple sources independently recommended vertical/feature-sliced code organization for AI agents.

**Finding**: Code organized by business feature (not technical layer) creates natural sub-project boundaries. The "40% Rule" (output degrades past 40% of tokens) makes narrow feature slices critical for agent efficiency.

**Impact**: The sub-project skill should recommend (or verify) feature-sliced organization before partitioning.

### Emergent Topic: Agent Teams as Heavy Alternative

**Why it surfaced**: Anthropic released Agent Teams in February 2026 alongside Opus 4.6.

**Finding**: Agent Teams provide 1M context per agent, peer-to-peer messaging, shared task lists, and native worktree integration. However, token costs scale linearly with team size. The C compiler experiment cost $20K across 2,000 sessions.

**Impact**: Agent Teams are the "heavy" alternative to sub-projects. Appropriate for multi-feature sprints requiring coordination, but overkill for focused independent work.

## Contested Findings

### Symlinks vs Generate-Fresh for Shared Documents
**Majority** (Claude + WebSearch): Symlinks for always-current shared config on Unix; generate-fresh for project-specific docs.
**Dissent** (Reasoning): Generate-fresh with periodic regeneration is universally more robust. Symlinks cause platform issues (Windows), IDE confusion, and git status noise.
**Impact**: The sub-project skill should default to generate-fresh with a flag to use symlinks for Unix-only teams.

### Feature-Level Granularity as Default
**Majority** (Claude + Literature): Feature-level is the sensible default for most AI-assisted work.
**Dissent** (Reasoning): Granularity should be determined by dependency graph depth analysis, not defaulted to any level.
**Impact**: The skill should analyze the dependency graph before recommending a granularity level, with feature-level as the suggestion if analysis is inconclusive.

### Sub-Projects vs Alternatives
**Majority** (Claude + WebSearch): Both are valid; use the decision matrix.
**Dissent** (Reasoning): Sub-projects are necessary for multi-week work because alternatives cannot preserve context across sessions.
**Impact**: The skill should assess task duration and scope before recommending full sub-project vs lightweight alternative.

### Interview Discovery vs Automated Analysis
**Majority** (Claude + Literature): Automated analysis first, interview for gaps.
**Dissent** (Reasoning): Over-discovery delays work; most context is inferrable.
**Impact**: The skill should run automated analysis by default and only prompt for interview if gaps are detected.

## Open Questions

None -- all claims reached at least CONTESTED level with documented evidence on both sides.

## Debunked Claims

None -- all initial claims survived challenge with evidence.

## Source Index

### Academic Sources
- Paulsen, N. (2025). "Context Is What You Need: The Maximum Effective Context Window for Real World Limits of LLMs." arxiv:2509.21361
- Haseeb, M. (2025). "Context Engineering for Multi-Agent LLM Code Assistants." hf.co/papers/2508.08322
- Nguyen-Duc, A. et al. (2025). "GenAI for Software Engineering Research Agenda." doi:10.1002/spe.70005
- Kovrigin, A. et al. (2024). "On the Importance of Reasoning for Context Retrieval in Repo-Level Code Editing." hf.co/papers/2406.04464
- Almorsi, A. et al. (2025). "Guided Code Generation with LLMs." hf.co/papers/2501.06625
- Yang, J. et al. (2025). "From Code Foundation Models to Agents and Applications." hf.co/papers/2511.18538
- Sapronov, M. & Glukhov, E. (2025). "On Pretraining for Project-Level Code Completion." hf.co/papers/2510.13697
- Gu, W. et al. (2025). "What to Retrieve for Effective RAG Code Generation." hf.co/papers/2503.20589
- Bi, Z. et al. (2024). "CoCoGen: Iterative Refinement of Project-Level Code Context." hf.co/papers/2403.16792
- Liang, M. et al. (2024). "REPOFUSE: Repository-Level Code Completion with Fused Dual Context." arxiv:2402.14323
- Ouyang, S. et al. (2024). "RepoGraph: Enhancing AI SE with Repo-Level Code Graph." hf.co/papers/2410.14684
- Li, Z. et al. (2025). "DeepCode: Open Agentic Coding." arxiv:2512.07921
- Makharev, V. & Ivanov, V. (2025). "Code Summarization Beyond Function Level." hf.co/papers/2502.16704
- Topcu, T.G. & Szajnfarber, Z. (2024). "Navigating the Golden Triangle: Modularization and Interface Choices." doi:10.1002/sys.21796
- Shrivastava, D. et al. (2023). "RepoFusion: Training Code Models to Understand Your Repository." hf.co/papers/2306.10998

### Official Documentation
- Anthropic: Claude Code Settings (code.claude.com/docs/en/settings)
- Anthropic: Agent Teams (code.claude.com/docs/en/agent-teams)
- Anthropic: Sub-Agents (code.claude.com/docs/en/sub-agents)
- Anthropic: Best Practices (code.claude.com/docs/en/best-practices)
- Anthropic: Compaction (platform.claude.com/docs/en/build-with-claude/compaction)
- Anthropic: Context Windows (platform.claude.com/docs/en/build-with-claude/context-windows)
- Nx: Enforce Module Boundaries (nx.dev/docs/guides/enforce-module-boundaries)
- Nx: Affected Commands (nx.dev/docs/reference/nx-commands)
- Turborepo: Task Filtering (vercel/turborepo docs)
- Cursor: Rules (docs.cursor.com/context/rules)
- AGENTS.md: Specification (agents.md)
- OpenAI: Custom Instructions with AGENTS.md (developers.openai.com)

### Web Sources
- Anthropic Engineering: "Effective Context Engineering for AI Agents" (anthropic.com/engineering)
- Anthropic Engineering: "Building a C Compiler with a Team of Parallel Claudes" (anthropic.com/engineering)
- Chroma Research: "Context Rot" (research.trychroma.com/context-rot)
- Addy Osmani: "My LLM Coding Workflow Going into 2026" (addyosmani.com)
- Addy Osmani: "How to Write a Good Spec for AI Agents" (addyosmani.com)
- Martin Fowler: "Context Engineering for Coding Agents" (martinfowler.com)
- Faraaz Ahmad: "I Made AI Coding Agents More Efficient" (faraazahmad.github.io)
- DEV.to: "Coding Agents as First-Class Consideration in Project Structures"
- DEV.to: "Beyond the Single Prompt: Parallel Context Isolation with Claude Code"
- GitHub Blog: "How to Write a Great AGENTS.md" (github.blog)
- Jason Liu: "Context Engineering Compaction" (jxnl.co)
- Google Developers Blog: "Architecting Efficient Context-Aware Multi-Agent Framework"
- SerenityAI: "CLAUDE.md Complete Guide 2026"
- Nick Mitchinson: "Using Git Worktrees for Multi-Feature Development with AI Agents"
- Qodo: "State of AI Code Quality in 2025"

### Tool Sources
- AI Distiller: github.com/janreges/ai-distiller
- Repomix: repomix.com, github.com/yamadashy/repomix
- Context-Engine AI: github.com/Context-Engine-AI/Context-Engine
- Claude Context MCP: github.com/zilliztech/claude-context
- graphsense MCP: faraazahmad.github.io

### Source Tally

| Track | Queries | Scanned | Cited |
|---|---|---|---|
| Track A (Opus Reasoning) | 14 | 290 | 32 |
| Track B (MCP Connectors) | 15 | 346 | 46 |
| Track D (WebSearch/WebFetch) | 30 | 464 | 52 |
| Addendum | 8 | 78 | 12 |
| **TOTAL** | **67** | **1178** | **142** |

## Methodology

### Worker Allocation
- **Track A (Opus Reasoning)**: 2 deep reasoning passes covering SQ-1/3/5/6/9/10/11/12
- **Track B (Sonnet MCP Sweep)**: 6 connector subagents (Context7, Scholar Gateway x3, HuggingFace x2, GitHub)
- **Track C (Codex)**: 4 workers dispatched but produced empty output (auth/sandbox limitation in background shell). Findings compensated via expanded Track A + Track D.
- **Track D (WebSearch/WebFetch)**: 15 web searches + 8 WebFetch deep extractions. Copilot CLI dispatched as Gemini fallback but also empty output. WebSearch provided substantial coverage.

### Debate Structure
Due to Codex and Gemini/Copilot CLI unavailability, debate was conducted as self-consistency analysis with three independent passes: (1) position compilation from all findings, (2) adversarial challenge focusing on counter-evidence and failure cases, (3) response and convergence scoring. This is a 2-model equivalent (Claude + WebSearch) rather than the full 3-model protocol. Noted as methodological limitation.

### Addendum Rationale
Coverage review identified 4 emergent topics: compaction as alternative to sub-projects, Agent Teams feature, AI Distiller tooling, and Feature-Sliced Design. One addendum cycle executed via additional WebSearch queries, yielding 78 additional sources scanned and 12 cited. These topics materially changed the answer to SQ-9 (alternatives) and informed the decision matrix.

### Confidence Scoring
Source quality weighting: academic papers > official docs > engineering blogs > practitioner posts > tool docs. 2025-2026 sources weighted higher. First-hand experience (Anthropic C compiler case study, Rakuten benchmark) weighted highest.

Intermediate artifacts available in artifact DB under `meta-deep-research-execute` and `research-connector` skills, all labels prefixed with `008D/`.
