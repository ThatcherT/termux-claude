#!/usr/bin/env bash
# Agent coordination helpers — source this from either agent
# Usage: source coord.sh

PHONE_IP="100.74.17.91"
PHONE_PORT=8788
PHONE_SSH_PORT=8022
DESKTOP_IP="100.99.44.89"
DESKTOP_PORT=8789

PHONE="$PHONE_IP:$PHONE_PORT"
DESKTOP="$DESKTOP_IP:$DESKTOP_PORT"

send_to_phone() {
  curl -s -d "$1" "http://$PHONE"
}

send_to_desktop() {
  curl -s -d "$1" "http://$DESKTOP"
}

phone_health() {
  curl -sf "http://$PHONE/health" >/dev/null 2>&1
}

desktop_health() {
  curl -sf "http://$DESKTOP/health" >/dev/null 2>&1
}

# Send a task and wait for the result on the SSE stream
# Usage: send_task_to_phone '{"task_id":"d-001","type":"exec","body":"..."}'
# Returns the first SSE event (the reply)
send_task_to_phone() {
  local task="$1"
  local timeout_secs="${2:-120}"
  curl -s -d "$task" "http://$PHONE"
  timeout "$timeout_secs" curl -sN "http://$PHONE/events" | while IFS= read -r line; do
    case "$line" in
      data:*) echo "${line#data: }"; break ;;
    esac
  done
}

send_task_to_desktop() {
  local task="$1"
  local timeout_secs="${2:-120}"
  curl -s -d "$task" "http://$DESKTOP"
  timeout "$timeout_secs" curl -sN "http://$DESKTOP/events" | while IFS= read -r line; do
    case "$line" in
      data:*) echo "${line#data: }"; break ;;
    esac
  done
}

phone_ssh() {
  ssh -p "$PHONE_SSH_PORT" "$PHONE_IP" "$@"
}

phone_scp() {
  scp -P "$PHONE_SSH_PORT" "$@" "$PHONE_IP:"
}
