#!/data/data/com.termux/files/usr/bin/bash
# Phone Channel — auto-restart loop
# Runs inside tmux. Restarts claude+channel on crash with backoff.

set -uo pipefail

CHANNEL_DIR="$HOME/phone-channel"
LOG="$CHANNEL_DIR/channel.log"
MAX_BACKOFF=300
backoff=5

cd "$CHANNEL_DIR"

export CLAUDE_CODE_TMPDIR="$HOME/.tmp"

# Auto-accept the development channel confirmation prompt
# Sends Enter to our own tmux session after a delay
auto_accept() {
    local session
    session=$(tmux display-message -p '#S' 2>/dev/null || echo "claude")
    (sleep 8 && tmux send-keys -t "$session" Enter) &
}

while true; do
    echo "[$(date)] Starting phone-channel..." >> "$LOG"

    # Pre-send Enter to auto-accept the dev channel prompt
    auto_accept

    # Claude Code spawns channel.mjs as MCP subprocess via .mcp.json
    claude \
        --dangerously-load-development-channels server:phone-channel \
        --dangerously-skip-permissions

    exit_code=$?
    echo "[$(date)] Phone-channel exited with code $exit_code" >> "$LOG"

    if [ $exit_code -eq 0 ]; then
        echo "[$(date)] Clean exit. Not restarting." >> "$LOG"
        break
    fi

    echo "[$(date)] Restarting in ${backoff}s..." >> "$LOG"
    sleep "$backoff"

    # Exponential backoff, capped
    backoff=$((backoff * 2))
    if [ $backoff -gt $MAX_BACKOFF ]; then
        backoff=$MAX_BACKOFF
    fi
done
