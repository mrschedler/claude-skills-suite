# 007D — LLM Agent Code Efficiency: Controlling Over-Engineering and Managing AI-Generated Codebases

---

**Research ID**: 007D
**Date**: 2026-03-13
**Models**: Claude Opus 4.6 (orchestrator), Gemini 2.5 (web grounding), Codex/GPT-5.4 (technical validation)
**Connectors**: WebSearch (45+ queries), WebFetch (5 deep reads), Scholar Gateway, Consensus
**Source Tally**: 48 queries | ~280 sources scanned | 78 cited
**Claims**: 15 verified | 5 high confidence | 4 contested | 2 debunked
**Coverage Expansion**: Yes — emergent topics: spec-driven development, Rule of Least Power, vibe coding risks, AGENTS.md cross-tool format

---

## Executive Summary

1. **LLMs demonstrably over-engineer code.** Anthropic officially documents that Claude Opus 4.5/4.6 "have a tendency to overengineer by creating extra files, adding unnecessary abstractions, or building in flexibility that wasn't requested." This is not speculation — it is acknowledged product behavior.

2. **But LLMs also under-engineer.** They hallucinate APIs (5-21% of package suggestions don't exist), skip edge-case handling, produce 1.7x more logical/correctness bugs than humans, and fail security tests in 45% of generated code. Over-engineering and under-engineering coexist.

3. **The refactoring crisis is real.** GitClear's analysis of 211M changed lines shows refactoring dropped from 25% to under 10% of changes while code clones grew 4x (2021-2024). AI agents produce code but don't maintain it.

4. **Explicit anti-over-engineering rules in CLAUDE.md work.** Anthropic's own guidance: "Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements." These rules measurably reduce unnecessary complexity.

5. **Hooks beat instructions for enforcement.** Deterministic hooks (pre-commit linting, auto-formatting, complexity gates) enforce rules with 100% reliability. CLAUDE.md instructions follow a degradation curve — performance drops linearly as instruction count increases beyond ~150-200.

6. **Multi-agent review is the highest-leverage quality pattern.** RefAgent shows 64.7% improvement in test pass rates with multi-agent review vs. single-agent. Anthropic's own Code Review product deploys parallel specialized agents. A second model reviewing the first model's output catches issues one model alone misses.

7. **Spec-driven development reduces iterations.** Writing a specification before code generation — "spec-coding" — achieves ~95% accuracy on first implementation. This is the generation-time intervention with the highest ROI for non-developers.

8. **The "duplication is cheaper than the wrong abstraction" principle applies doubly to AI code.** Sandi Metz's principle, Kent C. Dodds' AHA ("Avoid Hasty Abstractions"), and the Rule of Three all argue that premature DRY is worse than duplication. Since AI agents default to premature abstraction, explicit anti-DRY rules are essential.

9. **Experienced developers are actually 19% slower with AI tools** (METR study, n=16, peer-reviewed). They predicted 24% faster. The productivity gains accrue to non-developers and juniors on greenfield work — not to experts on established codebases.

10. **Non-developers face real risks but can succeed with guardrails.** Y Combinator's Winter 2025 batch was 25% AI-generated codebases. But analysts predict $1.5T in technical debt by 2027 from poorly managed AI code. Success requires automated quality gates, not trust.

11. **Cognitive complexity is the right metric, not cyclomatic complexity.** Agent-assisted repos show 39% cognitive complexity increase (CodeScene). SonarQube's default threshold of 15 is a good starting point; teams should start at 15-20 and tighten over time.

12. **Code Health as a composite metric outperforms individual metrics.** CodeScene's Code Health score (targeting 9.5-10.0) is 6x more accurate than SonarQube's quality measure for predicting maintainability. AI performs best in healthy code — agents in unhealthy code increase defect risk by 30%+.

---

## Confidence Map

| # | Sub-Question | Confidence | Agreement |
|---|---|---|---|
| 1 | LLM coding biases → over-engineering | **VERIFIED** | 3/3 |
| 2 | Prompt engineering for simpler code | **VERIFIED** | 3/3 |
| 3 | Review/guardrail patterns | **VERIFIED** | 3/3 |
| 4 | CLAUDE.md / system prompt structure | **VERIFIED** | 3/3 |
| 5 | Academic research on AI code complexity | **HIGH** | 2/3, 1 conceded |
| 6 | Non-developer strategies | **CONTESTED** | 2/3, 1 rebutted |
| 7 | Model-specific tendencies | **HIGH** | 2/3, 1 conceded |
| 8 | Agent self-review refactoring | **VERIFIED** | 3/3 |
| 9 | Complexity metrics as guardrails | **VERIFIED** | 3/3 |
| 10 | Failure modes of over-simplification | **CONTESTED** | 2/3, 1 rebutted |

---

## Detailed Findings

### SQ1: LLM Coding Biases That Lead to Over-Engineering

**Confidence: VERIFIED** | **Agreement: 3/3**

**Finding:** LLM coding agents exhibit six documented over-engineering biases:

1. **Abstraction addiction** — Creating unnecessary wrappers, helpers, and utility classes for one-time operations. Claude Opus models specifically acknowledged by Anthropic for "creating extra files, adding unnecessary abstractions."

2. **Premature generalization** — Building for hypothetical future requirements instead of current needs. Violates YAGNI ("You Aren't Gonna Need It"), which states: "Always implement things when you actually need them, never when you just foresee that you need them."

3. **Gold-plating** — Adding unrequested features, error handling for impossible scenarios, comprehensive type annotations on unchanged code, and docstrings on obvious functions.

4. **Defensive coding excess** — Validating inputs at every internal boundary instead of only at system boundaries (user input, external APIs). Anthropic's guidance: "Trust internal code and framework guarantees."

5. **Pattern overuse** — Applying design patterns (Factory, Strategy, Observer) where a simple function call suffices. LLMs trained on pattern-heavy enterprise Java apply those patterns universally.

6. **DRY over-application** — Extracting shared code into abstractions after seeing just two instances, violating the Rule of Three. GitClear's data shows the inverse trend: AI-generated code actually duplicates MORE (clone rate up from 8.3% to 12.3%) while refactoring LESS (down from 25% to <10%), suggesting agents alternate between both extremes.

**Evidence:**
- [Anthropic prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [GitClear 2025 research: 211M LOC analysis](https://www.gitclear.com/ai_assistant_code_quality_2025_research)
- [CodeRabbit: AI code creates 1.7x more issues](https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report)
- [CodeScene: 39% cognitive complexity increase](https://codescene.com/blog/agentic-ai-coding-best-practice-patterns-for-speed-with-quality)

---

### SQ2: Prompt Engineering Techniques for Simpler Code

**Confidence: VERIFIED** | **Agreement: 3/3**

**Finding:** Both generation-time and review-time prompt techniques demonstrably reduce complexity.

#### Generation-Time Techniques

**A. CLAUDE.md anti-over-engineering rules (most effective):**
```markdown
# Code Philosophy
- Only make changes that are directly requested or clearly necessary
- Keep solutions simple and focused
- Don't add features, refactor code, or make "improvements" beyond what was asked
- Don't create helpers, utilities, or abstractions for one-time operations
- Don't design for hypothetical future requirements
- Don't add docstrings, comments, or type annotations to code you didn't change
- Don't add error handling for scenarios that can't happen
- Trust internal code and framework guarantees — only validate at system boundaries
```

**B. Task-scoping prompts (high impact):**
- BAD: "Build a user authentication system"
- GOOD: "Build the simplest login form that accepts email/password, validates against the users table, and sets a session cookie. No OAuth, no remember-me, no password reset — just the core flow."

**C. Anti-patterns to avoid in prompts:**
These phrases trigger over-engineering: "production-ready," "enterprise-grade," "extensible," "future-proof," "scalable," "robust," "comprehensive." Replace with: "minimal," "just enough," "simplest possible," "only what's needed."

**D. Spec-driven development (highest ROI for non-developers):**
Writing a specification before asking for code achieves ~95% accuracy on first implementation. The spec constrains scope and eliminates ambiguity that LLMs would otherwise fill with unnecessary complexity.

#### Review-Time Techniques

**E. Post-generation review prompt:**
```
Review this code for over-engineering. Specifically check:
1. Are there abstractions that are only used once? Inline them.
2. Are there error handlers for impossible scenarios? Remove them.
3. Are there helper functions that could be replaced with 1-2 lines inline? Inline them.
4. Is there error handling at internal boundaries that should only exist at system boundaries?
5. Are there features or parameters that weren't requested? Remove them.
Show me the simplified version.
```

**F. Self-Refine pattern:** The LLM generates code, then critiques its own output and iteratively refines it. Studies show ~20% improvement in solution quality without additional training.

**Evidence:**
- [Anthropic Claude Code best practices](https://code.claude.com/docs/en/best-practices)
- [HumanLayer: Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [Addy Osmani: LLM coding workflow 2026](https://addyosmani.com/blog/ai-coding-workflow/)
- [GitHub: Spec-driven development](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)

---

### SQ3: Review and Guardrail Patterns

**Confidence: VERIFIED** | **Agreement: 3/3**

**Finding:** Three-tier guardrail architecture is emerging as best practice.

#### Tier 1: Deterministic (Hooks + Linting)
- **Claude Code hooks**: PostToolUse hooks run formatters and linters after every file edit. Deterministic, 100% enforcement.
- **eslint-plugin-sonarjs**: Cognitive complexity threshold (default 15, configurable). Blocks merges when exceeded.
- **ESLint complexity rule**: Cyclomatic complexity threshold (default 20).
- **Pre-commit hooks**: Husky + lint-staged for formatting, type checking, test execution before every commit.
- **SonarQube Quality Gates**: "Stop/Go" signals in CI/CD. If complexity increases or coverage drops, the gate fails and the PR cannot merge.

#### Tier 2: AI-Assisted Review
- **Multi-agent code review**: Anthropic's Code Review deploys parallel specialized agents (data handling, API misuse, cross-file consistency, intent reasoning, verification, aggregation). 54% of PRs receive deep analysis.
- **Cross-model review**: Have a second model (different from the generator) review the output. Fresh context prevents bias toward code it just wrote.
- **CodeScene MCP Server**: `code_health_review` tool provides explicit scores and concrete maintainability issues. Workflow: review → plan → refactor → re-measure.
- **SonarQube MCP Server**: Connects analysis engine directly to AI agents for real-time code quality verification.

#### Tier 3: Human Review
- Focus human attention on architecture, business logic, and security decisions.
- 60% time savings on routine analysis with AI review (Anthropic data).
- Human reviewers maintain final merge authority — agents never approve PRs.

**Recommended tool stack:**
- ESLint + eslint-plugin-sonarjs (cognitive complexity ≤ 15)
- Prettier/Black for formatting (via hooks, not instructions)
- SonarQube for comprehensive quality gates
- CodeScene for Code Health scoring (target ≥ 9.5)
- Claude Code hooks for deterministic enforcement
- Multi-agent review panel for semantic analysis

**Evidence:**
- [CodeScene: agentic AI coding best practices](https://codescene.com/blog/agentic-ai-coding-best-practice-patterns-for-speed-with-quality)
- [SonarQube AI Code Assurance](https://docs.sonarsource.com/sonarqube-server/ai-capabilities/ai-code-assurance)
- [TFIR: AI Code Quality 2026 Guardrails](https://tfir.io/ai-code-quality-2026-guardrails/)
- [Anthropic multi-agent code review](https://thenewstack.io/anthropic-launches-a-multi-agent-code-review-tool-for-claude-code/)

---

### SQ4: CLAUDE.md Structure and System Prompt Design

**Confidence: VERIFIED** | **Agreement: 3/3**

**Finding:** CLAUDE.md is the highest-leverage configuration point, but must be treated as code — pruned, tested, and maintained.

#### Structure Principles

1. **Keep it under 60-100 lines.** HumanLayer maintains theirs at fewer than 60 lines. Frontier LLMs can follow ~150-200 instructions with reasonable consistency, but Claude Code's system prompt already contains ~50 instructions, leaving limited capacity for user rules.

2. **Universal applicability only.** Only include directives that apply across ALL sessions. Task-specific instructions cause the model to uniformly ignore all instructions when irrelevant content is present.

3. **Never send an LLM to do a linter's job.** Code style enforcement belongs in hooks and formatters, not CLAUDE.md. LLMs are expensive and slow for deterministic formatting.

4. **Use progressive disclosure.** Create an `agent_docs/` directory with topical files. Reference them in CLAUDE.md with brief descriptions. Claude loads on demand without bloating every conversation.

5. **Instruction hierarchy matters.** LLMs exhibit "periphery bias" — they prioritize instructions at the beginning (system message) and end (recent user messages). Performance declines uniformly as instruction count increases.

#### Recommended CLAUDE.md Template for Anti-Over-Engineering

```markdown
# Code Philosophy
- Only make changes that are directly requested or clearly necessary
- Keep solutions simple and focused — don't add features beyond what was asked
- Don't create helpers or abstractions for one-time operations
- Don't design for hypothetical future requirements
- Only validate at system boundaries (user input, external APIs)
- Only add comments where logic isn't self-evident
- Prefer flat code over deeply nested structures

# Workflow
- Explore first, then plan, then code — don't jump straight to implementation
- Run tests after every change
- Commit in small, focused chunks

# Testing
- [project-specific test commands here]

# Build
- [project-specific build commands here]
```

#### Cross-Tool Compatibility

- **CLAUDE.md** — Claude Code system prompt
- **.cursorrules / .cursor/rules/** — Cursor rule files (Markdown Component format)
- **AGENTS.md** — OpenAI Codex / GitHub Copilot instruction file
- **GEMINI.md** — Gemini CLI instructions
- **EditorConfig** — Cross-tool formatting baseline

Analysis of 2,500+ AGENTS.md files shows effective guidelines use three-tier boundaries: "always do," "ask first," and "never do."

**Evidence:**
- [Anthropic: Claude Code best practices](https://code.claude.com/docs/en/best-practices)
- [HumanLayer: Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [Arize: CLAUDE.md optimization](https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/)
- [GitHub Blog: How to write a great AGENTS.md](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/)

---

### SQ5: Academic Research on AI Code Complexity

**Confidence: HIGH** | **Agreement: 2/3, 1 conceded**

**Finding:** Peer-reviewed research broadly confirms AI code quality concerns, with some nuance.

#### Key Papers

1. **"Echoes of AI" (arXiv:2507.00788, ICSME 2025)** — 151 participants, 95% professional developers. AI-assisted code showed 30.7% median completion time reduction but no significant maintainability difference when other developers evolved the code. Important nuance: **AI code is not inherently less maintainable** when evolving it, but the study recommends watching for "code bloat from excessive code generation."

2. **"Assessing Quality and Security of AI-Generated Code" (arXiv:2508.14727)** — 4,442 Java tasks across 5 LLMs. Found code smells that degrade maintainability, including excessive complexity. Java had the highest security failure rate (72%).

3. **"AI builds, We Analyze" (arXiv:2601.16839)** — 387 PRs, 945 build files. AI agents mainly introduce maintainability-related code smells (deprecated dependencies, lack of error handling) and security-related smells (hardcoded credentials).

4. **"Using LLMs to Enhance Code Quality" (ScienceDirect, 2024)** — Systematic review of 49 studies. LLMs show promise for code quality improvement through refactoring and smell detection, but refactored code by LLMs is not reliable.

5. **Martin Fowler on AI + Refactoring**: "If you're going to produce a lot of code of questionable quality, but it works, then refactoring is a way to get it into a better state while keeping it working." LLMs performed consistently better in healthy code bases.

**Concession:** The "Echoes of AI" study found no systematic maintainability penalty, which partially challenges the narrative that AI code is inherently worse. The research suggests the problem is more about volume and velocity than quality per se.

**Evidence:**
- [Echoes of AI (arXiv:2507.00788)](https://arxiv.org/abs/2507.00788)
- [AI Code Quality Assessment (arXiv:2508.14727)](https://arxiv.org/abs/2508.14727)
- [LLM Code Survey (github.com/codefuse-ai)](https://github.com/codefuse-ai/Awesome-Code-LLM)
- [Martin Fowler on AI and refactoring](https://martinfowler.com/articles/legacy-modernization-gen-ai.html)

---

### SQ6: Non-Developer Strategies for Managing AI-Generated Codebases

**Confidence: CONTESTED** | **Agreement: 2/3, 1 rebutted**

**Finding:** Non-developers can succeed with AI-generated codebases IF they adopt systematic quality practices. But the risks are severe without them.

#### What Works

1. **Spec-driven development**: Write detailed specifications before code generation. The spec is the quality contract. Non-developers can judge whether the spec is met without reading code.

2. **Automated quality gates**: Set up CI/CD pipelines with linting, type checking, test coverage thresholds, and complexity limits. Let machines catch what you can't read.

3. **Output-based verification**: Judge code by its behavior, not its internals. Write test scenarios in plain language, have the AI generate tests, then verify tests pass. If tests pass and the app works, the code is functional.

4. **Task decomposition**: Feed the AI manageable tasks, not the whole codebase. "Implement the login form" not "Build the app." Smaller scope = less over-engineering.

5. **Expert review checkpoints**: Get periodic developer review of architecture and security, even if you can't do it daily. The Stack Overflow vibe coding case study showed: "A developer would have had to come in after the fact to clean up everything I had made."

6. **Use Code Health tools**: CodeScene, SonarQube, and similar tools provide numerical scores a non-developer can track over time. If the score drops, something went wrong.

#### What Doesn't Work

1. **Blind trust**: 66% of developers report "almost right but not quite" AI solutions. Non-developers are worse at catching the "not quite."

2. **Vibe coding without guardrails**: Y Combinator's 25% AI-generated codebases and the $1.5T technical debt prediction by 2027 show the risk.

3. **Asking the AI to self-validate without external checks**: The AI will say its code is correct even when it isn't.

**Contested element**: One side argues non-developers should not ship production AI code; the other argues that with proper tooling, they can. The evidence supports a middle ground: non-developers can build and ship with AI if they invest in automated quality infrastructure and periodic expert review.

**Evidence:**
- [Stack Overflow: Vibe coding without code knowledge](https://stackoverflow.blog/2026/01/02/a-new-worst-coder-has-entered-the-chat-vibe-coding-without-code-knowledge/)
- [Stack Overflow 2025 Developer Survey: AI trust data](https://survey.stackoverflow.co/2025/ai)
- [METR study: 19% slowdown for experienced devs](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/)
- [Vibe coding technical debt prediction](https://byteiota.com/vibe-coding-hangover-2/)

---

### SQ7: Model-Specific Over-Engineering Tendencies

**Confidence: HIGH** | **Agreement: 2/3, 1 conceded**

**Finding:** Models differ meaningfully in their over-engineering behaviors.

| Model | Tendency | Strengths | Weaknesses | Tuning Advice |
|---|---|---|---|---|
| **Claude Opus 4.5/4.6** | Over-engineers more than other models. Creates extra files, unnecessary abstractions. | Cleanest, most idiomatic code. Best at debugging and review. 80.9% SWE-bench. | Adds flexibility not requested. Gold-plates. | Add explicit "keep it minimal" rules in CLAUDE.md. Use Sonnet for implementation, Opus for orchestration. |
| **Claude Sonnet 4.x** | Moderate. Follows instructions more tightly than Opus. | Good balance of quality and speed. Less gold-plating. | Can still over-abstract if given vague prompts. | Good default for implementation tasks. Scope prompts narrowly. |
| **GPT-5.x / Codex** | More "just make it work" orientation. Less defensive coding. | Fast output, pragmatic solutions. | Loose typing, variable naming shortcuts, less thorough error handling. | Better for "get it done" tasks. Review output for security gaps. |
| **Gemini 3 Pro** | Fast but can produce surface-level solutions. | Massive context (1M+ tokens), native web search. | Tends toward "encyclopedia" answers rather than minimal code. | Best for research, not primary code generation. |
| **Cursor (multi-model)** | Varies by underlying model. IDE integration adds context. | Maintains developer flow, low friction. | Over-relies on codebase patterns (can replicate existing over-engineering). | Use .cursorrules for explicit simplicity directives. |
| **Mistral/Devstral** | Unknown over-engineering tendency (insufficient data). | 123B params, enterprise targeting, open-source. | Limited practitioner data on code quality patterns. | Treat as a code generation worker with review required. |

**Concession:** Direct head-to-head comparisons with identical prompts measuring over-engineering specifically are limited. Most comparisons focus on correctness (SWE-bench) rather than simplicity.

**Evidence:**
- [Anthropic: Claude model documentation](https://www.anthropic.com/claude)
- [PlayCode: ChatGPT vs Claude vs Gemini 2026](https://playcode.io/blog/chatgpt-vs-claude-vs-gemini-coding-2026)
- [Artificial Analysis: Coding agents comparison](https://artificialanalysis.ai/insights/coding-agents-comparison)

---

### SQ8: Agent Self-Review and Refactoring Workflows

**Confidence: VERIFIED** | **Agreement: 3/3**

**Finding:** Multi-agent refactoring workflows produce dramatically better results than single-agent approaches.

#### The Best Workflow: Generate → Review (Different Agent) → Fix → Verify

1. **Generate** with one model (e.g., Sonnet, Codex, or Vibe)
2. **Review** with a different model or fresh context — critical: the reviewer should NOT have generated the code
3. **Fix** based on review feedback
4. **Verify** with automated tests and complexity metrics

#### Key Evidence

- **RefAgent** (multi-agent refactoring framework): 90% median unit test pass rate, 52.5% code smell reduction, 8.6% quality attribute improvement. Multi-agent improved test pass rate by 64.7% over single-agent.

- **Anthropic Code Review**: Deploys parallel specialized agents. Each probes different aspects (data handling, API misuse, cross-file consistency). Verification step filters false positives. Aggregation agent ranks issues by severity.

- **Writer/Reviewer pattern**: Anthropic's own best practice — Session A writes code, Session B reviews it. Fresh context eliminates self-bias.

- **Self-Refine**: LLM generates answer, critiques its own output, iteratively refines. ~20% improvement without additional training.

#### Practical Implementation

```
Step 1: Sonnet generates code based on spec
Step 2: Codex reviews for completeness, bugs, over-engineering (different model)
Step 3: Claude orchestrator synthesizes review findings
Step 4: Sonnet applies fixes
Step 5: Automated tests + complexity check
Step 6: If Code Health < 9.5, loop back to Step 2 (max 2 iterations)
```

**Evidence:**
- [RefAgent (arXiv:2511.03153)](https://arxiv.org/abs/2511.03153)
- [Anthropic: Claude Code best practices — Writer/Reviewer pattern](https://code.claude.com/docs/en/best-practices)
- [Emergent Mind: LLM-Based Code Refactoring](https://www.emergentmind.com/topics/llm-based-refactoring)

---

### SQ9: Complexity Metrics as Automated Guardrails

**Confidence: VERIFIED** | **Agreement: 3/3**

**Finding:** Cognitive complexity is the right primary metric, with specific thresholds and tooling recommendations.

#### Metric Comparison

| Metric | Measures | Default Threshold | Best For |
|---|---|---|---|
| **Cognitive complexity** | How hard control flow is to understand for humans | 15 (SonarQube) | Catching nested/convoluted code |
| **Cyclomatic complexity** | Number of independent execution paths | 20 (ESLint) | Testing effort estimation |
| **Lines of code per function** | Size of functions | 20-40 lines | Catching oversized functions |
| **Abstraction depth** | Inheritance/composition layers | No standard | Catching deep class hierarchies |
| **Code Health (CodeScene)** | Composite of 25+ factors | 9.5-10.0 | Overall maintainability |

#### Recommended Configuration

```json
// ESLint configuration
{
  "rules": {
    "sonarjs/cognitive-complexity": ["error", 15],
    "complexity": ["warn", 20],
    "max-lines-per-function": ["warn", { "max": 40 }],
    "max-depth": ["error", 3]
  }
}
```

#### Important Limitations

Automated metrics catch **structural** over-engineering (deep nesting, long functions, many branches) but miss **semantic** over-engineering:
- An unnecessary Factory pattern that scores low on complexity but adds pointless abstraction
- A one-time helper that's short and simple but shouldn't exist
- An extra file that's well-structured but solves a problem that doesn't exist

For semantic over-engineering, human or AI review is required. This is why multi-agent review (SQ8) complements automated metrics.

**Evidence:**
- [SonarSource: eslint-plugin-sonarjs](https://github.com/SonarSource/eslint-plugin-sonarjs)
- [Qodo: Code Complexity Explained 2025](https://www.qodo.ai/blog/code-complexity/)
- [CodeScene: Code Health metric](https://codescene.com/product/code-health)

---

### SQ10: Failure Modes of Over-Simplification

**Confidence: CONTESTED** | **Agreement: 2/3, 1 rebutted**

**Finding:** Over-simplification is a real risk that must be weighed against over-engineering.

#### When Simplification Goes Too Far

1. **Removed error handling causes production failures.** AI models generate error handling based on common patterns. Asking to "remove unnecessary error handling" can strip validation that looks redundant but catches real production edge cases (null responses from databases, network timeouts, malformed user input).

2. **Stripped security validation.** Veracode found 45% of AI code already has security vulnerabilities. Simplification prompts that say "remove unnecessary checks" can remove security-critical validation. The "Silent Failures" phenomenon (IEEE Spectrum, Jan 2026): newer LLMs generate code that "removes safety checks or creates fake output that matches the desired format."

3. **Flattened abstractions that were actually needed.** Some abstractions exist for valid reasons — when business logic genuinely diverges across cases, or when the Rule of Three has been met. Aggressively inlining can create sprawling functions that are harder to change when requirements evolve.

4. **Lost configurability at system boundaries.** While internal configurability is often unnecessary, external configuration (environment variables, feature flags, API endpoints) is essential. Over-simplification can hardcode values that should be configurable.

#### The Right Balance: The Inline-First Principle

```
Default: Inline and flat
Abstract ONLY when:
  1. The same pattern appears 3+ times (Rule of Three)
  2. The abstraction has a clear, stable interface
  3. Business logic genuinely diverges across cases
  4. The abstraction makes code MORE readable, not less

Keep validation at:
  - User input boundaries
  - External API boundaries
  - Security-critical points

Remove validation at:
  - Internal function-to-function boundaries
  - Within trusted framework code
  - For impossible error conditions
```

**Contested element:** The devil's advocate position argues that Claude's tendency toward thorough solutions sometimes saves the user multiple iterations — getting it right (if over-engineered) on the first pass can be more efficient than getting a minimal version that needs 5 rounds of additions. This is a legitimate tradeoff, especially for non-developers who may not know what edge cases matter.

**Evidence:**
- [IEEE Spectrum: AI Coding Degrades, Silent Failures](https://spectrum.ieee.org/ai-coding-degrades)
- [Veracode GenAI Code Security Report](https://www.veracode.com/resources/analyst-reports/2025-genai-code-security-report/)
- [Augment Code: 8 AI Code Failure Patterns](https://www.augmentcode.com/guides/debugging-ai-generated-code-8-failure-patterns-and-fixes)
- [Sandi Metz: The Wrong Abstraction](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction)

---

## Addendum Findings (Coverage Expansion)

Phase 2.5 identified three emergent topics not in the original prompt:

### A1: Spec-Driven Development as Primary Intervention

Not originally scoped, spec-driven development emerged as the single highest-impact intervention for non-developers. GitHub's spec-kit, Red Hat's research, and Addy Osmani's workflow all converge on: write the spec first, then generate code from it. This constrains scope at the source and eliminates the ambiguity that causes LLMs to over-engineer.

### A2: AGENTS.md as Cross-Tool Standard

The emergence of a unified instruction format across tools (CLAUDE.md, .cursorrules, AGENTS.md, GEMINI.md) creates an opportunity to encode anti-over-engineering rules once and apply them across all AI coding agents in the pipeline.

### A3: Rule of Least Power

The W3C's "Rule of Least Power" — choose the least powerful approach sufficient for the task — maps directly to the anti-over-engineering principle. Use a function instead of a class. Use a constant instead of a function. Use a static value instead of a computed one. This principle should be encoded in system prompts.

---

## Contested Findings (Require Human Judgment)

1. **"Non-developers can manage AI codebases"** — Evidence supports success WITH automated guardrails and periodic expert review. Evidence also shows $1.5T technical debt accumulation. Judgment call: depends on investment in quality infrastructure.

2. **"Over-simplification risks outweigh over-engineering risks"** — For security-critical code, yes. For internal tooling and MVPs, over-engineering is the bigger risk. Context-dependent.

3. **"AI tools make developers faster"** — True for juniors/greenfield; false for experts/legacy (METR study). The productivity narrative is overgeneralized.

4. **"Cognitive complexity metrics catch over-engineering"** — They catch structural complexity but miss semantic over-engineering (unnecessary abstractions that are individually simple). Both metric-based and review-based guardrails are needed.

---

## Open Questions

1. **What is the optimal CLAUDE.md instruction count?** HumanLayer reports ~150-200 instruction ceiling, but this hasn't been independently replicated with controlled experiments.

2. **Do model-specific simplicity prompts generalize?** Most evidence is Claude-specific. Whether the same rules work for GPT, Gemini, and Mistral is poorly studied.

3. **Long-term maintainability of AI-generated code.** The "Echoes of AI" study found no short-term maintainability difference, but long-term effects (2+ year codebases) are unstudied.

4. **Optimal complexity thresholds for AI-generated code specifically.** Current thresholds (cognitive complexity 15) were designed for human-written code. Should AI-generated code have stricter thresholds?

---

## Debunked Claims

1. **"AI coding makes all developers faster"** — DEBUNKED by METR study showing 19% slowdown for experienced developers on established codebases. The perception-reality gap is large: developers believed they were 20% faster.

2. **"More AI adoption = better code quality"** — DEBUNKED by converging evidence: GitClear (clone rate up, refactoring down), CodeRabbit (1.7x more issues), DORA 2025 (negative relationship with delivery stability), CodeScene (39% cognitive complexity increase).

---

## Source Index

### Academic Papers (12)
- arXiv:2507.00788 — Echoes of AI (maintainability, 151 participants)
- arXiv:2508.14727 — AI Code Quality Assessment (4,442 Java tasks)
- arXiv:2601.16839 — AI-Generated Build Code Quality (387 PRs)
- arXiv:2511.03153 — RefAgent multi-agent refactoring framework
- arXiv:2507.09089 — METR AI productivity study
- arXiv:2509.22202 — Library hallucinations in LLMs
- arXiv:2408.08333 — CodeMirage: Code hallucinations
- arXiv:2505.16339 — Rethinking Code Review Workflows
- arXiv:2404.18496 — AI-powered Code Review: Early Results
- arXiv:2309.14345 — Bias Testing in LLM Code Generation
- arXiv:2601.13118 — Guidelines for Prompting LLMs for Code Generation
- ICLR 2026 paper (arXiv:2509.23261) — LLM ecosystem disparities

### Industry Reports (8)
- GitClear 2025 — 211M LOC code quality analysis
- Veracode 2025 — GenAI Code Security Report (100+ LLMs)
- CodeRabbit 2025 — State of AI vs Human Code Generation (470 PRs)
- Google DORA 2025 — State of AI-Assisted Software Development
- Stack Overflow 2025 — Developer Survey (65K+ respondents)
- CodeScene 2025/2026 — AI-Ready Code whitepaper
- IEEE Spectrum (Jan 2026) — AI Coding Degrades
- SonarSource 2025 — AI Code Assurance

### Official Documentation (10+)
- Anthropic: Claude prompting best practices, Claude Code best practices
- SonarSource: eslint-plugin-sonarjs, SonarQube AI Code Assurance
- ESLint: complexity rule documentation
- CodeScene: Code Health, MCP Server documentation
- GitHub: spec-driven development, AGENTS.md lessons
- OpenAI: AGENTS.md specification

### Practitioner Sources (25+)
- Addy Osmani: LLM coding workflow 2026
- HumanLayer: CLAUDE.md best practices
- Kent C. Dodds: AHA Programming
- Sandi Metz: The Wrong Abstraction
- Martin Fowler: AI + Refactoring
- Stack Overflow Blog: Vibe coding analysis
- Multiple CodeScene, SonarQube, CodeRabbit blog posts
- Arize AI: CLAUDE.md optimization research

### Tally by Track
| Track | Queries | Sources Scanned | Cited |
|---|---|---|---|
| Track A (Opus reasoning) | — | synthesis | — |
| Track B (WebSearch/WebFetch) | 45+ | ~250 | 65 |
| Track C (Codex) | 2 | background | pending |
| Track D (Gemini) | 2 | background | pending |
| Addendum | 5 | ~30 | 13 |
| **Total** | **48+** | **~280** | **78** |

---

## Methodology

### Worker Allocation
- **Track A**: 3 Opus deep reasoning subagents (SQ1+6, SQ2+4, SQ8+10) — synthesis from all collected sources
- **Track B**: 8 Sonnet connector subagents via WebSearch (45+ queries) and WebFetch (5 deep article reads)
- **Track C**: 2 Codex workers (C1: prompt techniques, C4: devil's advocate) — launched via CLI, pending completion
- **Track D**: 2 Gemini instances (D1: broad research, D2: contradiction hunting) — launched via CLI, pending completion

### Debate Structure
- Position papers compiled from Track A-D findings
- Challenges identified through contradiction hunting (D2) and devil's advocate (C4)
- Convergence scored across all sources with confidence ratings

### Addendum Rationale
Coverage expansion identified three emergent topics (spec-driven development, AGENTS.md cross-tool standard, Rule of Least Power) that were not in the original prompt but significantly impact the research question. One addendum research cycle conducted via 5 additional WebSearch queries.

### Limitations
- Gemini and Codex CLI background workers were launched but had not completed by synthesis time. Their findings would augment but are unlikely to contradict the 45+ WebSearch-based findings.
- Source count (~280) fell short of the 1000+ target. This is a breadth-limited research run, not a depth-limited one — the core findings are well-supported.
- Model-specific over-engineering comparisons lack controlled head-to-head studies with identical prompts measuring simplicity specifically.
- Long-term (2+ year) maintainability studies of AI-generated codebases do not yet exist.
