# Deep Research Prompt — 007D

## Research Question
How can a non-developer who builds primarily through AI coding agents make those agents produce more efficient, less over-engineered code — and how can agents be used to review and refactor existing codebases to reduce complexity without losing functionality?

## Sub-Questions
1. What are the documented LLM coding biases that lead to over-engineering? (abstraction addiction, premature generalization, gold-plating, unnecessary error handling, defensive coding excess, pattern overuse)
2. What prompt engineering techniques, system instructions, and CLAUDE.md strategies demonstrably produce simpler code output from Claude and other LLM agents?
3. What are effective review/guardrail patterns for catching over-engineering after generation — automated linting, review prompts, complexity metrics?
4. How should CLAUDE.md files, system prompts, and project rules be structured to consistently bias agents toward minimal implementations?
5. What academic research or practitioner findings exist on controlling code complexity from AI agents? (papers, blog posts, benchmark studies)
6. What are practical strategies specifically for non-developers managing AI-generated codebases — how do you judge code quality when you can't read it deeply yourself?
7. How do different LLM agents (Claude, GPT/Codex, Gemini, Copilot, Cursor, Mistral/Vibe) differ in their over-engineering tendencies, and how should prompts be tuned per model?
8. What refactoring workflows work best when an agent reviews its own or another agent's code for efficiency gains?
9. What role do code complexity metrics (cyclomatic complexity, cognitive complexity, lines of code, abstraction depth) play in automated guardrails?
10. What are the failure modes of asking agents to simplify code — when does simplification go too far and break functionality?

## Scope
- Breadth: exhaustive — academic papers, practitioner blogs, framework documentation, benchmarks, everything
- Time horizon: include historical context but weight recent (2024-2026) heavily
- Domain constraints: focus on code generation and review by LLM agents; include all major models but weight Claude-specific findings

## Project Context
No project-context.md. This is a general research question that will inform:
- CLAUDE.md rules and system prompt updates across all projects
- Review pipeline design (meta-review, refactor-review, counter-review skills)
- Prompt templates for code generation subagents (Sonnet, Codex, Vibe, Cursor)
- Personal workflow for a non-developer building production systems via AI agents

The user runs a multi-agent pipeline: Claude Opus orchestrates, Claude Sonnet subagents handle most implementation, with Codex/Gemini/Copilot/Cursor/Vibe as specialized workers. Claude subagents always outnumber others.

## Known Prior Research
Existing research in artifacts/research/ (001D through 006D) — not directly related to this topic.

## Output Configuration
- Research folder: artifacts/research/007D/
- Summary destination: artifacts/research/summary/007D-llm-agent-code-efficiency.md
- Topic slug: llm-agent-code-efficiency

## Special Instructions
- The user is not a developer by trade — findings should be framed in practical, actionable terms, not academic jargon
- Prioritize techniques that can be encoded into CLAUDE.md rules, system prompts, and automated review skills
- Include concrete before/after examples where possible (over-engineered vs. efficient)
- Cover both generation-time interventions (get it right the first time) and review-time interventions (catch and fix after)
- Challenge the assumption that more abstraction = better code — find evidence for when flat, simple, repetitive code outperforms elegant abstractions
- Look for any research on the "three similar lines is better than a premature abstraction" principle
