#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

# Atlassian Cloud URLs (post Jira Cloud migration)
JIRA_URL=https://grubhub.atlassian.net
CONFLUENCE_URL=https://grubhub.atlassian.net/wiki

# Cloud auth: username + API token (same token for both products)
ATLASSIAN_USERNAME="$(whoami)@grubhub.com"
ATLASSIAN_API_TOKEN=$(get_credential "JIRA_PERSONAL_TOKEN" "op://Employee/Jira Access Token/credential")

READ_ONLY_MODE=false
MCP_VERBOSE=false

docker run --rm -i \
  -e JIRA_URL="$JIRA_URL" \
  -e JIRA_USERNAME="$ATLASSIAN_USERNAME" \
  -e JIRA_API_TOKEN="$ATLASSIAN_API_TOKEN" \
  -e CONFLUENCE_URL="$CONFLUENCE_URL" \
  -e CONFLUENCE_USERNAME="$ATLASSIAN_USERNAME" \
  -e CONFLUENCE_API_TOKEN="$ATLASSIAN_API_TOKEN" \
  -e MCP_VERBOSE="$MCP_VERBOSE" \
  -e READ_ONLY_MODE="$READ_ONLY_MODE" \
  ghcr.io/sooperset/mcp-atlassian:latest
