#!/data/data/com.termux/files/usr/bin/bash
# Voice Agent — one-time setup
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_HOME="$HOME/voice-agent"

echo "=== Voice Agent Setup ==="
echo ""

# Create working directory with CLAUDE.md
echo "[1/5] Creating agent workspace..."
mkdir -p "$AGENT_HOME"/{logs,state,lib}
cp "$SCRIPT_DIR/CLAUDE.md" "$AGENT_HOME/CLAUDE.md"
cp "$SCRIPT_DIR/config.sh" "$AGENT_HOME/config.sh"
cp "$SCRIPT_DIR/lib/"*.sh "$AGENT_HOME/lib/"
cp "$SCRIPT_DIR/agent.sh" "$AGENT_HOME/agent.sh"
chmod +x "$AGENT_HOME/agent.sh"

# Install jq for JSON parsing
echo "[2/5] Installing jq..."
pkg install -y jq 2>/dev/null || true

# Ensure termux-api is installed
echo "[3/5] Checking termux-api..."
if ! command -v termux-speech-to-text &>/dev/null; then
    pkg install -y termux-api
    echo ""
    echo "IMPORTANT: Install the Termux:API app from F-Droid:"
    echo "  https://f-droid.org/en/packages/com.termux.api/"
    echo ""
fi

# Set up Termux:Widget shortcuts
echo "[4/5] Setting up widget shortcuts..."
mkdir -p "$HOME/.shortcuts"
cp "$SCRIPT_DIR/shortcuts/voice-agent.sh" "$HOME/.shortcuts/Voice Agent"
cp "$SCRIPT_DIR/shortcuts/voice-reset.sh" "$HOME/.shortcuts/Reset Agent"
chmod +x "$HOME/.shortcuts/Voice Agent"
chmod +x "$HOME/.shortcuts/Reset Agent"

# Grant storage access if needed
echo "[5/5] Checking storage access..."
if [ ! -d "$HOME/storage" ]; then
    echo "Run 'termux-setup-storage' to grant storage access (optional, for file management)."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Install Termux:Widget from F-Droid (if not already installed)"
echo "     https://f-droid.org/en/packages/com.termux.widget/"
echo "  2. Install Termux:API from F-Droid (if not already installed)"
echo "     https://f-droid.org/en/packages/com.termux.api/"
echo "  3. Long-press home screen -> Widgets -> Termux:Widget"
echo "  4. Tap 'Voice Agent' to start talking"
echo ""
echo "Widget shortcuts installed:"
echo "  - Voice Agent  — tap to talk"
echo "  - Reset Agent  — tap to start fresh session"
echo ""
echo "To customize the agent, edit: $AGENT_HOME/CLAUDE.md"
echo "To change settings, edit: $AGENT_HOME/config.sh"
