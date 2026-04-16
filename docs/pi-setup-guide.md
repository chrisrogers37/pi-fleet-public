# Raspberry Pi Setup Guide

Complete setup guide for preparing a Raspberry Pi 5 to run a Claude Code bot fleet.

## Base System

### OS

Raspberry Pi OS (Debian Bookworm, 64-bit). Flash with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

### Initial Config

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Set timezone
sudo timedatectl set-timezone America/New_York  # or your timezone

# Enable SSH (if not already)
sudo systemctl enable --now ssh
```

## Required Software

### Node.js + npm

Required for MCP servers (most use `npx`).

```bash
# Install Node.js 20.x via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Create global npm directory (avoids sudo for global installs)
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Bun (for Telegram plugin)

```bash
curl -fsSL https://bun.sh/install | bash
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Python + uv/uvx (for workspace-mcp and other Python MCP servers)

```bash
# Python should already be installed. Install uv:
curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### tmux

```bash
sudo apt install -y tmux
```

### Claude Code

```bash
# Install via npm
npm install -g @anthropic-ai/claude-code

# Authenticate
claude auth login
# Complete OAuth flow in browser (use SSH tunnel if headless)
```

### GitHub CLI

```bash
# Install
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install -y gh

# Authenticate
gh auth login
```

## Optional CLIs

Install these based on what your bots need to manage.

### Vercel CLI

```bash
npm install -g vercel
vercel login
# Complete browser auth via SSH tunnel
```

### Railway CLI

```bash
npm install -g @railway/cli
railway login
# Complete browser auth via SSH tunnel
```

### Neon CLI

```bash
npm install -g neonctl
neonctl auth
# Complete browser auth via SSH tunnel
```

### DigitalOcean CLI (doctl)

```bash
# Download latest release
wget https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-arm64.tar.gz
tar xf doctl-1.104.0-linux-arm64.tar.gz
sudo mv doctl /usr/local/bin/
doctl auth init
# Paste API token from DO dashboard
```

### dbt Core (for data teams)

```bash
pip install dbt-snowflake  # or dbt-postgres, dbt-bigquery, etc.
```

### Tailscale (remote access)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Authenticate via URL
```

## MCP Server Dependencies

Most MCP servers install on-demand via `npx` or `uvx`. Some need pre-installation:

### workspace-mcp (Gmail / Google Calendar)

```bash
# Installs on-demand via uvx, but needs a Google Cloud OAuth client:
# 1. Go to console.cloud.google.com
# 2. Create project → APIs & Services → Credentials → OAuth Client ID
# 3. Type: Desktop app
# 4. Copy Client ID and Client Secret
# 5. First run triggers OAuth flow — open URL in browser via SSH tunnel
```

### Notion MCP

```bash
# Installs on-demand via npx. Needs:
# 1. Go to notion.so/profile/integrations
# 2. Create integration → copy token (ntn_...)
# 3. Share target pages/databases with the integration
```

### Home Assistant MCP

```bash
# hass-mcp installs via uvx. Needs:
# 1. HA long-lived access token from HA dashboard → Profile → Security
# 2. HA must be accessible from Pi (usually http://localhost:8123)
```

## SSH Tunnel for OAuth Flows

Headless Pi can't open browsers. Use SSH tunnels for OAuth:

```bash
# On your laptop — forward Pi's OAuth callback port
ssh -L 8000:localhost:8000 your-pi-host -N

# Then open the OAuth URL in your laptop's browser
# The callback redirects to localhost:8000 which tunnels to the Pi
```

For multiple Gmail accounts, each needs a unique port:
```bash
# Account 1: port 8000 (default)
# Account 2: port 8001
# Account 3: port 8002
# Set WORKSPACE_MCP_PORT in .mcp.json for each
```

## Security Hardening

```bash
# Lock down secret files
chmod 600 ~/claudlobby/*/.env ~/claudlobby/*/.mcp.json

# Disable SSH password auth
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Firewall
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from YOUR_LAN_SUBNET/24 to any port 22
sudo ufw enable

# Brute-force protection
sudo apt install -y fail2ban
echo -e "[sshd]\nenabled = true\nbackend = systemd" | sudo tee /etc/fail2ban/jail.local
sudo systemctl enable --now fail2ban

# Disable unnecessary services
sudo systemctl disable --now cups cups-browsed ModemManager
```

## Swap (Recommended for 4+ Bots)

```bash
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=4096/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## Crontab Template

```crontab
# === Bot Keepalives (staggered to avoid load spikes) ===
0,30 * * * * /home/YOUR_USER/claudlobby/bot-common/keepalive.sh /home/YOUR_USER/claudlobby/bot-a
6,36 * * * * /home/YOUR_USER/claudlobby/bot-common/keepalive.sh /home/YOUR_USER/claudlobby/bot-b
12,42 * * * * /home/YOUR_USER/claudlobby/bot-common/keepalive.sh /home/YOUR_USER/claudlobby/bot-c

# === Scheduled Briefings (optional) ===
30 8 * * * /home/YOUR_USER/claudlobby/bot-a/briefing-cron.sh morning
0 13 * * * /home/YOUR_USER/claudlobby/bot-a/briefing-cron.sh midday
30 18 * * * /home/YOUR_USER/claudlobby/bot-a/briefing-cron.sh evening

# === Maintenance ===
# Log rotation: weekly Sunday 3 AM
0 3 * * 0 for f in /home/YOUR_USER/claudlobby/*/keepalive.log /home/YOUR_USER/claudlobby/*/briefing-cron.log; do [ -f "$f" ] && tail -200 "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done

# Disk space monitor: daily 7 AM
0 7 * * * USAGE=$(df / --output=pcent | tail -1 | tr -dc '0-9'); [ "$USAGE" -gt 90 ] && echo "$(date -Iseconds) WARN — disk at ${USAGE}%%" >> /home/YOUR_USER/claudlobby/bot-a/keepalive.log

# Weekly reboot: Sunday 5 AM (optional — clears leaked memory)
# 0 5 * * 0 sudo /sbin/reboot
```
