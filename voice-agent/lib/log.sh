#!/data/data/com.termux/files/usr/bin/bash
# Voice Agent — daily interaction logging

log_interaction() {
    local role="$1"
    local text="$2"
    local logfile="$AGENT_DIR/logs/$(date +%Y-%m-%d).log"
    mkdir -p "$AGENT_DIR/logs"
    echo "[$(date +%H:%M:%S)] $role: $text" >> "$logfile"
}
