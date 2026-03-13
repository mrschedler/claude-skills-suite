---
name: perf-review
description: Scans for N+1 queries, missing indexes, memory leaks, O(n²) loops, caching gaps, and DB query issues. Use before deploys or after implementation sprints.
---

# Performance Review

## Purpose

Find performance problems before users do. This skill scans for common performance
anti-patterns across backend, frontend, and database layers. AI-generated code frequently
introduces N+1 queries, unbounded allocations, and O(n²) loops that pass functional tests
but collapse under load. This skill catches what profilers would find — without needing
to run the app.

## Inputs

- The full codebase
- `project-context.md` — to understand the deployment environment and expected scale
- Database schema files (migrations, schema.prisma, models.py, etc.) if present
- ORM configuration and query files
- Frontend build config (webpack, vite, next.config, etc.) if present

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'perf-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings:
  - Sonnet: `db_upsert 'perf-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'perf-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'perf-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'perf-review' 'findings' 'standalone')
```
If `$AGE` is non-empty and less than 24, report: "Found fresh perf-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB. If no record exists or user says no, proceed with a fresh scan.

### 1. Load Context

Read `project-context.md` to understand:
- What's the expected load? (10 users vs 10,000 vs 10M)
- What's the tech stack? (This determines which checks apply)
- Is there a database? What type? (SQL, NoSQL, graph)
- Is there a frontend? What framework?
- What are the deployment constraints? (RAM limits, cold starts, edge functions)

This shapes severity — an O(n²) loop on 10 items is LOW; on 100K items is CRITICAL.

### 2. Query Performance

Scan for database query anti-patterns:

**N+1 Queries**
- ORM calls inside loops (e.g., `for user in users: user.posts.all()`)
- GraphQL resolvers that fetch related data per-item without DataLoader
- Nested `.find()` / `.findOne()` calls in iteration

**Missing Indexes**
- Columns used in WHERE, JOIN, ORDER BY without corresponding index definitions
- Composite queries where column order doesn't match index order
- Text search on unindexed string columns

**Unbounded Queries**
- `SELECT *` without LIMIT
- Missing pagination on list endpoints
- Queries that could return unbounded result sets

**Query Plan Issues**
- Full table scans where index scans are possible
- Implicit type casting in WHERE clauses (prevents index use)
- OR conditions that prevent index merge

Read `references/perf-patterns.md` for the full backend anti-pattern catalog with
framework-specific examples.

### 3. Memory & Allocation

Scan for memory-related performance issues:

- **Unbounded buffers**: Arrays/lists that grow without size limits
- **Large object retention**: Objects held in memory longer than needed (closures, event listeners not cleaned up)
- **String concatenation in loops**: Building strings with `+=` instead of builders/join
- **Unnecessary copies**: Deep cloning where shallow would suffice, or spreading large objects
- **Stream misuse**: Loading entire files/responses into memory instead of streaming
- **Global caches without eviction**: Maps/objects used as caches that grow forever

### 4. Algorithmic Complexity

Scan for complexity issues:

- **O(n²) nested loops**: Especially on collections that could grow (sort+filter chains, nested finds)
- **Redundant computation**: Same expensive calculation repeated without memoization
- **Missing early exits**: Loops that continue after finding the target
- **Inefficient data structures**: Using arrays for lookup-heavy operations instead of Sets/Maps
- **Recursive without memo**: Recursive functions with overlapping subproblems and no caching

### 5. Caching

Evaluate caching strategy:

- **Missing cache layers**: Expensive computations or external API calls repeated every request
- **Cache invalidation gaps**: Data changes but cache is never cleared
- **Over-caching**: Caching data that changes frequently or is cheap to compute
- **Missing HTTP caching headers**: Static assets without Cache-Control/ETag
- **No request deduplication**: Identical concurrent requests not batched (thundering herd)

### 6. Frontend Rendering (conditional)

