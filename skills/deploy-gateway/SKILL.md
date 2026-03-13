---
name: deploy-gateway
description: Use when deploying, rebuilding, or restarting the MCP gateway container. Handles CI images, manual build, Traefik labels, health checks, and log verification.
disable-model-invocation: true
argument-hint: [--manual-build to build locally instead of using CI image, --force to skip confirmation, --rollback <sha> to deploy a previous version]
---

# Deploy Homelab MCP Gateway

You are performing a **redeploy** of the Homelab MCP Gateway container on Tower (Unraid). The image is built by GitLab CI on every push to main.

**Reference**: Read `../../references/gateway-dev.md` for full gateway development rules if needed.

**IMPORTANT**: All code changes must be committed to GitLab BEFORE deploying. If there are uncommitted changes, commit first.

## Pre-flight

1. **Verify GitLab is clean** via `remote-ssh`:
   ```
   export GIT_DIR=/opt/homelab-mcp-gateway/.git GIT_WORK_TREE=/opt/homelab-mcp-gateway
   git status
   ```
   If dirty, commit and push before proceeding.

2. **Check current container status** using `docker_call` -> `list_containers`, filter `homelab-mcp-gateway`.

3. **Check available images**:
   ```
   docker images homelab-mcp-gateway --format '{{.Tag}} {{.Size}} {{.CreatedAt}}' | head -5
   ```

4. **Unless `--force` was passed**, confirm with the user before proceeding.

## Deploy Sequence

Execute on Tower via `remote-ssh`. Each step must succeed before the next.

### Step 1: Build (only if --manual-build)

Normally skip — CI builds automatically. Only for emergency local builds:
```
cd /opt/homelab-mcp-gateway && docker build --no-cache -t homelab-mcp-gateway:latest .
```

### Step 2: Stop and remove old container
```
docker stop homelab-mcp-gateway && docker rm homelab-mcp-gateway
```

### Step 3: Run new container

**CRITICAL: All 3 Traefik labels are MANDATORY.**

```
docker run -d \
  --name homelab-mcp-gateway \
  --network traefik_proxy \
  --restart unless-stopped \
  --env-file /opt/homelab-mcp-gateway/.env \
  -v /opt/homelab-mcp-gateway/logs:/app/logs \
  -l "traefik.enable=true" \
  -l 'traefik.http.routers.mcp-gateway.rule=Host(`mcp.8-bit-byrum.com`)' \
  -l "traefik.http.services.mcp-gateway.loadbalancer.server.port=3500" \
  homelab-mcp-gateway:latest
```

For rollback: replace `latest` with `homelab-mcp-gateway:<commit-sha>`.

### Step 4: Wait and verify
```
sleep 5 && docker ps --filter name=homelab-mcp-gateway --format "{{.Status}}"
```

### Step 5: Health check
```
curl -sf https://mcp.8-bit-byrum.com/health || echo "HEALTH CHECK FAILED"
```
If failed, wait 10s and retry once.

### Step 6: Tail logs
```
docker logs homelab-mcp-gateway --tail=20
```

## Output Format

```
## Gateway Deploy Report

| Step | Status |
|------|--------|
| GitLab clean | YES / NO (committed) |
| Build | OK / SKIPPED / FAILED |
| Stop old | OK / SKIPPED (not running) |
| Start new | OK / FAILED |
| Health check | OK / FAILED |

### Container Status
<docker ps output>

### Last 20 Log Lines
<log output>
```

## NEVER Do These

- NEVER deploy without committing to GitLab first
- NEVER add `-p 3500:3500` — Traefik handles routing
- NEVER add `entrypoints=https`, `tls=true`, or `tls.certresolver`
- NEVER use `docker compose` — Unraid doesn't have it
- NEVER omit any of the 3 Traefik labels
- NEVER change the container name, network, or port
