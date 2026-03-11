1) **Against “consolidating 37 skills into fewer is always better” (granularity won in some cases)**  
- DORA reports better delivery outcomes when architecture/team structure is loosely coupled and deployable independently, explicitly favoring smaller, separable units over tight consolidation ([DORA](https://dora.dev/capabilities/loosely-coupled-teams/)).  
- Google/DeepMind/MIT’s controlled agent-scaling study found centralized multi-agent setups improved parallelizable tasks by ~80.8%, so specialization/decomposition can beat a single consolidated agent in the right task shape ([arXiv 2512.08296](https://arxiv.org/abs/2512.08296), [Google Research summary](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/)).  
- Fowler documents “strong module boundaries” and “independent deployment” as real microservice benefits (while also noting costs), i.e., granularity can outperform monolithic consolidation in some org contexts ([Fowler](https://martinfowler.com/articles/microservice-trade-offs.html)).

2) **Against “progressive disclosure/lazy loading is best” (where eager loading was simpler)**  
- SQLAlchemy states lazy loading commonly creates N+1 query problems, and eager loading is the usual mitigation ([SQLAlchemy](https://docs.sqlalchemy.org/en/21/orm/queryguide/relationships.html)).  
- SQLAlchemy also says `selectin` eager loading is, in most cases, the simplest and most efficient way to load collections ([SQLAlchemy](https://docs.sqlalchemy.org/en/21/orm/queryguide/relationships.html)).  
- Django docs: `select_related` pulls related rows in the same query to avoid query explosions; this is often simpler operationally than many lazy fetches ([Django](https://docs.djangoproject.com/en/5.1/ref/models/querysets/)).

3) **Against “subagent isolation solves context limits” (overhead exceeded savings)**  
- The same Google/DeepMind/MIT paper finds explicit coordination overhead penalties: tool-heavy tasks suffer from multi-agent overhead; sequential reasoning degraded by 39–70% across multi-agent variants; independent topologies amplified errors 17.2x ([arXiv 2512.08296](https://arxiv.org/abs/2512.08296)).  
- A comparative MDPI evaluation reported all tested multi-agent coordination setups underperformed single-agent baselines in that study setup, citing coordination overhead as primary ([MDPI Electronics 2025](https://www.mdpi.com/2079-9292/14/24/4883)).  
Inference: isolation can help, but “always solves context limits” is false; task structure and coordination tax dominate outcomes.

4) **Against “automated sprints are the future” (failures and abandonments)**  
- A PACIS case study documents a distributed team that **abandoned** its Scrum transition; identified causes included degraded Scrum practices in distributed settings and ScrumMaster credibility issues ([PACIS 2013 case](https://aisel.aisnet.org/pacis2013/42/)).  
- BCG (2024): only ~53% of surveyed firms realized agile transformation targets; 47% were in an “illusion of agility” state, indicating broad transformation underperformance ([BCG](https://www.bcg.com/publications/2024/why-companies-get-agile-right-wrong)).  
- Fastly documents Pivotal Tracker integration retirement (effective April 30, 2025) due third-party retirement, showing ecosystem-level abandonment around a major sprint tool ([Fastly changelog](https://www.fastly.com/documentation/reference/changes/2025/01/retirement-of-pivotal-tracker-integration/)).  
- Atlassian’s Scrum guidance still frames sprint planning as human negotiation between product owner and development team, not full automation ([Atlassian](https://www.atlassian.com/agile/scrum/sprint-planning)).  
Inference: current evidence supports augmentation, not “automated sprints as inevitable replacement.”

**Source Tally**  
- Claim 1 (granularity over consolidation): **4 sources**  
- Claim 2 (eager simpler than lazy in cases): **2 sources**  
- Claim 3 (subagent overhead > savings in cases): **2 sources**  
- Claim 4 (automation failures/abandonments): **4 sources**  
- **Unique sources used:** 10
