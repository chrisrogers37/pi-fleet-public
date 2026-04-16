# claudlobby

A multi-bot Claude Code fleet running on a Raspberry Pi 5. Always-on AI assistants connected via Telegram, each with specialized roles, isolated contexts, and shared infrastructure.

## What This Is

A system for running multiple Claude Code instances as persistent bots on a single Raspberry Pi, each with:
- Its own **Telegram bot** for communication
- Its own **MCP servers** (GitHub, Notion, Gmail, Shopify, etc.)
- Its own **persona and skills** defined in CLAUDE.md
- **Shared infrastructure** for starting, monitoring, and restarting bots

The bots operate in Telegram group chats where some listen to everything (`requireMention: false`) and others only respond when @mentioned (`requireMention: true`). This creates a natural hierarchy — a manager bot that converses freely and worker bots that activate on demand.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Raspberry Pi 5 (16GB)              │
│                                                     │
│  ~/claudlobby/                                        │
│  ├── bot-common/          Shared start/keepalive    │
│  ├── bot-a/               Manager bot (Opus)         │
│  ├── bot-b/               Specialist bot (Opus)      │
│  ├── bot-c/               Engineer bot (Opus)        │
│  ├── bot-d/               Another engineer (Opus)    │
│  └── bot-e/               Code reviewer (Sonnet)     │
│                                                     │
│  Each bot = systemd service + tmux session           │
│           + Telegram channel + MCP servers            │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ Telegram │ │ Telegram │ │ Telegram │
    │ Group 1  │ │ Group 2  │ │ Group 3  │
    │ Domain A │ │ Domain B │ │ Eng Team │
    └──────────┘ └──────────┘ └──────────┘
```

## How It Works

### Bot Lifecycle

Each bot is a systemd service that launches a tmux session running Claude Code with the Telegram channel plugin:

1. **systemd** starts the bot on boot (or manual `systemctl start`)
2. **bot-common/start-bot.sh** reads `bot.conf`, sets up env vars, launches Claude in tmux
3. **Claude Code** connects to Telegram and MCP servers, reads CLAUDE.md for persona/instructions
4. **Keepalive cron** checks every 30 min: restarts dead sessions, nudges idle ones

### Multi-Bot Telegram

Multiple bots coexist in group chats using the Telegram channel plugin's access controls:

- **Manager bots** (`requireMention: false`): hear all messages, conversational
- **Worker bots** (`requireMention: true`): silent until @mentioned
- Each bot uses `TELEGRAM_STATE_DIR` to isolate its Telegram state (tokens, access lists, inbox)

### Task Dispatch

The manager bot orchestrates workers via **tmux send-keys** (reliable, instant) rather than Telegram (which can drop messages):

```bash
# Manager dispatches to worker
tmux send-keys -t work-eng-bot 'Fix the failing test in src/api/auth.ts and create a PR' Enter

# Worker reports back via report-back.sh
~/claudlobby/bot-common/report-back.sh "work-eng" "DONE" "Fixed auth test, PR #42" "pr:https://github.com/org/repo/pull/42"
```

## Quick Start

### Prerequisites

- Raspberry Pi 5 (16GB recommended, 8GB minimum for 2 bots)
- Debian Bookworm (standard Pi OS)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- Telegram account + bots created via [@BotFather](https://t.me/BotFather)

### 1. Clone and Set Up

```bash
git clone https://github.com/YOUR_USERNAME/claudlobby.git ~/claudlobby
cd ~/claudlobby
```

### 2. Create Your First Bot

```bash
# Create bot directory
mkdir -p ~/claudlobby/my-bot/{planning,.claude/skills}

# Copy and customize the config
cp examples/bot.conf ~/claudlobby/my-bot/bot.conf
# Edit bot.conf with your bot name, paths, Telegram state dir

# Write your CLAUDE.md (persona + instructions)
cp examples/CLAUDE.md ~/claudlobby/my-bot/CLAUDE.md
# Customize the persona, skills, MCP servers, behavior rules

