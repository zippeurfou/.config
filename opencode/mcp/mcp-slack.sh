#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

export SLACK_MCP_XOXC_TOKEN=$(get_credential "SLACK_MCP_XOXC_TOKEN" "op://Employee/SLACK_MCP_XOXC_TOKEN/credential")
export SLACK_MCP_XOXD_TOKEN=$(get_credential "SLACK_MCP_XOXD_TOKEN" "op://Employee/SLACK_MCP_XOXD_TOKEN/credential")
export SLACK_MCP_CUSTOM_TLS=1
export SLACK_MCP_USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36"

docker run -i --rm \
  -e SLACK_MCP_XOXC_TOKEN \
  -e SLACK_MCP_XOXD_TOKEN \
  -e SLACK_MCP_CUSTOM_TLS \
  -e SLACK_MCP_USER_AGENT \
  ghcr.io/korotovsky/slack-mcp-server:latest mcp-server --transport stdio
