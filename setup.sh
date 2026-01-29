#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATH_ENTRY="export PATH=\"$SCRIPT_DIR/bin:\$PATH\""

echo "=== takt-sandbox setup ==="
echo ""

# Docker check
if ! command -v docker &> /dev/null; then
  echo "[ERROR] docker command not found. Please install Docker Desktop."
  exit 1
fi

# Build image
echo "[1/3] Building Docker image..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" build
echo ""

# Verify
echo "[2/3] Verifying installation..."
TAKT_VERSION=$(docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm --entrypoint "" takt takt --version 2>/dev/null)
CLAUDE_VERSION=$(docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm --entrypoint "" takt claude --version 2>/dev/null)
echo "  takt:       $TAKT_VERSION"
echo "  Claude Code: $CLAUDE_VERSION"
echo ""

# Detect shell config
echo "[3/3] Configuring PATH..."
SHELL_NAME="$(basename "$SHELL")"
case "$SHELL_NAME" in
  zsh)  SHELL_RC="$HOME/.zshrc" ;;
  bash) SHELL_RC="$HOME/.bashrc" ;;
  *)    SHELL_RC="$HOME/.profile" ;;
esac

if [ -f "$SHELL_RC" ] && grep -qF "takt-sandbox/bin" "$SHELL_RC"; then
  echo "  PATH already configured in $SHELL_RC (skipped)"
else
  echo "" >> "$SHELL_RC"
  echo "# takt-sandbox" >> "$SHELL_RC"
  echo "$PATH_ENTRY" >> "$SHELL_RC"
  echo "  Added to $SHELL_RC"
fi
echo ""

echo "=== Setup complete ==="
echo ""
echo "Reload your shell to activate:"
echo ""
echo "  source $SHELL_RC"
echo ""
echo "Then use takt from any project:"
echo ""
echo "  cd /your/project && takt \"your task\""
echo ""
echo "Note: Claude Code authentication is shared from host (~/.claude/)."
echo "      Run 'claude login' on host if not yet authenticated."
