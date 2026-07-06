#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

export DD_API_KEY=$(get_credential "DD_API_KEY")
export DD_APP_KEY=$(get_credential "DD_APP_KEY")
export DD_SITE="datadoghq.com"

npx -y datadog-mcp-server@latest --transport stdio
