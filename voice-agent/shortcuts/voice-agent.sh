#!/data/data/com.termux/files/usr/bin/bash
# Termux:Widget shortcut — tap to activate voice agent
exec "$HOME/voice-agent/agent.sh" 2>"$HOME/voice-agent/logs/error.log"
