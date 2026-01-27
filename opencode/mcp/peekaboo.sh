#!/usr/bin/env bash
set -euo pipefail

# Peekaboo MCP Server - macOS screen capture and GUI automation
# Provides: see, click, type, scroll, hotkey, menu, menubar, dock, window, dialog, image tools
# Requires: macOS 15+, Screen Recording + Accessibility permissions
#
# Optional: Set AI providers for visual analysis
# export PEEKABOO_AI_PROVIDERS="anthropic/claude-opus-4,openai/gpt-5.1"

# Use the peekaboo-mcp wrapper script which launches "peekaboo mcp serve"
npx -y -p @steipete/peekaboo peekaboo-mcp
