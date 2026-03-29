#!/data/data/com.termux/files/usr/bin/bash
# sms-watcher.sh — Polls termux-sms-list for new texts from self.
# When a new SMS from own number is detected, POSTs it to phone-channel.
# Runs as a background process in the phone tmux session.
#
# Usage: bash sms-watcher.sh &

POLL_INTERVAL=10  # seconds
PHONE_CHANNEL="http://localhost:8788"
LAST_ID_FILE="$HOME/.sms-watcher-last-id"

# Get own phone number (or set manually if detection fails)
OWN_NUMBER=""

# Initialize last seen ID
if [ -f "$LAST_ID_FILE" ]; then
  LAST_ID=$(cat "$LAST_ID_FILE")
else
  # Seed with current latest SMS ID so we don't process old messages
  LAST_ID=$(termux-sms-list -l 1 2>/dev/null | python -c "import json,sys; msgs=json.load(sys.stdin); print(msgs[0]['_id'] if msgs else 0)" 2>/dev/null || echo "0")
  echo "$LAST_ID" > "$LAST_ID_FILE"
fi

while true; do
  sleep "$POLL_INTERVAL"

  # Get recent SMS (last 5 messages)
  SMS_JSON=$(termux-sms-list -l 5 2>/dev/null) || continue

  # Find new messages from self with ID > LAST_ID
  # termux-sms-list returns: [{_id, number, body, date, type, ...}]
  # type=1 is inbox (received), type=2 is sent
  # We want inbox messages (type=1) from our own number
  RESULT=$(python -c "
import json, sys

last_id = int(sys.argv[1])
own_number = sys.argv[2]
msgs = json.load(sys.stdin)

new_msgs = []
max_id = last_id

for m in msgs:
    msg_id = int(m.get('_id', 0))
    if msg_id <= last_id:
        continue
    max_id = max(max_id, msg_id)

    # Check if from self: type=1 (received) and number matches own
    # If own_number is empty, check if sender == receiver (sent to self)
    sender = m.get('number', '').replace(' ','').replace('-','')
    msg_type = m.get('type', '')

    # Type 1 = received. For self-texts, Android often shows them as received.
    # Also match type 2 (sent) since texting yourself shows in sent too.
    is_self = False
    if own_number:
        clean_own = own_number.replace(' ','').replace('-','')
        is_self = sender.endswith(clean_own[-10:]) if len(clean_own) >= 10 else sender == clean_own
    else:
        # Heuristic: if we can't determine own number, accept all type=1 inbox
        # The user can filter by setting OWN_NUMBER
        is_self = str(msg_type) == '1'

    if is_self:
        new_msgs.append({'id': msg_id, 'body': m.get('body', '')})

print(json.dumps({'max_id': max_id, 'messages': new_msgs}))
" "$LAST_ID" "$OWN_NUMBER" <<< "$SMS_JSON" 2>/dev/null) || continue

  # Parse result
  MAX_ID=$(echo "$RESULT" | python -c "import json,sys; print(json.load(sys.stdin)['max_id'])" 2>/dev/null) || continue
  MESSAGES=$(echo "$RESULT" | python -c "import json,sys; print(json.dumps(json.load(sys.stdin)['messages']))" 2>/dev/null) || continue

  # Process new messages
  MSG_COUNT=$(echo "$MESSAGES" | python -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)

  if [ "$MSG_COUNT" -gt 0 ] 2>/dev/null; then
    echo "$MESSAGES" | python -c "
import json, sys, subprocess

msgs = json.load(sys.stdin)
for m in msgs:
    payload = json.dumps({'source': 'sms', 'body': m['body']})
    subprocess.run(['curl', '-s', '-d', payload, '$PHONE_CHANNEL'], capture_output=True)
" 2>/dev/null

    # Update last seen ID
    echo "$MAX_ID" > "$LAST_ID_FILE"
  fi
done
