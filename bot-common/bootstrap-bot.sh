#!/bin/bash
# bootstrap-bot.sh — scaffold a new bot dir from the manager/ or examples/worker/ template.
#
# Creates per-bot dir, channel state, and service unit.
#
# Usage:
#   bootstrap-bot.sh <bot-name> manager [options]
#   bootstrap-bot.sh <bot-name> worker  [options]
#
# Options:
#   --telegram-token <token>   Inline BotFather token (otherwise you'll be prompted)
#   --group-chat-id <id>       Telegram group chat ID to auto-add
#   --claudlobby-root <path>   Defaults to ~/claudlobby
#
# Does NOT do (you handle these yourself):
#   - Create the bot via BotFather
#   - Pair the first human via /telegram:access
#   - Install the service unit (systemd: sudo cp + systemctl; launchd: cp plist + launchctl bootstrap)
set -u
BOT="${1:?Usage: bootstrap-bot.sh <bot-name> <template>}"
TEMPLATE="${2:?Usage: bootstrap-bot.sh <bot-name> <template (manager|worker)>}"
shift 2

TOKEN=""
CHAT_ID=""
ROOT="${CLAUDLOBBY_ROOT:-$HOME/claudlobby}"

while [ $# -gt 0 ]; do
  case "$1" in
    --telegram-token) TOKEN="$2"; shift 2 ;;
    --group-chat-id)  CHAT_ID="$2"; shift 2 ;;
    --claudlobby-root) ROOT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

SRC=""
case "$TEMPLATE" in
  manager) SRC="$ROOT/manager" ;;
  worker)  SRC="$ROOT/examples/worker" ;;
  *) echo "template must be 'manager' or 'worker'" >&2; exit 2 ;;
esac

[ -d "$SRC" ] || { echo "template not found at $SRC" >&2; exit 1; }
BOT_DIR="$ROOT/$BOT"
[ -e "$BOT_DIR" ] && { echo "bot dir already exists: $BOT_DIR" >&2; exit 1; }

echo "Creating $BOT_DIR from $TEMPLATE template..."
mkdir -p "$BOT_DIR"
cp -R "$SRC"/. "$BOT_DIR/"

# Substitute placeholders in bot.conf + CLAUDE.md
for f in "$BOT_DIR/bot.conf" "$BOT_DIR/CLAUDE.md" "$BOT_DIR/.mcp.json.template"; do
  [ -f "$f" ] || continue
  sed -i.bak \
    -e "s|<BOT_NAME>|$BOT|g" \
    -e "s|<BOT_NAME_UPPER>|$(echo "$BOT" | tr '[:lower:]' '[:upper:]')|g" \
    -e "s|<BOT_DIR>|$BOT_DIR|g" \
    -e "s|<CLAUDLOBBY_ROOT>|$ROOT|g" \
    "$f" && rm "$f.bak"
done

# Rename .mcp.json.template → .mcp.json if present
[ -f "$BOT_DIR/.mcp.json.template" ] && mv "$BOT_DIR/.mcp.json.template" "$BOT_DIR/.mcp.json"

# Telegram state dir
STATE_DIR="$HOME/.claude/channels/telegram-$BOT"
mkdir -p "$STATE_DIR"/{approved,inbox}
umask 077

if [ -n "$TOKEN" ]; then
  echo "TELEGRAM_BOT_TOKEN=$TOKEN" > "$STATE_DIR/.env"
  chmod 600 "$STATE_DIR/.env"
fi

POLICY="pairing"
GROUPS="{}"
if [ -n "$CHAT_ID" ]; then
  # Include the group with requireMention:true by default for workers, false for manager
  REQUIRE=$([ "$TEMPLATE" = "manager" ] && echo "false" || echo "true")
  GROUPS="{\"$CHAT_ID\": {\"requireMention\": $REQUIRE, \"allowFrom\": []}}"
fi
cat > "$STATE_DIR/access.json" <<JSON
{
  "dmPolicy": "$POLICY",
  "allowFrom": [],
  "groups": $GROUPS,
  "pending": {}
}
JSON
chmod 600 "$STATE_DIR/access.json"

# Pre-seed Claude Code workspace trust (avoids interactive prompt on first launch)
CCJSON="$HOME/.claude.json"
if [ -f "$CCJSON" ] && command -v jq >/dev/null; then
  TMP=$(mktemp)
  jq --arg dir "$BOT_DIR" '.projects[$dir] = {
    "allowedTools": [],
    "mcpContextUris": [],
    "mcpServers": {},
    "enabledMcpjsonServers": [],
    "disabledMcpjsonServers": [],
    "hasTrustDialogAccepted": true,
    "projectOnboardingSeenCount": 99,
    "hasClaudeMdExternalIncludesApproved": true,
    "hasClaudeMdExternalIncludesWarningShown": true
  }' "$CCJSON" > "$TMP" && mv "$TMP" "$CCJSON"
fi

echo
echo "✅ Bootstrapped $BOT ($TEMPLATE)"
echo "   Bot dir:       $BOT_DIR"
echo "   Channel state: $STATE_DIR"
echo
echo "Next steps:"
[ -z "$TOKEN" ] && echo "  1. Create the bot via @BotFather → paste token into $STATE_DIR/.env"
echo "  2. Fill in $BOT_DIR/CLAUDE.md — persona, scope, any role-specific rules"
echo "  3. Fill in $BOT_DIR/.mcp.json — MCP server tokens"
echo "  4. Install the service unit (systemd/launchd) pointing at bot-common/start-bot.sh"
echo "  5. Start the bot, then DM it to pair (runs /telegram:access automatically)"
