#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

GITHUB_TOKEN=$(get_credential "GITHUB_TOKEN" "op://Employee/GitHub PAT/credential")

docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" ghcr.io/github/github-mcp-server
