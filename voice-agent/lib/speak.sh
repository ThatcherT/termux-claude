#!/data/data/com.termux/files/usr/bin/bash
# Voice Agent — text-to-speech + notification fallback

speak_text() {
    local text="$1"
    termux-tts-speak -r "$TTS_RATE" "$text"
}

deliver_response() {
    local text="$1"
    local char_count=${#text}

    if [ "$char_count" -le "$TTS_MAX_CHARS" ]; then
        termux-tts-speak -r "$TTS_RATE" "$text"
    else
        # Speak first sentence, full text in notification
        local first_sentence
        first_sentence=$(echo "$text" | sed 's/\. .*/\./')
        termux-tts-speak -r "$TTS_RATE" "$first_sentence"
        termux-notification \
            --id "$NOTIFICATION_ID" \
            --title "Voice Agent" \
            --content "$text" \
            --priority high
    fi
}
