---
name: integration-review
description: Checks for dead wiring, missing config/env entries, incomplete teardown, and unbundled assets. Use before deployment or after implementation sprints.
---

# Integration Review

Catch the class of bugs where code exists but isn't connected. This addresses the
second most common failure mode in LLM-assisted development (after stubs/placeholders):
functions that are written but never called, config keys that are defined but never read,
environment variables referenced but not documented, resources opened but never closed,
and sidecar binaries referenced but not bundled. These pass linting, type-checking, and
even unit tests — they only fail at integration time or in production.

## Inputs

- The full codebase
- `project-plan.md` — to verify that planned integrations are actually wired
- `features.md` — to trace feature flows end-to-end
- `.env.example` / `.env.*` files — to verify env var documentation
- Build config files (`tauri.conf.json`, `package.json`, `Cargo.toml`, `docker-compose.yml`, etc.)

## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  ```bash
  source artifacts/db.sh
  db_upsert 'integration-review' 'findings' 'standalone' "$FINDINGS_CONTENT"
  ```
- **Multi-model mode** (called by meta-review): Store per-model findings:
  - Sonnet: `db_upsert 'integration-review' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert 'integration-review' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert 'integration-review' 'findings' 'gemini' "$CONTENT"`

## Instructions

### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
```bash
source artifacts/db.sh
AGE=$(db_age_hours 'integration-review' 'findings' 'standalone')
```
If `$AGE` is non-empty and less than 24, report: "Found fresh integration-review findings from $AGE hours ago. Reuse them? (y/n)"
If the user says yes, read findings from DB. If no record exists or user says no, proceed with a fresh scan.

### Phase 1: Map the Codebase Surface

Before checking wiring, build a map of what exists:

1. **Identify all exports** — functions, classes, constants, types exported from each module.
2. **Identify all imports** — what each file imports and from where.
3. **Identify all config reads** — environment variables read via `process.env`, `os.environ`, `env::var`, config file reads, CLI flag parsing.
4. **Identify all resource acquisitions** — DB connections, file handles, event listeners, timers, WebSocket connections, PTY sessions, child processes.
5. **Identify build/bundle config** — `tauri.conf.json` bundles, `package.json` bin/files entries, `Cargo.toml` [[bin]] targets, Dockerfile COPY directives, CI artifact uploads.

Read `references/wiring-patterns.md` for language-specific patterns to scan for.

### Phase 2: Dead Wiring Detection

For each export identified in Phase 1, verify it has at least one consumer:

1. **Unused exports** — functions/classes/constants exported but never imported anywhere. Exclude entry points (main, index, route handlers, CLI commands) and framework-required exports (React components in route files, test exports).
2. **One-way integrations** — module A imports from B, but the imported value is assigned and never used (imported but not called/referenced in any code path).
3. **Orphaned event handlers** — event listeners registered (`on`, `addEventListener`, `subscribe`) but the event is never emitted from the expected source.
4. **Registered but unreachable routes** — API routes/commands defined in a registry but missing the handler implementation, or handler exists but is never registered.
5. **Placeholder session/ID values** — hardcoded strings like `'axys-server'`, `'test-session'`, `'default'`, `'TODO'`, `'placeholder'` used where a dynamic value (real session ID, PTY handle, connection ref) should be wired.

Read `references/wiring-patterns.md` for framework-specific dead wiring patterns (React, Tauri, Express, FastAPI, etc.).

### Phase 3: Config & Environment Completeness

1. **Env var documentation** — for every `process.env.X` / `os.environ['X']` / `env::var("X")` in code, verify `X` appears in `.env.example` with a documented default or description. Flag any env var in code but not in `.env.example`.
2. **Env var usage** — for every key in `.env.example`, verify it is actually read somewhere in code. Flag documented-but-unused env vars (dead config).
3. **Config key wiring** — for config objects/files that define keys, verify each key is consumed by application code. Flag config keys that are defined but never read.
4. **Feature flag completeness** — if the project uses feature flags, verify each flag has: a definition, at least one check in code, and a documented default.
5. **Secret references** — verify that secret paths referenced in code (Vault paths, AWS SSM paths, etc.) match what's documented. Flag hardcoded secrets as CRITICAL.

Read `references/config-completeness.md` for the full checklist by config type.

### Phase 4: Resource Lifecycle & Teardown

For each resource acquisition identified in Phase 1, trace its lifecycle:

1. **Open without close** — DB connections opened but never closed (missing `finally`, `defer`, `Drop`, `useEffect` cleanup). Check both success and error paths.
2. **Event listener leaks** — `addEventListener`/`on`/`subscribe` without corresponding `removeEventListener`/`off`/`unsubscribe` in cleanup paths. Especially critical in React `useEffect` returns, server shutdown handlers, and test `afterEach` blocks.
3. **Timer leaks** — `setInterval`/`setTimeout` without `clearInterval`/`clearTimeout` in cleanup. Check React component unmount, server shutdown, and test teardown.
4. **Child process orphans** — child processes spawned (`spawn`, `exec`, `fork`, PTY sessions) without kill/cleanup in error paths and shutdown handlers.
5. **Incomplete shutdown sequences** — server/app shutdown handlers that close some resources but not all. Verify the shutdown handler covers every resource type opened during startup.
6. **Test teardown gaps** — test `beforeEach`/`beforeAll` that acquire resources without corresponding `afterEach`/`afterAll` cleanup. Check for leaked DB connections, unclosed servers, and dangling event listeners between tests.

Read `references/teardown-patterns.md` for language-specific lifecycle patterns.

### Phase 5: Bundle & Build Completeness

1. **Sidecar/binary bundles** — if the project references sidecar binaries (Tauri `sidecar`, Electron `extraResources`, etc.), verify every referenced binary appears in the bundle config with correct target triples.
2. **Asset references** — images, fonts, templates, migration files referenced in code must exist on disk at the referenced path AND be included in the build output (not just source).
3. **Build artifact completeness** — if the project produces multiple outputs (app binary + CLI tool, server + worker, etc.), verify each has a build target and isn't silently skipped.
4. **Dependency bundling** — native dependencies, FFI libraries, WASM modules referenced in code must be in the build pipeline. Flag native deps that are `require`d/`import`ed but not in `package.json`/`Cargo.toml`/`requirements.txt`.
5. **Docker/container completeness** — if Dockerfiles exist, verify COPY directives include all files the app needs at runtime. Flag files read by the app that aren't copied into the container.

### Phase 6: Feature Flow Verification

For each feature in `features.md` marked as done or in-progress:

1. **Trace the full integration path** — from user action → UI handler → API call → business logic → data layer → response → UI update. Verify every hop in the chain is wired (not just that each piece exists independently).
2. **Cross-boundary wiring** — where the feature crosses process boundaries (frontend→backend, app→sidecar, service→database), verify the protocol/API contract matches on both sides. Flag mismatched types, missing fields, or different endpoint paths.
3. **Error propagation** — verify errors at each layer propagate correctly to the user. Flag errors that are caught and silently swallowed mid-chain, or that propagate as generic "something went wrong" when specific context is available.

### Phase 7: Produce Findings

Format each finding:

```
## [SEVERITY] Finding Title

