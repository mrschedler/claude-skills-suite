---
name: infra-health
description: Use when checking service health, verifying infrastructure status, or after a deploy/restart. Checks containers, endpoints, Uptime Kuma, and Prometheus alerts.
argument-hint: [service name to check just one, e.g. "dify", "gateway", "n8n"]
disable-model-invocation: true
---

# Infrastructure Health Check

You are performing a **fast, deterministic health check** across all critical homelab services. This is not an exploratory debug session — it's a structured status sweep.

If an argument was provided, filter the checks to just that service. Otherwise, check everything.

## Process

### Step 1: Gateway Status Overview

Call `gateway_call` with sub-tool `status` via the Homelab Tools MCP. This returns connected service health (Qdrant, Neo4j, Postgres, n8n, Vault, Docker).

### Step 2: Container Health

Call `docker_call` with sub-tool `list_containers`. Check these critical containers:

| Container | Expected Status |
|-----------|----------------|
| homelab-mcp-gateway | running |
| pgvector-18 | running |
| Neo4j | running |
| Qdrant | running |
| Vault | running |
| n8n | running |
| dify-api | running |
| dify-worker | running |
| dify-web | running |
| dify-plugin-daemon | running |
| dify_postgres17 | running |
| openhands | running |
| Prometheus | running |
| Grafana | running |
| Alertmanager | running |
| uptime-kuma | running |
| Uptime-Kuma-API | running |
| RabbitMQ | running |
| Redis | running |
| MongoDB | running |
| gitlab-ce | running |
| traefik | running |
| docker-socket-proxy | running |
| ntfy | running |

Flag any container that is:
- Not running
- Restarting
- Started less than 2 minutes ago (possible recent crash-restart)

### Step 3: Uptime Kuma Monitors

Call `uptime_call` with sub-tool `list_monitors`. Check for any monitor with status DOWN or PENDING.

### Step 4: Prometheus Alerts

Call `prometheus_call` with sub-tool `query` with the query: `ALERTS{alertstate="firing"}`.

If any alerts are firing, list them.

### Step 5: Key Endpoint Checks

Use `remote-ssh` to run quick curl checks from Tower:

```bash
curl -sf https://mcp.8-bit-byrum.com/health -o /dev/null && echo "gateway: OK" || echo "gateway: FAILED"
curl -sf http://dify-api:5001/v1/meta -o /dev/null && echo "dify-api: OK" || echo "dify-api: FAILED"
curl -sf http://Vault:8200/v1/sys/health -o /dev/null && echo "vault: OK" || echo "vault: FAILED"
curl -sf http://Prometheus:9090/-/healthy -o /dev/null && echo "prometheus: OK" || echo "prometheus: FAILED"
curl -sf http://Qdrant:6333/healthz -o /dev/null && echo "qdrant: OK" || echo "qdrant: FAILED"
```

## Output Format

```
## Infrastructure Health Report

### Service Overview
| Service | Container | Status | Uptime | Notes |
|---------|-----------|--------|--------|-------|
| Gateway | homelab-mcp-gateway | UP | 3d 4h | |
| PostgreSQL | pgvector-18 | UP | 5d 1h | |
| Dify API | dify-api | DOWN | - | Stopped 10m ago |
| ... | ... | ... | ... | ... |

### Uptime Kuma Monitors
| Monitor | Status | Response Time |
|---------|--------|---------------|
| Gateway | UP | 142ms |
| ... | ... | ... |
(or "All monitors UP" if none are down)

### Prometheus Alerts
- No alerts firing
(or list of firing alerts)

### Endpoint Checks
| Endpoint | Status |
|----------|--------|
| gateway /health | OK |
| dify-api /meta | OK |
| vault /sys/health | OK |
| prometheus /-/healthy | OK |
| qdrant /healthz | OK |

### Summary
- Total services: 24
- Healthy: 24
- Degraded: 0
- Down: 0
```

If any service is down or degraded, add a **Recommended Actions** section with specific steps to investigate or fix.
