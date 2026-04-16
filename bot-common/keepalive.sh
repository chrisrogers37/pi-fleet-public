#!/bin/bash
# Shared bot keepalive — restart if dead, nudge if idle
# Usage: keepalive.sh /path/to/bot/dir
BOT_DIR="${1:?Usage: keepalive.sh /path/to/bot/dir}"
source "$BOT_DIR/bot.conf"

LOG="$BOT_DIR/keepalive.log"

# If session is dead, restart the service
if ! /usr/bin/tmux has-session -t "$BOT_NAME" 2>/dev/null; then
    echo "$(date -Iseconds) RESTART — session dead, restarting $BOT_SERVICE" >> "$LOG"
    sudo systemctl restart "$BOT_SERVICE"
    exit 0
fi

pane_content=$(/usr/bin/tmux capture-pane -t "$BOT_NAME" -p 2>/dev/null)
last_lines=$(echo "$pane_content" | tail -10)

# Skip if Claude is actively processing
if echo "$last_lines" | grep -qE '(Running|Blanching|Wandering|Thinking|Reading|Writing|Editing)'; then
    echo "$(date -Iseconds) SKIP — active processing" >> "$LOG"
    exit 0
fi

# Nudge if idle at prompt
if echo "$last_lines" | grep -qE '(^\s*[>❯]|Remote Control active|Enter/Esc to close)'; then
    /usr/bin/tmux send-keys -t "$BOT_NAME" Enter
    echo "$(date -Iseconds) SENT Enter — idle detected" >> "$LOG"
else
    echo "$(date -Iseconds) SKIP — no idle pattern matched" >> "$LOG"
fi
