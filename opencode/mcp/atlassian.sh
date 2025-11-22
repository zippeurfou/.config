#!/bin/bash

JIRA_URL=https://jira.grubhub.com
CONFLUENCE_URL=https://wiki.grubhub.com
JIRA_PERSONAL_TOKEN=$(op read "op://Employee/Jira Access Token/credential")
CONFLUENCE_PERSONAL_TOKEN=$(op read "op://Employee/Confluence Access Token/credential")
READ_ONLY_MODE=false
MCP_VERBOSE=false        # Enables INFO level logging (equivalent to 'mcp-atlassian -v')

docker run --rm -i \
  -e CONFLUENCE_URL="$CONFLUENCE_URL" \
  -e CONFLUENCE_PERSONAL_TOKEN="$CONFLUENCE_PERSONAL_TOKEN" \
  -e JIRA_URL="$JIRA_URL" \
  -e JIRA_PERSONAL_TOKEN="$JIRA_PERSONAL_TOKEN" \
  -e MCP_VERBOSE="$MCP_VERBOSE" \
  -e READ_ONLY_MODE="$READ_ONLY_MODE" \
  ghcr.io/sooperset/mcp-atlassian:latest
