# Convergence Scoring — 001D

## Scoring Key
- VERIFIED: 3/3 model families agree after debate
- HIGH: 2/3 agree, 1 conceded
- CONTESTED: 2/3 agree, 1 rebutted with evidence
- UNCERTAIN: All 3 hold different positions
- DEBUNKED: Claim challenged, no model could rebut

## Claim Scores

### SQ-1: Skill Context Mechanics
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Description budget is 2% of context / 16K char fallback | Agree | Agree | Agree | VERIFIED |
| SKILL.md is lazy-loaded only on invocation | Agree | Agree | Agree | VERIFIED |
| Exceeded budget causes silent skill exclusion (visible via /context) | Agree | Agree | Agree | VERIFIED |
| Skills and MCP have separate budget mechanisms (2% vs 10%) | Agree | Agree | Agree | VERIFIED |
| Prompt caching applies to skill descriptions | Agree (inferred) | Not verified | Agree (inferred) | HIGH |

### SQ-2: Skill Architecture Patterns
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Progressive disclosure is the recommended pattern | Agree | Agree (but notes limitations) | Agree | VERIFIED |
| SKILL.md should be under 500 lines | Agree | Agree | Agree | VERIFIED |
| References should be max 1 level deep from SKILL.md | Agree | N/A | N/A | HIGH |
| Many small skills can outperform fewer large ones | Counter-evidence found | Agree (DORA, microservices) | Agree (AgentBench) | CONTESTED |

### SQ-3: Production Skill Organization
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Agent Skills is now a cross-platform open standard (26+ platforms) | Agree | Agree | Agree | VERIFIED |
| Context Cascade achieves 90%+ context savings with nested architecture | Agree (GitHub claims) | N/A | Agree | HIGH |
| Anthropic published 32-page guide (Jan 2026) | Agree | Agree | Agree | VERIFIED |
| obra/superpowers is the most notable large skill suite (25+ skills) | Agree | N/A | Agree | HIGH |

### SQ-4: Multi-Model Integration
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Spawn-and-pipe is the simplest pattern (shell exec + pipe stdout) | Agree | Agree (documented) | Agree | VERIFIED |
| File-based IPC is most reliable for large outputs | Agree | Agree | Agree | VERIFIED |
| MCP bridging provides best structured integration | Agree | Agree (documented) | Agree | VERIFIED |
| Git worktree isolation prevents file conflicts | Agree | Agree | Agree | VERIFIED |
| Gemini should only run read-only (-p mode) | Agree | N/A | Agree (with caveats) | HIGH |

### SQ-5: Sprint State Machine
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| spec->plan->implement->test->review->deploy is viable | Agree | Agree | Agree (Superpowers as example) | VERIFIED |
| Human checkpoints between stages are essential | Agree | Agree | Agree (84% merge with HITL vs 25% without) | VERIFIED |
| Adversarial debate fits between implement and review | Agree | N/A | Agree | HIGH |
| Temporal/durable execution engines are the best backend | N/A | N/A | Agree (but limited evidence) | UNCERTAIN |

### SQ-6: Sandboxed Execution
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Codex uses Apple Seatbelt (macOS) for sandboxing | Agree | Agree (documented) | Agree | VERIFIED |
| Git worktrees are universal isolation primitive | Agree | Agree | Agree | VERIFIED |
| E2B/Firecracker is production standard for cloud | Agree | N/A | Agree | HIGH |
| nsjail is best for Linux process isolation | Agree | N/A | Agree | HIGH |

### SQ-7: Automated Rollback
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Feature flags are fastest rollback mechanism | Agree | N/A | Agree | HIGH |
| GitOps revert is the simplest pattern | Agree | Agree | Agree | VERIFIED |
| Blue-green deployment enables instant environment switch | Agree | N/A | Agree | HIGH |
| AI-powered pre-commit hooks catch hallucinated dependencies | N/A | N/A | Agree (Gemini only) | UNCERTAIN |

### SQ-8: Context Window Optimization
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Subagent isolation outperforms single agent by 90.2% (Anthropic) | Agree | N/A | Agree | HIGH |
| Context rot degrades all models — 30%+ for mid-context info | Agree | Agree | Agree | VERIFIED |
| WarpGrep reduces context rot by 70% | Agree | N/A | Agree | HIGH |
| Subagent overhead can exceed savings (45% rule) | Counter-claim | Agree (DORA, MIT) | Agree | CONTESTED |
| File-based state passing is the most effective inter-agent pattern | Agree | Agree | Agree | VERIFIED |

### SQ-9: Failure Modes
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Agentic drift is the most insidious failure mode | Agree | Agree | Agree | VERIFIED |
| 40% of multi-agent pilots fail within 6 months | Agree | N/A | Agree | HIGH |
| Merge tax is superlinear (N(N-1)/2 conflicts) | Agree | Agree | Agree | VERIFIED |
| Circuit breakers need semantic awareness, not just HTTP errors | Agree | N/A | Agree | HIGH |

### SQ-10: Real Practitioner Examples
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| obra/superpowers is leading skill suite (25+ skills) | Agree | N/A | Agree (case study) | HIGH |
| Claude Squad / Gas Town are mature orchestrators | Agree | N/A | Agree | HIGH |
| Multi-model setups reduce costs 40-60% vs Opus-only | Agree | N/A | Agree | HIGH |

### SQ-11: MCP vs Skills
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| MCP and Skills are complementary, not competing | Agree | Agree | Agree | VERIFIED |
| MCP provides access, Skills provide methodology | Agree | Agree | Agree | VERIFIED |
| MCP progressive discovery (Jan 2026) closed context gap | Agree | N/A | Agree | HIGH |

### SQ-12: ICML Paper on Instruction Length
| Claim | Claude | Codex | Gemini | Score |
|---|---|---|---|---|
| Paper exists: arXiv:2602.11988 (ETH Zurich, Feb 2026) | Agree | N/A | Agree | VERIFIED |
| Context files REDUCE success rates (not improve) | Agree (verified via WebFetch) | N/A | Disagree (Gemini quoted 22% decrease, implying different metric) | CONTESTED |
| "300 words" is a specific finding in the paper | DEBUNKED | N/A | Reported it as finding | DEBUNKED |
| The paper recommends "minimal requirements only" | Agree (verified) | N/A | Agree | VERIFIED |
| LLM-generated context files reduce success by 0.5-2%, increase cost 20%+ | Agree (verified) | N/A | N/A | HIGH |

## Summary Counts
- VERIFIED: 22
- HIGH: 18
- CONTESTED: 3
- UNCERTAIN: 2
- DEBUNKED: 1
