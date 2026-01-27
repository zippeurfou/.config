#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

JIRA_URL=https://jira.grubhub.com
CONFLUENCE_URL=https://wiki.grubhub.com
JIRA_PERSONAL_TOKEN=$(get_credential "JIRA_PERSONAL_TOKEN" "op://Employee/Jira Access Token/credential")
CONFLUENCE_PERSONAL_TOKEN=$(get_credential "CONFLUENCE_PERSONAL_TOKEN" "op://Employee/Confluence Access Token/credential")
READ_ONLY_MODE=false
MCP_VERBOSE=false

docker run --rm -i \
  -e CONFLUENCE_URL="$CONFLUENCE_URL" \
  -e CONFLUENCE_PERSONAL_TOKEN="$CONFLUENCE_PERSONAL_TOKEN" \
  -e JIRA_URL="$JIRA_URL" \
  -e JIRA_PERSONAL_TOKEN="$JIRA_PERSONAL_TOKEN" \
  -e MCP_VERBOSE="$MCP_VERBOSE" \
  -e READ_ONLY_MODE="$READ_ONLY_MODE" \
  ghcr.io/sooperset/mcp-atlassian:latest
