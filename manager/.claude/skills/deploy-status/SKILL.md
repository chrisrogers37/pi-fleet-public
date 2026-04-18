---
name: deploy-status
description: "Use when the user wants to check deployment health across Vercel, Railway, and DigitalOcean. Shows service status, recent deploys, and failures."
argument-hint: "[vercel|railway|all] [project-name]"
---

# Deploy Status

Unified deployment health across all platforms.

## Platforms & Projects

### Vercel
Use `vercel` CLI (in `~/.npm-global/bin/`). Always `export PATH="$HOME/.npm-global/bin:$PATH"` first.

Projects (<FLEET_ORG> only): foxxed, huntress, artemis-invest-frontend, artemis-stablecoins-v2

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
vercel ls --token=$VERCEL_TOKEN 2>&1 | head -30
```

For specific project:
```bash
export PATH="$HOME/.npm-global/bin:$PATH"
vercel ls <project-name> --token=$VERCEL_TOKEN 2>&1 | head -20
```

### Railway
Two tokens in `~/.env` — query both via GraphQL API (`me.workspaces.projects`, NOT `me.projects`):

**Work** (`RAILWAY_API_TOKEN` — Artemis Analytics):
```bash
source ~/.env
curl -s -X POST https://backboard.railway.com/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ me { workspaces { id name projects { edges { node { id name services { edges { node { id name } } } } } } } } }"}' | python3 -m json.tool
```

Known work projects & services:
- Artemis Stablecoin Dashboard: artemis-stablecoins-v2, Postgres, Redis
- huntress: huntress + 6 sync services
- foxxed: foxxed-pipeline, foxxed-api, foxxed-s3sync
- artemis-data-svc: Redis, artemis-data-svc
- heimdall-bot, vault-trade-execution, aletheia-backend, artemis-comp-explorer, wholesome-presence

### DigitalOcean
Use `doctl` CLI (team: wickedmuse).

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
doctl apps list --format ID,Spec.Name,ActiveDeployment.Phase,UpdatedAt 2>&1
```

### Neon (Databases)
```bash
export PATH="$HOME/.npm-global/bin:$PATH"
neonctl projects list --org-id <NEON_ORG_ID> --output json 2>&1 | python3 -c "import sys,json; [print(f\"{p['name']}: {p['current_state']}\") for p in json.load(sys.stdin)]"
```


## Operations

### 1. Full Status (default)

Check all platforms in parallel:
- Vercel: recent deployments, any failures
- Railway: service status via GraphQL API
- DigitalOcean: app status
- Neon: database health

### 2. Platform-specific

When user says "/deploy-status vercel" — only check Vercel.

### 3. Project-specific

When user says "/deploy-status huntress" — find it across platforms and show details.

## Output Formatting

See [\_telegram\-formatting\.md](../_telegram-formatting.md) for Telegram output formatting rules\.

Send via `mcp__plugin_telegram_telegram__reply` to chat\_id `7668871620` with `format: "markdownv2"`\.

```
🚀 *DEPLOY STATUS*

*Vercel*
━━━━━━━━━━━━
✅ huntress — deployed 2h ago
✅ foxxed — deployed 4h ago

*Railway — Artemis Analytics*
━━━━━━━━━━━━
✅ huntress \(7 services\) — 29m ago
✅ foxxed — pipeline \+ api 12h ago
💤 artemis\-data\-svc — sleeping

*Railway — Personal*
━━━━━━━━━━━━
✅ storyline\-ai — 4d ago

*DigitalOcean*
━━━━━━━━━━━━

🗄️ *Neon*
━━━━━━━━━━━━
✅ All 6 databases healthy

⚠️ *Issues*
━━━━━━━━━━━━
• wholesome\-presence has no deployment
```

## Instructions

1. Run all platform checks in parallel (both Railway tokens in parallel)
2. Highlight failures, errors, or unhealthy services at the top
3. Show last deploy time for each service
4. Group Railway results by workspace (Artemis Analytics / Personal)
5. Skip platforms with no projects if checking all
6. For Railway, handle token auth issues gracefully — note which workspace needs re-auth

$ARGUMENTS