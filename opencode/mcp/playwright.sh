#!/usr/bin/env bash
set -euo pipefail

# Playwright MCP with Chrome Extension mode
# Connects to your existing Chrome browser with all your cookies/sessions
# Requires: Playwright MCP Bridge extension installed in Chrome
#
# To auto-approve connections, get token from extension popup and add:
# export PLAYWRIGHT_MCP_EXTENSION_TOKEN="your-token-here"

npx @playwright/mcp@latest \
  --extension \
  --viewport-size 1280x720 \
  --console-level info
