#!/usr/bin/env bash
set -euo pipefail

# Railway MCP for deployment management
# Get token from: https://railway.app/account/tokens
npx -y @railway/mcp-server

# npx @anthropic-ai/mcp-server-railway@latest
