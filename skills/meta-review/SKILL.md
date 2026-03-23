---
name: meta-review
description: Comprehensive multi-model project review across 10-11 lenses and 3 model families in parallel. Use for full project review, pre-deploy audit, or milestone quality gate. Not for single-lens reviews.
---

# meta-review

Meta-skill that runs SAST pre-scan (Semgrep, SonarQube, local CLIs), then
fans out 10-11 review lenses across 3 model families in parallel with SAST
context injected, then synthesizes into a unified report with confidence scoring.

## Architecture

Sonnet-primary with targeted Codex/Gemini spot-checks on key lenses.

```
                   +-- Semgrep MCP scan
                   +-- SonarQube MCP query (if project exists)
meta-review --> SAST pre-scan --+-- ruff / biome / oxlint / gitleaks (local CLIs)
                   |
                   v  $SAST_SUMMARY injected into all lens prompts
                   |
                   +-- counter-review ------[Sonnet | Gemini]
                   +-- security-review -----[Sonnet | Codex]
                   +-- test-review --------[Sonnet]
                   +-- refactor-review -----[Sonnet | Codex]
                   +-- drift-review -------[Sonnet | Gemini]
                   +-- completeness-review -[Sonnet | Codex]       --> synthesis
                   +-- compliance-review ---[Sonnet]
                   +-- integration-review --[Sonnet | Codex]
                   +-- perf-review --------[Sonnet | Codex]
                   +-- dep-audit ----------[Sonnet | Codex]
                   +-- log-review ---------[Sonnet | Codex]
                   +-- breaking-change ----[Sonnet | Codex]
                   +-- ui-review ----------[Sonnet | Codex]  (frontend only)
```

