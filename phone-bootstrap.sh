#!/usr/bin/env bash
# Bootstrap the phone's Claude Code + phone-channel from the desktop
# Usage: bash phone-bootstrap.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coord.sh"

echo "Checking phone-channel health..."
if phone_health; then
  echo "Phone-channel is already running."
  exit 0
fi

echo "Phone-channel is down. SSHing in to restart..."
phone_ssh 'bash ~/phone-channel/health-restart.sh'

echo "Waiting for phone-channel to come up..."
for i in $(seq 1 30); do
  if phone_health; then
    echo "Phone-channel is up."
    exit 0
  fi
  sleep 2
done

echo "ERROR: Phone-channel did not start within 60 seconds."
echo "Try SSHing in manually: ssh -p 8022 $PHONE_IP"
exit 1
