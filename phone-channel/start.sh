#!/data/data/com.termux/files/usr/bin/bash
# Phone Channel — reliable start script
# Starts channel in tmux with auto-restart on crash

set -euo pipefail

SESSION="claude"
CHANNEL_DIR="$HOME/phone-channel"

# Acquire wake lock to prevent Android from killing us
termux-wake-lock 2>/dev/null || true

# If already running in tmux, do nothing
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already running. Attach with: tmux attach -t $SESSION"
    exit 0
fi

# Start tmux session — run-channel.sh handles auto-accept and restarts
tmux new-session -d -s "$SESSION" "bash $CHANNEL_DIR/run-channel.sh"

echo "Phone channel started in tmux session '$SESSION'"
echo "  Attach: tmux attach -t $SESSION"
echo "  Logs:   tail -f $CHANNEL_DIR/channel.log"
