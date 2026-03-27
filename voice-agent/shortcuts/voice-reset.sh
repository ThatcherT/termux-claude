#!/data/data/com.termux/files/usr/bin/bash
# Termux:Widget shortcut — reset voice agent session
rm -f "$HOME/voice-agent/state/session_id"
termux-toast "Session reset"
termux-tts-speak "Session reset. Starting fresh."
