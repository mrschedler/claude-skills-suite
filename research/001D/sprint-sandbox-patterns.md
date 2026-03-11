**1) Sprint State Machine (Spec → Plan → Implement → Test → Debug → Review → Deploy)**  
State flow:
```text
SPEC -> PLAN -> IMPLEMENT -> TEST -> REVIEW -> DEPLOY
                    ^         |        |
                    |         v        v
                    +---- DEBUG <--- (changes requested)
DEPLOY --incident/rollback--> DEBUG
```

**Recommended gates, debates, and human checkpoints (inference from sources):**

| Transition | Gate condition | Adversarial debate placement | Human checkpoint |
|---|---|---|---|
| `SPEC -> PLAN` | Scope, non-goals, acceptance criteria, risk tier documented (SSDF/AI RMF lifecycle discipline) | Optional “requirements skeptic” on high-risk specs | Product/security owner sign-off for medium/high risk |
| `PLAN -> IMPLEMENT` | Task graph, rollback plan, test plan, sandbox profile selected | **Debate #1 (required):** “builder vs breaker” challenge on plan assumptions (debate evidence + NIST adversarial testing mindset) | Approve any sandbox/network escalation policy |
| `IMPLEMENT -> TEST` | Build passes, lint/static checks pass, changes isolated (worktree/branch) | None | None |
| `TEST -> DEBUG` | Any failing functional/security/regression checks | **Debate #2:** “fix proposer vs critic” before patching flaky/high-impact failures | None |
| `TEST -> REVIEW` | Required checks green; evidence bundle attached (test logs, risk notes, provenance where applicable) | Optional | Reviewer assignment locked |
| `REVIEW -> DEPLOY` | Required PR approvals + required status checks + deployment policy pass | **Debate #3 (high-risk only):** pre-deploy adversarial/red-team pass | Required reviewers for protected deployment environment |
| `DEPLOY -> (done)` | Staged rollout/canary + monitoring healthy | None | Release approver (ops/SRE) |
| `DEPLOY -> DEBUG` | Incident trigger, rollback, or SLO breach | Post-incident adversarial replay | Incident commander approval |

Why these placements:
- Multi-agent debate is shown to improve reasoning/factuality outcomes in model outputs, so use it at decision-heavy points, not everywhere ([Du et al., ICML 2024](https://proceedings.mlr.press/v235/du24e.html)).  
- NIST GAI profile emphasizes regular adversarial testing and explicit pre-deployment red-teaming contexts, supporting pre-deploy debate/red-team gates ([NIST AI 600-1](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf)).  
- Human approval gates align with protected branches/deployments in GitHub ([protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), [deployments/environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)).

---

**2) Sandbox Options + Isolation Level Per Sprint Stage**

Isolation levels (practical):
- `L1`: Workspace policy only (Codex read-only/workspace-write).
- `L2`: Process jail (OS sandbox / nsjail).
- `L3`: Container or microVM.
- `L4`: Ephemeral VM per job.

| Stage | Target isolation | Recommended stack |
|---|---|---|
| `SPEC`, `PLAN` | `L1` | Codex `read-only` + restrictive approvals (`untrusted`/`on-request`) ([config](https://developers.openai.com/codex/config-reference), [approvals](https://developers.openai.com/codex/agent-approvals-security)) |
| `IMPLEMENT` | `L1-L2` | Codex `workspace-write` in dedicated git worktree; keep `.git` protected; no network by default ([approvals](https://developers.openai.com/codex/agent-approvals-security), [worktrees](https://developers.openai.com/codex/app/worktrees), [git-worktree](https://git-scm.com/docs/git-worktree.html)) |
| `TEST` | `L2-L3` | nsjail for untrusted test binaries/fuzzing; Docker with seccomp/userns hardening for integration tests ([nsjail](https://github.com/google/nsjail), [Docker seccomp](https://docs.docker.com/engine/security/seccomp/), [Docker userns](https://docs.docker.com/engine/security/userns-remap/)) |
| `DEBUG` | `L2-L3` | Same as `TEST`; use disposable Docker sandbox/microVM when reproducing risky behavior ([Docker Sandboxes](https://docs.docker.com/ai/sandboxes/), [docker sandbox create codex](https://docs.docker.com/reference/cli/docker/sandbox/create/codex/)) |
| `REVIEW` | `L1-L2` | Read-only analysis + CI evidence verification in isolated runners |
| `DEPLOY` | `L4` | Ephemeral VM runners + protected deployment approvals ([GitHub-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/use-github-hosted-runners), [runner model](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners), [GitLab hosted runners](https://docs.gitlab.com/ee/ci/runners/hosted_runners/)) |

Notes on each option:
- **Codex CLI sandbox modes**: `read-only`, `workspace-write`, `danger-full-access`; approvals are independently controlled (`untrusted`, `on-request`, `never`, etc.) ([config reference](https://developers.openai.com/codex/config-reference), [agent approvals](https://developers.openai.com/codex/agent-approvals-security)).  
- **Git worktrees**: excellent parallelism/isolation of working copies; **not** a hard security boundary (shared repo metadata model) ([git-worktree](https://git-scm.com/docs/git-worktree.html)).  
- **nsjail**: strong Linux process isolation using namespaces, seccomp-bpf, cgroups ([nsjail](https://github.com/google/nsjail)).  
- **Docker**: baseline container isolation; improve with seccomp/userns; Docker Sandboxes add microVM boundary ([Docker seccomp](https://docs.docker.com/engine/security/seccomp/), [userns](https://docs.docker.com/engine/security/userns-remap/), [Sandboxes](https://docs.docker.com/ai/sandboxes/)).  
- **Ephemeral VMs**: strongest reset/isolation for CI/CD deploy path; new VM/container per job then decommissioned ([GitHub](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/use-github-hosted-runners), [GitLab](https://docs.gitlab.com/ee/ci/runners/hosted_runners/)).  

Also relevant governance baselines for gates/traceability: [NIST SSDF (SP 800-218)](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf), [NIST AI RMF 1.0](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf), [NIST GAI Profile](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf).

**Source Tally**
- OpenAI/Codex docs: 4  
- NIST standards/frameworks: 3  
- Platform/infra docs (Docker, Git, GitHub, GitLab): 9  
- Academic research papers: 1  
- **Total sources cited: 17**
