---
name: status
description: "Use when the user asks if the assistant is healthy, or to diagnose connectivity, cron jobs, MCP servers, or session issues. Self-diagnostic tool."
argument-hint: "[full|mcp|cron|telegram]"
---


# Status

Self-diagnostic for the always-on assistant. Checks session health, MCP connections, cron jobs, and Telegram connectivity.

## Checks

### 1. Session Info

```bash
echo "Uptime: $(ps -o etime= -p $(pgrep -f 'claude' | head -1) 2>/dev/null || echo 'unknown')"
echo "PID: $(pgrep -f 'claude' | head -1)"
echo "Memory: $(ps -o rss= -p $(pgrep -f 'claude' | head -1) 2>/dev/null | awk '{printf "%.0f MB", $1/1024}')"
tmux list-sessions 2>/dev/null
```

### 2. MCP Server Connectivity

Test each MCP server by making a lightweight call:

| Server | Test |
|--------|------|
| Notion | `mcp__notion__API-get-self` |
| Gmail | `mcp__claude_ai_Gmail__gmail_get_profile` |
| Google Calendar | `mcp__claude_ai_Google_Calendar__gcal_list_calendars` |
| GitHub | `mcp__github__search_repositories` with a simple query |
| Home Assistant | `mcp__homeassistant__get_version` |
| Telegram | `mcp__plugin_telegram_telegram__react` is available (passive check) |
| Docker | `mcp__docker__list_containers` |

Run all tests in parallel. Report pass/fail for each.

### 3. Cron Jobs

```bash
crontab -l 2>/dev/null
```

Check if crons are firing:
```bash
echo "=== Briefing cron ===" && ls -la ~/assistant/briefing-cron.sh
echo "=== Audit cron ===" && ls -la ~/assistant/evening-audit.sh
echo "=== Last briefing log ===" && tail -5 /tmp/briefing-cron.log 2>/dev/null || echo "no log"
echo "=== Last audit log ===" && cat ~/assistant/audit-results/cron.log 2>/dev/null || echo "no log"
```

### 4. Finance Snapshots

```bash
echo "=== Portfolio snapshots (last 5) ===" && ls -la ~/assistant/finances/portfolio-snapshots/ | tail -5
echo "=== Transaction snapshots (last 5) ===" && ls -la ~/assistant/finances/transaction-snapshots/ | tail -5
```

Check for gaps in daily snapshots.

### 5. Telegram Connectivity

Passive check — note the last message received and any gaps in message IDs. Check if the Telegram plugin tools are responding.

### 6. Disk & System

```bash
df -h / | tail -1
free -h | head -2
uptime
cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "CPU temp: %.1f°C\n", $1/1000}'
```

## Output Formatting

See [\_telegram\-formatting\.md](../_telegram-formatting.md) for Telegram output formatting rules\.

Send via `mcp__plugin_telegram_telegram__reply` to chat\_id `7668871620` with `format: "markdownv2"`\.

```
🖥️ *ASSISTANT STATUS*

*Session*
━━━━━━━━━━━━
• Running 4h 23m \| PID 12345 \| 487 MB RAM
• Pi 5 \| 42\.3°C \| 12\.4 GB free \| load 0\.32

*MCP Servers*
━━━━━━━━━━━━
✅ Notion \| Gmail \| Calendar \| GitHub
✅ Home Assistant \| Telegram \| Docker

*Crons*
━━━━━━━━━━━━
✅ Briefings — last: today 6:30 PM
✅ Evening audit — last: yesterday 9:00 PM
✅ Portfolio snapshot — last: today 4:30 PM
✅ Transaction snapshot — last: today 6:00 AM

*Snapshots*
━━━━━━━━━━━━
✅ 30/30 days \(no gaps\)

⚠️ *Issues*
━━━━━━━━━━━━
• None
```

With problems:
```
⚠️ *Issues*
━━━━━━━━━━━━
• Telegram: message drops detected \(gap: msg 1175\-1177\)
• Railway token: empty projects \(needs re\-auth\)
❌ Portfolio snapshot: missing Apr 2\-3 \(session was down\)
```

## Instructions

1. Run all checks in parallel for speed
2. For MCP tests, use lightweight read-only calls — don't modify anything
3. Flag any issues prominently at the top
4. Include CPU temperature (Pi 5 throttles at 85°C)
5. Check for snapshot gaps by comparing file dates against expected daily cadence
6. Default to full status check if no argument specified

$ARGUMENTS
