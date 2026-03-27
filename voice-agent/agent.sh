#!/data/data/com.termux/files/usr/bin/bash
# Voice Agent — core conversation loop
# Activated via Termux:Widget tap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/listen.sh"
source "$SCRIPT_DIR/lib/speak.sh"
source "$SCRIPT_DIR/lib/session.sh"
source "$SCRIPT_DIR/lib/log.sh"

cd "$AGENT_DIR"

maybe_reset_session

# Haptic + audio confirmation
termux-vibrate -d 100 &

while true; do
    speak_text "Listening."

    user_input=$(listen_for_speech)

    if [ -z "$user_input" ]; then
        speak_text "I didn't catch that."
        break
    fi

    log_interaction "USER" "$user_input"

    # Exit phrases
    if echo "$user_input" | grep -qiE "never\s*mind|^stop$|^cancel$|goodbye|that's all|that is all"; then
        speak_text "Talk to you later."
        break
    fi

    speak_text "Thinking." &
    thinking_pid=$!

    session_flag=$(get_session_flag)

    response=$(timeout "$CLAUDE_TIMEOUT" claude -p "$user_input" \
        $session_flag \
        --output-format json \
        --allowedTools "$CLAUDE_TOOLS" \
        2>/dev/null) || true

    # Kill "Thinking" TTS if still running
    kill "$thinking_pid" 2>/dev/null || true
    wait "$thinking_pid" 2>/dev/null || true

    if [ -z "$response" ]; then
        speak_text "Sorry, something went wrong. Try again."
        log_interaction "ERROR" "empty response or timeout"
        break
    fi

    result_text=$(echo "$response" | jq -r '.result // empty' 2>/dev/null)
    session_id=$(echo "$response" | jq -r '.session_id // empty' 2>/dev/null)

    if [ -z "$result_text" ]; then
        speak_text "I got a response but couldn't parse it. Try again."
        log_interaction "ERROR" "failed to parse response"
        break
    fi

    [ -n "$session_id" ] && save_session_id "$session_id"

    log_interaction "AGENT" "$result_text"

    deliver_response "$result_text"

    # Brief pause before listening for follow-up
    sleep 1
done
