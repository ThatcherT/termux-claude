#!/data/data/com.termux/files/usr/bin/bash
# Voice Agent — session ID persistence + daily reset

STATE_DIR="$AGENT_DIR/state"
SESSION_FILE="$STATE_DIR/session_id"
DATE_FILE="$STATE_DIR/session_date"

mkdir -p "$STATE_DIR"

maybe_reset_session() {
    local today
    today=$(date +%Y-%m-%d)
    local current_hour
    current_hour=$(date +%-H)
    local session_date
    session_date=$(cat "$DATE_FILE" 2>/dev/null || echo "")

    # Reset if new day (after SESSION_RESET_HOUR)
    if [ "$today" != "$session_date" ] && [ "$current_hour" -ge "$SESSION_RESET_HOUR" ]; then
        rm -f "$SESSION_FILE"
        echo "$today" > "$DATE_FILE"
    fi
}

get_session_flag() {
    local sid
    sid=$(cat "$SESSION_FILE" 2>/dev/null || echo "")
    if [ -n "$sid" ]; then
        echo "--resume $sid"
    fi
    # Empty string = new session (no flag)
}

save_session_id() {
    echo "$1" > "$SESSION_FILE"
}
