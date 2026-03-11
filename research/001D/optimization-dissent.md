I will activate the `research` skill to leverage its specialized guidance for finding contradicting evidence and distinguishing facts from opinions across multiple sources.
I will begin by researching the overhead costs of subagent isolation and seeking benchmarks that suggest simpler alternatives might be more efficient.
The following research summarizes contradicting evidence, benchmarks, and failure stories that challenge the efficiency and viability of common multi-agent and instructional patterns.

### 1. Subagent Isolation Efficiency
**The Dissent:** While isolation provides safety, the "coordination tax" often outweighs the benefits of specialization unless the task is massively complex.
*   **The 45% Rule:** A 2025 Google/MIT study found that if a single-agent baseline achieves **>45% accuracy** on a task, adding more agents typically yields **negative returns** due to coordination overhead.
*   **Token & Latency Tax:** Coordination tokens can consume over **45% of the total token budget**. Communication latency often serializes what could be parallel, increasing response times (e.g., from 2.5s to 3.0s in programming benchmarks).
*   **Error Amplification:** Independent isolated agents amplify errors by **17.2x**, whereas centralized orchestration limits this to **4.4x**.
*   **Simpler Alternative:** **Agent Routing** (selecting one right agent) and **Agent Cascades** (sequential refinement) achieve **12% better accuracy** at **20% lower cost** than pure isolated multi-agent systems.

### 2. Multi-Agent Automated Sprint Viability
**The Dissent:** Autonomous multi-agent software engineering has a reported **40% failure rate** within the first six months of production deployment.
*   **State Synchronization Failures:** Agents frequently develop inconsistent views of the codebase (e.g., one agent closing an issue another just opened), leading to "zombie" processes.
*   **Ownership Diffusion:** In teams of 5+ agents, ownership of "hard cases" diffuses. Agents tend to optimize for safe, micro-changes while **abandoning complex edge cases** that require deep reasoning.
*   **Retry Storms & Ghosting:** Naive automated workflows often enter "retry storms," consuming thousands of dollars in tokens on a single failing task without progress. 
*   **Context Drift:** Long-running sprints suffer from "context bloat," where critical instructions are silently dropped as the conversation history exceeds the window, causing the agents to drift away from the original goal.

### 3. Skill Consolidation (The Case for "Small & Many")
**The Dissent:** Large monolithic skills suffer from a "context ceiling" where too many instructions in one prompt confuse the model.
*   **SLM Superiority:** A **200M parameter** Small Language Model (SLM) was shown to outperform **GPT-4 (1.8T)** in specialized tasks like identifying unfair legal terms.
*   **Tool Confusions:** The **General AgentBench (2026)** found that leading LLMs experience "substantial performance degradation" when moving from domain-specific skills to a unified monolithic setting.
*   **Blast Radius:** In monolithic skills, a single hallucination derails the entire process. Modular "micro-skills" isolate failures, making them easier to debug and verify.
*   **Efficiency:** Modular skills offer sub-second responses and can run on consumer hardware, whereas large consolidated skills require high-end H100/A100 clusters.

### 4. CLAUDE.md Length (The Case for >300 Words)
**The Dissent:** Keeping instructions under 300 words often results in "interpretive freedom" that leads to generic hallucinations and inconsistency.
*   **The 60% Accuracy Leap:** Benchmarks show that detailed, well-structured prompts (often exceeding 1,000 words) can improve accuracy by **60%** over concise, "minimalist" instructions.
*   **Structure vs. Length:** The **IFEval benchmark** demonstrates that **structure (XML tags, Markdown hierarchy)** is more important than brevity. A 1,000-word structured prompt often outperforms a 200-word unstructured one.
*   **Behavioral Contracts:** Detailed instructions act as a strict "behavioral contract." Concise prompts are prone to "instruction drift" where the model reverts to its default training data instead of following local project conventions.
*   **Vulnerability to Hallucination:** Models are more likely to hallucinate when instructions are too brief to define edge cases and specific negative constraints.

### Source Tally
*   **Academic/Industry Research:** Google, MIT, UIUC (*On the Scaling Laws of Multi-Agent Systems, 2025*); General AgentBench (2026).
*   **Tech Blogs/Benchmarks:** GitHub Blog (State synchronization failures); NVIDIA (Small vs. Large model performance); Anthropic (Instruction following & context window optimization).
*   **Case Studies:** IBM Granite 8B (Structure vs. Length benchmarks); HumanEval (MAS vs. SAS latency); various post-mortems from AI engineering platforms (Sparrow, ArtusAI, TechAhead).