# Create .mcp.json with your MCP servers
cp examples/.mcp.json ~/claudlobby/my-bot/.mcp.json
# Add your API tokens (this file is gitignored)
```

### 3. Set Up Telegram

```bash
# 1. Create bot via @BotFather, get token
# 2. Disable Group Privacy: /setprivacy → Disable
# 3. Create group chat, add bot, make admin
# 4. Get group ID via @raw_data_bot

# Create Telegram state directory
mkdir -p ~/.claude/channels/telegram-my-bot/{approved,inbox}

# Write bot token
echo "TELEGRAM_BOT_TOKEN=your_token_here" > ~/.claude/channels/telegram-my-bot/.env
chmod 600 ~/.claude/channels/telegram-my-bot/.env

# Write access config
cat > ~/.claude/channels/telegram-my-bot/access.json << 'EOF'
{
  "dmPolicy": "allowlist",
  "allowFrom": ["YOUR_TELEGRAM_USER_ID"],
  "groups": {
    "YOUR_GROUP_CHAT_ID": {
      "requireMention": false,
      "allowFrom": []
    }
  },
  "pending": {}
}
EOF
```

### 4. Install Systemd Service

```bash
sudo cp examples/bot.service /etc/systemd/system/my-bot.service
# Edit the service file: update paths, bot name
sudo systemctl daemon-reload
sudo systemctl enable my-bot
sudo systemctl start my-bot
```

### 5. Set Up Keepalive Cron

```bash
# Add to crontab (crontab -e)
*/30 * * * * /home/YOUR_USER/claudlobby/bot-common/keepalive.sh /home/YOUR_USER/claudlobby/my-bot
```

## Directory Structure

```
claudlobby/
├── bot-common/                    # Shared infrastructure
│   ├── start-bot.sh               # Parameterized bot launcher
│   ├── keepalive.sh               # Health check + auto-restart
│   └── report-back.sh             # Inter-bot communication
│
├── examples/                      # Templates for new bots
│   ├── bot.conf                   # Bot configuration template
│   ├── CLAUDE.md                  # Persona/instructions template
│   ├── .mcp.json                  # MCP server config template
│   ├── bot.service                # Systemd service template
│   ├── access.json                # Telegram access template
│   └── settings.local.json        # Claude permissions template
│
├── my-bot/                        # Each bot follows this structure
│   ├── CLAUDE.md                  # Persona + capabilities
│   ├── bot.conf                   # Bot-specific config
│   ├── .mcp.json                  # MCP servers (gitignored)
│   ├── .env                       # Secrets (gitignored)
│   ├── .claude/
│   │   ├── settings.local.json    # Permissions
│   │   └── skills/                # Bot-specific skills
│   └── planning/                  # Multi-session plans
│
└── another-bot/                   # Add as many bots as you need
    └── (same structure)