Total: SAST pre-scan + **20-22 LLM reviews** (12-13 Sonnet + 8-9 Codex + 2 Gemini), then 1 synthesis pass.
ui-review is conditional — only included if frontend files (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`) exist in the project.

**Model assignment rationale:**
- **Sonnet** (all 12-13): primary reviewer, full codebase access, no concurrency limit
- **Codex** (security, refactor, completeness, integration, perf, dep-audit, log-review, breaking-change-review, +ui if frontend): code-centric lenses where static analysis shines
- **Gemini** (counter, drift): architecture/strategy lenses that benefit from web grounding

## Inputs

| Input | Source | Required |
|---|---|---|
| Project root path | cwd or user prompt | Yes |
| project-context.md | Project root | Yes |
| features.md | Project root | Yes |
| project-plan.md | Project root | Recommended |
| Full codebase | Project root | Yes |

## Outputs

- 8-9 lenses x 2-3 models = 16-18 individual lens findings in the artifact DB (skill=`{lens}`, phase=`findings`, label=`sonnet`/`codex`/`gemini`)
- 1 unified synthesis on disk: `artifacts/reviews/review-synthesis-N.md` (incrementally numbered — never overwrites previous runs)

## Instructions

### Phase 1: Preparation

1. Verify the project has the required inputs. If `project-context.md` or
   `features.md` is missing, stop and tell the user to create them first
   (run `/meta-init` or the individual atomic skills).

2. Create the `artifacts/reviews/` directory if it does not exist.

3. Check CLI availability for multi-model execution. Load `/codex`, `/gemini`,
   and `/copilot` for path resolution — each driver skill has the canonical
   discovery pattern. Note which models are available. Copilot is Gemini's
   fallback — if Gemini is unavailable or fails, retry with Copilot before
   skipping. Unavailable models are skipped — synthesis adjusts confidence
   scoring accordingly.

4. Identify the ~10 most important source files for Gemini context. These
   are typically: entry point, main config, core business logic files, auth
   module, database layer, and any file >200 lines. Write this file list —
   Gemini invocations will reference them via `@path/to/file`.

### Phase 1.5: SAST Pre-Scan

Run static analysis tools **before** LLM reviews. Results are injected as
context into every lens prompt so reviewers see real findings, not just vibes.

All 3 steps run in parallel (no dependencies between them):

#### Step 1: Semgrep MCP scan

Call the Semgrep MCP tool directly (Claude has access as a global MCP tool):
```
mcp__semgrep__scan_directory(path: "<project-root>")
```
Store the result. If the tool is unavailable, skip and note in synthesis.

#### Step 2: SonarQube scan + query

Derive the project key from the root folder name (lowercase, e.g.,
`/Users/foo/Projects/Arbytr` → `arbytr`).

**2a. Check if project exists:**
```
mcp__sonarqube__search_my_sonarqube_projects(q: "<project-key>")
```

**2b. If no project exists, create and scan:**
```bash
# Create project via SonarQube API
curl -s -u "$SONARQUBE_TOKEN:" "http://100.127.173.50:9000/api/projects/create" \
  -d "name=<ProjectName>&project=<project-key>"

# Run sonar-scanner (JDK 21 required)
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
npx --yes sonar-scanner \
  -Dsonar.projectKey=<project-key> \
  -Dsonar.projectName=<ProjectName> \
  -Dsonar.sources=. \
  -Dsonar.exclusions="**/node_modules/**,**/dist/**,**/compact/**,**/artifacts/**,**/research/**" \
  -Dsonar.host.url=http://100.127.173.50:9000 \
  -Dsonar.token="$SONARQUBE_TOKEN" 2>&1
```

The token is stored in Vault at `services/sonarqube`. Read it via:
```bash
SONARQUBE_TOKEN=$(vault kv get -field=token services/sonarqube 2>/dev/null)
```
If Vault is unavailable, check env var `SONARQUBE_TOKEN`. If neither exists,
skip SonarQube entirely.

The scan takes ~60s. If JDK is not installed (`java --version` fails), skip.

**2c. Query results** (whether project was pre-existing or just created):
```
mcp__sonarqube__search_sonar_issues_in_projects(
  projects: ["<project-key>"],
  severities: ["HIGH", "BLOCKER"],
  issueStatuses: ["OPEN"]
)
mcp__sonarqube__search_security_hotspots(projectKey: "<project-key>")
```

If SonarQube is unreachable or all steps fail, skip and note in synthesis.

#### Step 3: Local SAST CLIs

Detect project language from file extensions, then run the applicable tools:

**TypeScript/JavaScript projects** (has `package.json` or `tsconfig.json`):
```bash
npx biome lint --reporter=json <project-root> 2>/dev/null > /tmp/sast-biome.json
npx oxlint <project-root> 2>/dev/null > /tmp/sast-oxlint.txt
```

**Python projects** (has `pyproject.toml`, `setup.py`, or `requirements.txt`):
```bash
ruff check --output-format=json <project-root> 2>/dev/null > /tmp/sast-ruff.json
```

**All projects** (secrets scan):
```bash
gitleaks detect --source <project-root> --no-git --report-format json 2>/dev/null > /tmp/sast-gitleaks.json
```

If a tool is not installed or fails, skip it and note in synthesis.

#### Step 4: Assemble SAST summary

Collect all results into a single `$SAST_SUMMARY` string. Format:

```markdown
## SAST Pre-Scan Results

### Semgrep (N findings)
- [severity] rule-id: message (file:line)
...

### SonarQube (N HIGH/BLOCKER issues, M security hotspots)
- [BLOCKER] S2189: 'stopped' is not modified in this loop (file:line)
- [CRITICAL] S3776: Cognitive Complexity 120 exceeds 15 (file:line)
...

### Local Tools
- biome: N issues
- oxlint: N issues
- ruff: N issues
- gitleaks: N secrets detected (CRITICAL — block deploy)
```

Truncate to ~5000 chars max — keep HIGH/BLOCKER/CRITICAL findings, drop
INFO/LOW. This summary is injected into every lens prompt in Phase 2.

If ALL SAST tools were unavailable or returned zero findings, note
"SAST pre-scan: no tools available or zero findings" and proceed — LLM
reviews still run regardless.

### Phase 2: Fan-Out (12 reviews total)

The 7 review lenses with their model assignments:

| Lens | Atomic Skill | Sonnet | Codex | Gemini |
|---|---|---|---|---|
| counter-review | `/counter-review` | YES | — | YES |
| security-review | `/security-review` | YES | YES | — |
| test-review | `/test-review` | YES | — | — |
| refactor-review | `/refactor-review` | YES | YES | — |
| drift-review | `/drift-review` | YES | — | YES |
| completeness-review | `/completeness-review` | YES | YES | — |
| compliance-review | `/compliance-review` | YES | — | — |
| integration-review | `/integration-review` | YES | YES | — |
| perf-review | `/perf-review` | YES | YES | — |
| dep-audit | `/dep-audit` | YES | YES | — |
| log-review | `/log-review` | YES | YES | — |
| breaking-change-review | `/breaking-change-review` | YES | YES | — |
| ui-review | `/ui-review` | YES | YES | — |

**ui-review is conditional** — only include if frontend files exist (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`). Skip for backend-only projects.

