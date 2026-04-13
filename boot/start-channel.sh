#!/data/data/com.termux/files/usr/bin/bash
# Termux:Boot — auto-start phone channel on device boot
termux-wake-lock 2>/dev/null || true
pgrep -x sshd > /dev/null || sshd
sleep 10  # wait for network/tailscale
bash ~/phone-channel/start.sh
