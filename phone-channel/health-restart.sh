#!/data/data/com.termux/files/usr/bin/bash
# Health check — run locally on phone or via SSH from desktop
# Checks if channel is responding, restarts if not

if curl -sf http://localhost:8788/health >/dev/null 2>&1; then
    echo "OK — phone-channel is healthy"
    exit 0
fi

echo "WARN — phone-channel not responding, restarting..."

# Kill stale tmux session if it exists
tmux kill-session -t claude 2>/dev/null || true

# Kill any orphaned processes
pkill -f "channel.mjs" 2>/dev/null || true
pkill -f "claude.*server:phone-channel" 2>/dev/null || true
sleep 2

# Restart
bash ~/phone-channel/start.sh