**Do NOT add lenses to Codex or Gemini beyond what is listed above.**
Sonnet covers all 12-13. Codex covers 8-9. Gemini covers 2. Total = 20-22 reviews.

---

#### Step 2a: Launch Sonnet subagents (all 7 at once — OK)

Spawn the `review-lens` agent (`subagent_type: "review-lens"`) for each lens.
All 12-13 can run simultaneously — Sonnet subagents have no concurrency limit.

Each agent:
1. Receives the lens name, the atomic skill's review instructions, AND the
   `$SAST_SUMMARY` from Phase 1.5 in the prompt
2. Has full codebase access via Claude tools
3. Uses standardized severity classification and output format
4. Cross-references SAST findings — confirms, disputes, or expands on them
5. Returns findings as text in its response — does NOT write to DB

**DB writes are the main thread's job.** When each subagent returns, the
main thread extracts the findings from the agent's response and writes
them to the artifact DB:
```bash
source artifacts/db.sh
db_upsert '{lens}' 'findings' 'sonnet' "$AGENT_RESPONSE"
```
Subagents do NOT have access to `artifacts/db.sh` or the project DB path.
Never rely on subagents to write to the DB — they will silently fail.

#### Step 2b: Launch Codex (8-9 lenses — max 5 concurrent, queue the rest)

Use the `/codex` skill for invocation syntax.

Total Codex lenses: `security-review`, `refactor-review`,
`completeness-review`, `integration-review`, `perf-review`, `dep-audit`,
`log-review`, `breaking-change-review`, and `ui-review` (if frontend).

**CONCURRENCY: Max 5 Codex processes at a time (hard limit from general.md).**

**Wave 1 (launch immediately, 5 slots):**
`security-review`, `refactor-review`, `completeness-review`, `integration-review`, `perf-review`

**Wave 2 (backfill as Wave 1 slots free — each completion triggers the next):**
`dep-audit`, `log-review`, `breaking-change-review`, `ui-review` (if frontend)

Do NOT launch Wave 2 all at once — backfill one-for-one as each Wave 1
process finishes. If a Wave 1 slot frees up, immediately dispatch the next
queued lens. This keeps 5 slots saturated until the queue is empty.

Each Codex exec:
1. Receives a review prompt assembled from the atomic skill's instructions
   AND the `$SAST_SUMMARY` from Phase 1.5
2. Runs read-only with relevant source directories added
3. Pipes output to a temp file, then stores in DB:
   ```bash
   source artifacts/db.sh && db_upsert '{lens}' 'findings' 'codex' "$(cat /tmp/lens-codex-{lens}.md)" && rm /tmp/lens-codex-{lens}.md
   ```

   Load `/codex` for invocation syntax. Key params: `--sandbox read-only`,
   `--ephemeral`, `--cd <project-root>`, `--add-dir <relevant-dir>`, 120s timeout.
   Prompt: `LENS_PROMPT`. Output to `/tmp/lens-codex-{lens}.md`.

