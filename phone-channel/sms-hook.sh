#!/data/data/com.termux/files/usr/bin/bash
# sms-hook.sh — Tasker calls this when an SMS arrives from self.
# Forwards the SMS body to phone-channel for Claude to evaluate.
# Place at: ~/.termux/tasker/sms-hook.sh
#
# Tasker config:
#   Profile: Event > Phone > Received Text > Sender = own number
#   Task: Plugin > Termux:Tasker > sms-hook.sh > Arguments: %SMSRB

SMS_BODY="$1"
[ -z "$SMS_BODY" ] && exit 1

# JSON-encode the body safely and POST to phone-channel
PAYLOAD=$(python -c "import json,sys; print(json.dumps({'source':'sms','body':sys.argv[1]}))" "$SMS_BODY")
curl -s -d "$PAYLOAD" http://localhost:8788 >/dev/null 2>&1