```

## Key Concepts

### Naming and Personality

Each bot can have a unique name and personality. The directory name is the technical identifier — the persona lives in CLAUDE.md and the Telegram display name:

- **Directory:** `~/claudlobby/my-bot/` (technical, used by systemd/tmux/crons)
- **CLAUDE.md:** "You are Rajan, a meticulous code reviewer who..." (how the bot sees itself)
- **Telegram @BotFather:** Set the display name and username (how everyone else sees it)

Give bots distinct personalities — a sarcastic engineer, a methodical reviewer, a high-energy business rep. The persona in CLAUDE.md shapes every interaction. Bots with strong personalities are more memorable and easier to work with in group chats.

### bot.conf

Each bot has a `bot.conf` that the shared scripts read:

```bash
BOT_NAME="my-bot"                    # tmux session name
BOT_SERVICE="my-bot"                 # systemd service name
BOT_LABEL="MY-BOT"                   # display label in logs
BOT_DIR="/home/user/claudlobby/my-bot" # absolute path to bot dir
TELEGRAM_STATE_DIR="/home/user/.claude/channels/telegram-my-bot"
CLAUDE_CONFIG_DIR=""                 # set for separate Claude auth
CLAUDE_EXTRA_FLAGS=""                # e.g., "--model sonnet" for cheaper bots
STARTUP_PROMPT="You just started. Read your CLAUDE.md and greet the team."
```

### CLAUDE_CONFIG_DIR (Multi-Account)

Run bots under different Claude accounts by pointing to a separate config directory:

```bash
# In bot.conf for a work bot:
CLAUDE_CONFIG_DIR="/home/user/.claude-work"
```

This gives the bot its own auth, plugins, and channel state. Requires a one-time `claude auth login` in the new config dir. Symlink shared skills: `ln -s ~/.claude/skills ~/.claude-work/skills`

### TELEGRAM_STATE_DIR (Multi-Bot Telegram)

Each bot needs its own Telegram state to avoid conflicts:

```
~/.claude/channels/telegram-assistant/   # Bot 1
~/.claude/channels/telegram-company/     # Bot 2
~/.claude/channels/telegram-engineer/    # Bot 3
```

The `TELEGRAM_STATE_DIR` env var tells the Telegram plugin where to find its token and access config. Set it in `bot.conf` and the shared `start-bot.sh` passes it to Claude.

Reference: [anthropics/claude-code#37173](https://github.com/anthropics/claude-code/issues/37173)

### requireMention (Group Chat Routing)

Control which bots respond to which messages in a shared group:

```json
{
  "groups": {
    "-100XXXXXXXXXX": {
      "requireMention": true,
      "allowFrom": []
    }
  }
}
```

- `requireMention: false` — bot processes ALL messages (manager/conversational bots)
- `requireMention: true` — bot only responds to @mentions and replies (worker bots)

**Important:** You must also disable Group Privacy on @BotFather (`/setprivacy` → Disable) for the bot to receive group messages at all.

### Skill Scoping

Skills can be global (shared by all bots) or project-scoped (only visible to one bot):

```
~/.claude/skills/              # Global — all bots see these
~/claudlobby/my-bot/.claude/skills/  # Project-scoped — only this bot
```

Use this to give each bot only the skills it needs. Personal assistant skills (briefing, finance, calendar) shouldn't be visible to engineer bots.

## Multi-Bot Patterns

### Manager + Workers

One bot orchestrates, others execute:

```
Manager (requireMention: false)
  ├── Worker A (requireMention: true) — engineering tasks
  ├── Worker B (requireMention: true) — code reviews
  └── Worker C (requireMention: true) — specialized work
```

The manager dispatches via tmux (reliable), workers report results to Telegram (visible).

### Independent Specialists

Bots in separate groups for different domains:

```
Domain A group:  Bot A (e.g., personal assistant, life management)
Domain B group:  Bot B (e.g., business ops, customer service, e-commerce)
Engineering group: Manager + engineers + code reviewer
```

### Code Review Pipeline

Engineer creates PR → Manager dispatches reviewer → Reviewer posts findings → Manager routes feedback:

```bash
# Manager dispatches review
tmux send-keys -t code-reviewer-bot 'Review PR #42 at https://github.com/org/repo/pull/42. Use /review-pr.' Enter
```

## Resource Planning

Per-bot resource cost on Pi 5:

| Component | RAM |
|-----------|-----|
| Claude Code process | ~580 MB |
| MCP servers (varies) | ~200-500 MB |
| **Total per bot** | **~800 MB - 1.1 GB** |

| Fleet Size | Estimated RAM | Pi 5 (16GB) |
|-----------|---------------|-------------|
| 2 bots | ~2-3 GB | Comfortable |
| 3-4 bots | ~4-5 GB | Good |
| 5-6 bots | ~6-8 GB | Monitor closely |
| 7+ bots | ~8+ GB | Consider swap or second Pi |

Tips:
- Give worker bots fewer MCP servers (just GitHub) to reduce memory
- Use `--model sonnet` for bots that don't need Opus (code reviewer, simple tasks)
- Add swap space as safety net: `sudo dphys-swapfile` (2-4 GB recommended)

## Security Hardening

Recommended for any Pi running always-on bots:

```bash
# Lock down secret files
chmod 600 ~/.env ~/claudlobby/*/.env ~/claudlobby/*/.mcp.json