If Codex is unavailable, skip all Codex reviews and note it in synthesis.

#### Step 2c: Launch Gemini (2 lenses — both at once)

Use the `/gemini` skill for invocation syntax and environment safety.

Launch exactly **2** Gemini processes for: `counter-review`, `drift-review`.
Both fit within the 2-slot limit — no queuing needed.

Each Gemini invocation:
1. Receives a prompt file containing: the atomic skill's review instructions,
   the `$SAST_SUMMARY` from Phase 1.5, plus relevant code context via
   `@path/to/file` references (use the file list from Phase 1, max ~10 files)
2. Uses the `/gemini` File Context template. Only force
   `@codebase_investigator` if the current `/gemini` driver says the
   environment supports it.
3. Pipes output to a temp file, then stores in DB as label `gemini`:
   ```bash
   source artifacts/db.sh && db_upsert '{lens}' 'findings' 'gemini' "$(cat /tmp/lens-gemini-{lens}.md)" && rm /tmp/lens-gemini-{lens}.md
   ```

   Load `/gemini` for invocation syntax. Use the current File Context template
   with a 60s timeout and `@file` references. Output to
   `/tmp/lens-gemini-{lens}.md`.

If Gemini is unavailable or fails (timeout, empty output), **retry each
failed lens with Copilot** using the `/copilot` skill. Use the same prompt
and context. Store as label `copilot`:
```bash
source artifacts/db.sh && db_upsert '{lens}' 'findings' 'copilot' "$(cat /tmp/lens-copilot-{lens}.md)" && rm /tmp/lens-copilot-{lens}.md
```
Load `/copilot` for invocation syntax. Key params: `--add-dir <project-root>`,
60s timeout. Prompt: `LENS_PROMPT`. Output to `/tmp/lens-copilot-{lens}.md`.
`copilot` label counts the same as `gemini` for confidence scoring.
If both Gemini and Copilot fail, skip and note it in synthesis.

**Steps 2a, 2b, and 2c all launch simultaneously** — Sonnet (no limit) and
Gemini (2 slots, within limit) go immediately. Codex Wave 1 (5 slots) goes
immediately. Codex Wave 2 backfills one-for-one as Wave 1 slots free up.
Never exceed 5 concurrent Codex processes.

---

### Phase 3: Wait for Completion

All 20-22 reviews must complete before synthesis begins:

- Sonnet: confirm all 12-13 subagents returned
- Codex: confirm 8-9 via DB: `source artifacts/db.sh && db_exists '{lens}' 'findings' 'codex'` for Wave 1 (security, refactor, completeness, integration, perf) and Wave 2 (dep-audit, log-review, breaking-change-review, +ui if frontend)
- Gemini: confirm 2/2 via DB: `source artifacts/db.sh && db_exists '{lens}' 'findings' 'gemini'` for counter, drift

If any individual review fails (timeout, crash, empty output), note the
failure in synthesis but do not block on it. Partial data is better than no
data.

### Phase 4: Synthesis

After all reviews complete, read lens findings from the artifact DB. Each
lens has a different number of models — read only what was assigned:

```bash
source artifacts/db.sh
# All 7 lenses have Sonnet
SONNET=$(db_read '{lens}' 'findings' 'sonnet')
# security, refactor, completeness also have Codex
CODEX=$(db_read '{lens}' 'findings' 'codex')    # only for 3 lenses
# counter, drift also have Gemini
GEMINI=$(db_read '{lens}' 'findings' 'gemini')   # only for 2 lenses
```

**Always create a brand-new, incrementally numbered synthesis file** — never
append to, merge with, or build on top of an existing one. Each meta-review
produces a complete, self-contained synthesis written from scratch.

Naming convention: `artifacts/reviews/review-synthesis-N.md` where N is the
next integer in sequence. Check existing files to determine N:
```bash
ls artifacts/reviews/review-synthesis-*.md 2>/dev/null | sort -t- -k3 -n | tail -1
```
- If no files exist → write `review-synthesis-1.md`
- If `review-synthesis-3.md` is the latest → write `review-synthesis-4.md`

