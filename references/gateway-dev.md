# Homelab MCP Gateway — Development Rules

These rules apply whenever working with the Homelab MCP Gateway, Tower (Unraid), or any `ssh-tower`/`remote-ssh`/`gateway_call`/`mcp-gateway` tools.

## Git Workflow (MANDATORY)

- **Source of truth**: GitLab CE on Tower at `/opt/homelab-mcp-gateway/`
- ALL code changes MUST be committed to GitLab BEFORE deploying
- NEVER edit files on Tower and rebuild without committing first
- The CI/CD pipeline builds the Docker image on push to main — NEVER skip this
- GitHub sync is handled by CI — do NOT manually push sanitized code to GitHub
- Work on feature branches for non-trivial changes; merge to main when ready
- Git commands on Tower require: `export GIT_DIR=/opt/homelab-mcp-gateway/.git GIT_WORK_TREE=/opt/homelab-mcp-gateway` (SSH MCP doesn't preserve `cd`)
- CF Access blocks git push on public GitLab URL — use internal Docker IP: `http://oauth2:TOKEN@$(docker inspect gitlab-ce --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')/...`
- Disable Auto DevOps on new GitLab projects (`auto_devops_enabled: false` via API)

## Secret Handling (MANDATORY)

- NEVER hardcode API keys, tokens, channel IDs, webhook UUIDs, or passwords in source code
- All secrets come from environment variables (`process.env.X || ""`) or Vault
- Docker-internal hostname fallbacks (`|| "http://service:port"`) are acceptable — they are not secrets
- When adding new config, add the env var to `.env` on Tower and `.env.example` in the repo
- Dify workflow keys, n8n webhook IDs, and Mattermost channel IDs should be env vars (not source-embedded lookup tables) — this is a known gap being fixed
- If you see hardcoded keys in existing code (DIFY_SECTION_KEYS, N8N_WEBHOOK_IDS, MM_CHANNELS), treat them as technical debt, not a pattern to follow

## Tower Access

- Path: `/opt/homelab-mcp-gateway/`
- SSH tools: `remote-ssh`, `ssh-read-lines`, `ssh-write-chunk`, `ssh-edit-block`, `ssh-search-code`
- Gateway tools: `gateway_call` -> `read_file`/`write_file` for direct filesystem access
- Deploy: use `/deploy-gateway` skill
- Build: GitLab CI on push to main (manual build only if CI is broken)

## Container & Networking Constraints

- **Unraid has NO docker compose** — use `docker build` + `docker run` with `--env-file`
- **Container network**: `traefik_proxy` (NEVER `br0`, NEVER port-map with `-p`)
- **Traefik + Cloudflare**: Cloudflare terminates SSL. Traefik listens on HTTP only. NEVER add `entrypoints=https`, `tls=true`, or `tls.certresolver` labels
- **3 Traefik labels are MANDATORY** on gateway deploy: `traefik.enable=true`, `traefik.http.routers.mcp-gateway.rule=Host(...)`, `traefik.http.services.mcp-gateway.loadbalancer.server.port=3500`
- Container name `homelab-mcp-gateway` is fixed — never change it
- PG host is `pgvector-18` (not `postgres`) — check `POSTGRES_HOST` env var

## Notifications

- **ALL notifications go to Mattermost** via `mm-notify.ts` — ntfy is DEAD
- DO NOT use ntfy for anything — no ntfy API calls, no ntfy env vars, no ntfy webhooks
- Channels: `pipeline-updates`, `human-review`, `alerts`, `dev-logs`, `deliverables`, `to-do`, `queue`
- Bot token: `MATTERMOST_BOT_TOKEN` env var, internal URL: `http://mattermost:8065`
- Functions named `ntfyNotify`/`ntfyError` in projects.ts/workspaces.ts are vestigial names — they call Mattermost internally

## Known Gotchas

- **`ssh-edit-block` is unreliable** — reports success but often doesn't change the file. Use `python3 -c` with file read/replace/write as the reliable alternative
- **SSH MCP heredoc/multiline psql silently fails** — always use single-line `-c "..."` commands for psql, one statement per call
- **MCP sessions are in-memory** — container restart means all clients must reconnect (auto-recovery is implemented in index.ts)
- **Dify UUID regex bug** — `VARIABLE_PATTERN` needs `-` in character class. Patch lost on container recreation. Run `/patch-dify` after any Dify upgrade
- **Dify API endpoint**: `http://dify-api:5001/v1/workflows/run` (NOT dify-nginx)
- **Dify workflow variables**: use `{{#nodeId.variableName#}}` syntax — plain `{var}` is literal text
- **n8n API-created webhooks**: path-only URL format (`/webhook/{path}`), NOT `/{wfId}/webhook/{path}`
- **n8n EXECUTIONS_MODE=queue breaks webhooks** — use `regular` mode for single-container setups

## Deploy Discipline — Background Jobs (MANDATORY)

- **Pushing to GitLab triggers CI which rebuilds the image** — this does NOT auto-restart the container, but deploying the new image WILL kill any in-flight background jobs (curator, build_knowledge_base, discover_*, etc.)
- **If a pipeline job is running**: commit and push code to GitLab freely (CI build is fine), but DO NOT redeploy the container until the job finishes or errors out
- **Batch changes**: if multiple improvements come up while a job is running, accumulate them all in commits — deploy once after the job completes, not per-change
- **If the job errors or loops**: OK to kill and redeploy immediately to fix the issue
- **Track pending deploy notes**: if changes are committed but not yet deployed (waiting on a running job), note what's queued so nothing gets forgotten

## Code Review Workflow

When reviewing or modifying gateway source code:
1. Read the file from Tower via SSH MCP first — understand current state
2. Make changes via `ssh-write-chunk` or `python3 -c` file write
3. Run `npx tsc` to check for TypeScript errors
4. Commit to GitLab with descriptive message
5. CI builds the image automatically
6. Deploy with `/deploy-gateway` if immediate deploy needed
