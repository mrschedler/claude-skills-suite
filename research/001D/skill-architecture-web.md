MCP issues detected. Run /mcp list for status.Based on deep-dive research into 2025-2026 standards for Claude Code and the Agent Skills open standard, here is the synthesis of current best practices and architectural patterns.

### 1. Claude Code Context Consumption (The "2% Budget")
Claude Code utilizes a **Progressive Disclosure Architecture (PDA)** to maintain high reasoning performance in large codebases.
*   **The 2% Metadata Budget:** Claude allocates roughly **2% of the context window** (approx. 16,000 characters) to index all available skills at session startup. It only reads the `name` and `description` from the YAML frontmatter.
*   **Lazy Loading (Level 2):** The full body of a `SKILL.md` is only injected into the active context when Claude's reasoning loop identifies a semantic match with the 2% description.
*   **Lazy Loading (Level 3):** Supplemental documentation, API specs, or large examples linked within the skill are only read if explicitly requested by the model during execution.
*   **Exclusion Patterns:** Skills use "Observation Masking" to collapse repetitive tool outputs (like long build logs) and strict file-type exclusions (e.g., `**/dist/**`, `**/node_modules/**`) to prevent "context fog."

### 2. Best Skill Architecture for 30+ Skills
Managing a large-scale skill library requires moving from a flat folder to a **Domain-Oriented Structure**:
*   **Tiered Directory Structure:** Organize skills by domain (e.g., `engineering/`, `architecture/`, `security/`). This prevents name collisions and allows for "Marketplace" style distribution.
*   **Orchestrator vs. Encyclopedia:** Avoid making skills "knowledge bases." Instead, design them as **Orchestrators** that use tools (grep, read, bash) to find facts on-demand.
*   **Shared Logic via Scripts:** Move complex logic into standalone Python/JS scripts in a `shared/bin/` folder. Skills then invoke these via the `bash` tool to keep `SKILL.md` files lean.
*   **Subagent Delegation:** For massive tasks (e.g., repository-wide audits), use the `Task` tool to spawn a subagent in a fresh context window, preventing the main session from hitting token limits.

### 3. Anthropic Official Recommendations
Anthropic's 2025-2026 guidance emphasizes the **Agent Skills** standard:
*   **Size Constraint:** Keep every `SKILL.md` under **500 lines**. Move everything else to supplemental reference files.
*   **Micro-Skills Principle:** Build atomic skills (e.g., `review-test` and `review-security`) rather than monolithic "expert" skills.
*   **Hand-Refined Instructions:** Senior engineers recommend manually "tightening" AI-generated skill instructions to remove verbosity, which can confuse the model at scale.
*   **Frontmatter Hygiene:** Always include a specific `description` to ensure the "2% budget" indexer triggers the skill correctly.

### 4. Multi-Model Integration Patterns (Gemini + Codex in Claude Code)
*   **The "Context Champion" (Gemini 1.5/2.5 Pro):** When Claude identifies a task involving files >3,000 lines or repository-wide impact analysis, it invokes the **Gemini CLI** (e.g., `gemini -p "@path"`) to leverage Gemini's 1M-2M token window for a high-level summary.
*   **The "Ensemble Opinion" Pattern:** Using **Zen MCP** or **Agent Deck**, users run a prompt through Claude, Gemini, and Codex (GPT-4o/5) in parallel. Claude then synthesizes the three perspectives into a final, verified implementation.
*   **The "Reviewer-Optimizer" Pattern:** Implementation is handled by Claude Code (superior at multi-step editing), while Gemini is used for "needle-in-a-haystack" logic verification and Codex for identifying edge cases.

### 5. Sandbox Options for AI Code (2025-2026)
*   **E2B (Industry Standard):** The primary choice for production agents. Uses **Firecracker microVMs** for kernel-level isolation and supports stateful 24-hour sessions.
*   **Docker Sandboxes (Local-First):** Introduced by Docker to wrap agents like Claude Code in a secure container that mirrors the local workspace while protecting host secrets.
*   **Piston:** High-performance engine for short-lived snippet execution in 100+ languages; often used for unit test verification.
*   **Emerging:** **Northflank** (unlimited sessions/BYOC) and **Daytona** (sub-90ms cold starts).

### 6. Automated Rollback Patterns
*   **AI-Powered Semantic Hooks:** `pre-commit` hooks that use a lightweight LLM (Claude Haiku) to scan the `git diff` for hallucinated dependencies or logic inconsistencies before the commit is finalized.
*   **Smart Rollback (CI/CD):** Integration with monitoring tools (Datadog/Harness). If an AI-generated feature triggers log anomalies or latency spikes during a "bake period," the pipeline automatically executes a `git revert`.
*   **Shadow Mode (Dark Launch):** AI-generated code runs in parallel with legacy code. The system compares outputs and automatically aborts deployment if results diverge significantly.
*   **Prompt Versioning:** Treating prompts as immutable artifacts, allowing "bad" prompts to be rolled back independently of application logic.

### 7. MCP vs. Skills Tradeoffs
| Feature | MCP Servers | Claude Code Skills |
| :--- | :--- | :--- |
| **Primary Goal** | **Connectivity:** Accessing live data/APIs. | **Methodology:** Encoding expert workflows. |
| **Context Loading** | **Eager:** Loads all tools upfront. | **Lazy:** Progressive disclosure (on-demand). |
| **Token Cost** | Higher (constant tool definitions). | Lower (metadata-only index). |
| **Portability** | High (any MCP-compliant client). | Medium (optimized for Claude surfaces). |
| **Hybrid Pattern** | **MCP** provides the "Hands" (e.g., GitHub API); **Skills** provide the "Brain" (e.g., how to conduct a PR review). |

---

### Source Tally
| Source Type | Count | Quality |
| :--- | :--- | :--- |
| **Official Docs** (Anthropic/Docker/E2B) | 5 | High (Definitive) |
| **Technical Blogs** (Zencoder/Medium) | 4 | Medium-High (Implementation Patterns) |
| **Community** (Reddit/GitHub/Substack) | 6 | Medium (Practitioner insights) |
| **Total Sources Referenced** | 15 | |