**Category**: Dead Wiring | Config Gap | Teardown Leak | Bundle Gap | Broken Flow | Placeholder Value
**Location**: file/path:line

**What exists**: The code/config that was written.

**What's missing**: The connection, cleanup, or config entry that should exist but doesn't.

**Evidence**: The specific export with no importer, the env var with no .env.example entry,
the addEventListener with no removeEventListener, etc.

**Impact**: What breaks in production because of this gap.

**Recommendation**: Specific fix — what to add/connect/wire, with target file and approach.
```

Severity levels:
- **CRITICAL** — Resource leak in production path (DB connection, child process), missing secret config, hardcoded credential, sidecar not bundled (app won't start)
- **HIGH** — Dead wiring on a feature's critical path (feature silently doesn't work), env var used but undocumented, event listener leak in long-running process
- **MEDIUM** — Unused exports (dead code), config defined but never read, timer leak in short-lived context, test teardown gap
- **LOW** — Aspirational config keys, unused type exports, redundant event listener registration

### Summarize

End with:
- Count by category (Dead Wiring, Config Gap, Teardown Leak, Bundle Gap, Broken Flow, Placeholder Value)
- Count by severity
- Integration health score — percentage of traced flows that are fully wired end-to-end
- Top 5 most critical gaps (the ones that would cause production failures)
- Overall assessment: is integration complete, or does it need a wiring pass?

## Execution Mode

- **Standalone**: Spawn the `review-lens` agent (`subagent_type: "review-lens"`) with this skill's lens instructions and input files. Stores findings in DB as `db_upsert 'integration-review' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs the Sonnet review, while Codex (`/codex`) and Gemini (`/gemini`) run in parallel with the same prompt. Each model stores findings in DB under label `sonnet`, `codex`, or `gemini`. The meta-review skill handles synthesis.

## References (on-demand)

Read these files only when needed for the relevant phase:
- `references/wiring-patterns.md` — Language/framework-specific export, import, and dead wiring detection patterns
- `references/teardown-patterns.md` — Resource lifecycle patterns by language and framework
- `references/config-completeness.md` — Environment variable, config file, and bundle entry checklists

## Examples

```
User: Check if everything is actually wired together before we deploy.
→ Full integration review. All 7 phases. Emphasis on dead wiring and bundle completeness.
```

```
User: We built the PTY integration but it feels flaky — check the wiring.
→ Emphasis on Phase 2 (placeholder session IDs), Phase 4 (PTY teardown), and Phase 6 (feature flow).
```

```
User: Run integration-review on the Tauri app.
→ Full review with emphasis on Phase 5 (sidecar bundles, asset references) and Phase 2 (IPC wiring).
```

```
User: After the last sprint, make sure nothing got left disconnected.
→ Post-sprint integration audit. All phases, with Phase 6 (feature flow) as primary focus.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