This preserves the full review history so changes can be tracked over time.
The latest file is always the current synthesis.

The synthesis document structure:

#### Confidence Scoring

Confidence depends on how many models reviewed that lens:

| Lens Coverage | Agreement | Confidence |
|---|---|---|
| 2-model lens (Sonnet + Codex/Gemini) | 2/2 agree | **HIGH** |
| 2-model lens | 1/2 flags it | **MEDIUM** |
| 1-model lens (Sonnet only) | Sonnet flags it | **MEDIUM** (no cross-validation) |

For findings that appear across multiple lenses (cross-lens patterns),
confidence is automatically HIGH regardless of per-lens model count.

#### Deduplication

Different models will find the same issue with different wording. Merge
duplicates into a single finding, noting which models flagged it.

#### Cross-Lens Patterns

Look for patterns that span multiple lenses:
- A security finding + a test finding about the same code = high-priority gap
- A drift finding + a completeness finding = likely a feature that was
  partially implemented and then abandoned
- A refactor finding + a counter-review finding = structural issue
  masquerading as multiple smaller problems

Flag cross-lens patterns explicitly — they are higher priority than any
single-lens finding.

#### Synthesis Document Structure

```markdown
# Review Synthesis

## Summary
- Total findings: N (after dedup)
- By confidence: HIGH: X, MEDIUM: Y
- SAST pre-scan: Semgrep (N), SonarQube (N), local tools (N) — or "skipped"
- Reviews completed: 16-18 (10-11 Sonnet + 6-7 Codex + 2 Gemini), note any failures
- Multi-model lenses: security, refactor, completeness, integration, +ui (Codex), counter, drift (Gemini)

## SAST Findings (Pre-Scan)
[BLOCKER/CRITICAL findings from static analysis tools — these are machine-
verified, not LLM opinion. Gitleaks secrets findings are always top priority.]

## Cross-Lens Patterns
[Patterns that span multiple review lenses — highest priority items]

## HIGH Confidence Findings
[Findings flagged by all available models — sorted by severity]

## MEDIUM Confidence Findings
[Findings flagged by 2 of 3 models — sorted by severity]

## Notable LOW Confidence Findings
[Only CRITICAL/HIGH severity findings from a single model — may be
false positives but too important to ignore]

## Per-Lens Summary
[One-paragraph summary per lens with finding counts]

## Recommendations
[Prioritized action list: what to fix first, what can wait, what to ignore]
```

### Phase 5: Report

Present the synthesis to the user. Highlight:
- Total finding count and confidence distribution
- Top 3 highest-priority items (cross-lens patterns first)
- Whether any lenses found zero issues (suspicious — may indicate the
  review prompt was too narrow or the model hallucinated "all clear")

After presenting, suggest: **"Run `/review-fix` to implement approved fixes."**

## Error Handling

- If a model is unavailable, run with remaining models. Adjust confidence
  scoring denominators accordingly.
- If an entire lens fails across all models, flag it as "REVIEW FAILED" in
  synthesis and recommend the user run that lens manually.
- If the project is small (< 5 source files), warn the user that some lenses
  (refactor, compliance) may produce thin results — this is expected, not a
  failure.

## Examples

```
User: "Run a full review before we deploy."
Action: Verify inputs exist. Fan out all 7 lenses x 3 models in parallel.
        Wait for completion. Synthesize. Present prioritized findings.
```

```
User: "Project review — we just finished the MVP."
Action: Same full fan-out. Emphasize completeness-review and drift-review
        since MVP milestones are where planned vs. actual diverge most.
```

```
User: "Audit everything. I don't trust this codebase."
Action: Full review. Call out any lens where all 3 models agree there are
        CRITICAL issues — those are the trust-breakers to address first.
```

```
User: [After meta-init] "Run the review before I start building."
Action: Full review focused on the plan and context docs rather than code
        (since code doesn't exist yet). Counter-review, completeness-review,
        and drift-review are most relevant at this stage.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