Only run this section if frontend files exist (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`).

Read `references/frontend-perf.md` for the full frontend anti-pattern catalog.

- **Unnecessary re-renders**: Components re-rendering when props haven't changed, missing React.memo/useMemo/useCallback where justified by profiling
- **Large bundle size**: Unshaken imports, missing code splitting, importing entire libraries for one function
- **Layout thrashing**: Alternating DOM reads and writes, forced synchronous layouts
- **Unoptimized images**: Large images without lazy loading, missing srcset, uncompressed formats
- **Blocking resources**: Render-blocking CSS/JS, missing async/defer on scripts
- **Client-side over-fetching**: Fetching full objects when only a few fields are needed

### 7. Payload & Serialization

Scan for data transfer issues:

- **Over-fetching**: API responses returning entire objects when clients need 2-3 fields
- **Missing compression**: Large responses without gzip/brotli
- **Redundant serialization**: Converting to/from JSON multiple times in a pipeline
- **Missing pagination**: List endpoints returning unbounded arrays
- **Large payloads in loops**: Sending/receiving large objects per-iteration instead of batching

### 8. Concurrency & I/O

Scan for concurrency and I/O patterns:

- **Sync I/O in async paths**: Blocking file reads, synchronous HTTP calls in async handlers
- **Sequential where parallel is possible**: `await` in loops instead of `Promise.all` / `asyncio.gather`
- **Connection pool exhaustion**: Not returning connections, pools too small for concurrency
- **Missing timeouts**: External calls without timeout (can hang indefinitely)
- **Lock contention**: Broad locks where fine-grained would suffice
- **Chatty APIs**: Multiple sequential API calls that could be batched into one

### 9. Database-Specific Analysis

If database schema files or migration files exist:

- **Missing indexes on foreign keys**: FK columns without indexes (common in ORMs that auto-create FKs but not indexes)
- **Over-indexing**: Too many indexes on write-heavy tables (slows inserts/updates)
- **Schema anti-patterns**: EAV pattern, polymorphic associations without proper indexing, JSON columns queried with WHERE
- **Connection management**: Missing connection pooling, pool size mismatched to workload
- **Migration performance**: Migrations that lock tables for extended periods (adding columns with defaults, index creation without CONCURRENTLY)

### 10. Produce Findings

Write findings with this structure per finding:

```
## [SEVERITY] Finding Title

**Category**: Query Performance | Memory & Allocation | Algorithmic Complexity |
  Caching | Frontend Rendering | Payload & Serialization | Concurrency & I/O | Database
**Location**: file/path:line

**Problem**: What the performance issue is, specifically.

**Impact**: Estimated effect under load — what breaks and at what scale.

**Evidence**: Code snippet showing the anti-pattern.

**Recommendation**: How to fix it. Include code examples for non-obvious fixes.
```

Severity levels:
- **CRITICAL** — Will cause outages, OOM, or timeouts under expected load. Blocks deployment.
- **HIGH** — Significant degradation that users will notice. Fix before next milestone.
- **MEDIUM** — Performance debt that compounds over time. Fix when touching this code.
- **LOW** — Optimization opportunity. Nice-to-have, not blocking.

### 11. Summarize

End with:
- Summary table of findings by severity and category
- Top 3 highest-impact findings with estimated scale impact
- "Quick wins" list — findings that are easy to fix with high payoff
- Overall performance posture: BLOCK (any CRITICAL) | REVIEW (HIGHs) | CLEAN

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings as `db_upsert 'perf-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each stores findings under label `sonnet`/`codex`/`gemini`. The meta-review skill handles synthesis.

## References (on-demand)

Read these files only when needed for the relevant section:
- `references/perf-patterns.md` — Full backend anti-pattern catalog: query patterns, memory patterns, concurrency patterns, with framework-specific examples (Django, Rails, Express, FastAPI, Spring)
- `references/frontend-perf.md` — Frontend performance anti-patterns: React, Vue, Svelte specifics, bundle analysis, Core Web Vitals impact

## Examples

```
User: Check for performance issues before we launch.
→ Full audit across all categories. Produce prioritized findings. Report BLOCK/REVIEW/CLEAN verdict.
```

```
User: Our API is slow. Review the database queries.
→ Emphasis on Query Performance (§2) and Database-Specific Analysis (§9). Still scan other areas but prioritize DB.
```

```
User: The React app feels sluggish.
→ Emphasis on Frontend Rendering (§6), Payload & Serialization (§7). Check bundle size and re-render patterns.
```

```
User: We're about to scale from 100 to 10,000 users. What will break?
→ Full audit with scale-aware severity. O(n) patterns that are fine at 100 become CRITICAL at 10K.
  Emphasis on caching, connection pools, query patterns.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