# Disable SSH password auth (key-only)
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Install firewall
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw allow from 192.168.x.0/24 to any port 22  # SSH from LAN
sudo ufw enable

# Install brute-force protection
sudo apt install fail2ban
sudo systemctl enable --now fail2ban

# Disable unnecessary services
sudo systemctl disable --now cups cups-browsed ModemManager
```

## Telegram Reliability

The Claude Code Telegram plugin has known message-dropping issues ([#36477](https://github.com/anthropics/claude-code/issues/36477), [#37933](https://github.com/anthropics/claude-code/issues/37933)). Mitigations that help:

1. **Keepalive cron** — nudges idle sessions every 30 min (included in bot-common)
2. **Group chats with `requireMention: false`** — significantly more reliable than DMs
3. **Supergroup format** — make bots admin to auto-upgrade to supergroup
4. **Staggered keepalives** — don't run all bots' keepalives at the same minute
5. **Auto-restart** — keepalive detects dead sessions and runs `systemctl restart`

For critical interactions, use **Remote Control** (`--remote-control` flag, included by default) as a reliable fallback.

## Documentation

- **[Pi Setup Guide](docs/pi-setup-guide.md)** — Complete setup: OS, Node.js, Bun, Claude Code, CLIs (Vercel, Railway, Neon, DigitalOcean, dbt), security hardening, swap, cron templates
- **[Bot Archetypes](docs/bot-archetypes.md)** — Proven configurations for manager, engineer, code reviewer, designer, and business bots. MCP servers, skills, and Telegram settings for each.
- **[Integrations Guide](docs/integrations.md)** — Setup for every MCP server: GitHub, Notion, Gmail, Calendar, Slack, Shopify, Printify, Home Assistant, Docker, Spotify, Granola, and DevOps CLIs
- **[Notion Integration](docs/notion-integration.md)** — Deep dive: connecting to Notion, programmatic database creation, multi-workspace isolation, recommended database structures
- **[Advanced Patterns](docs/advanced-patterns.md)** — Lifecycle orchestration, alert sweep, triage, inter-bot communication, automated audits, pre-stop handoff, visual crawl, multi-account, data pre-sync, Telegram formatting

### Global Skills Layer

Bot-specific skills live in each bot's directory. General-purpose development skills (code review, worktrees, security audits, deployment tools) are shared globally via [claudefather](https://github.com/Artemis-xyz/claudefather) — a global Claude Code configuration repo that manages skills, hooks, and agents installed to `~/.claude/`. See the [bot archetypes doc](docs/bot-archetypes.md) for which skills each bot type needs.

## Example Configurations

The `examples/` directory contains templates for every file a bot needs:

| File | Purpose |
|------|---------|
| `bot.conf` | Bot identity and paths |
| `CLAUDE.md` | Persona, skills, behavior rules |
| `.mcp.json` | MCP server connections (GitHub, Notion, Gmail, Shopify, Slack, Home Assistant) |
| `bot.service` | Systemd service unit |
| `access.json` | Telegram group/DM access control |
| `settings.local.json` | Claude tool permissions |
| `skills/` | Orchestration skills: dispatch, fleet-status, briefing, lifecycle, triage, data-alert-sweep, visual-crawl |
| `scripts/` | Automation scripts: pre-stop-handoff, git-pull-all, evening-audit, finance-presync |
| `_telegram-formatting.md` | Telegram markdown reference |

## Use Cases

This system is flexible enough for many configurations:

- **Personal assistant** — Calendar, email, tasks, smart home, finance tracking
- **Business operations** — Customer service, order management, e-commerce (Shopify/Printify)
- **Engineering team** — Code reviews, PR management, data pipeline monitoring, automated fixes
- **Content management** — Social media scheduling, content calendar, analytics
- **DevOps/SRE** — Deployment monitoring (Vercel, Railway, DO), database management (Neon, Snowflake)
- **Multi-tenant** — Separate bots for separate businesses/clients, fully isolated

## License

MIT
