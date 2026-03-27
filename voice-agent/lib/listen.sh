#!/data/data/com.termux/files/usr/bin/bash
# Voice Agent — speech-to-text wrapper

listen_for_speech() {
    local result
    result=$(timeout "$LISTEN_TIMEOUT" termux-speech-to-text 2>/dev/null)
    # Trim whitespace
    echo "$result" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
