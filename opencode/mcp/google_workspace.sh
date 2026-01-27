#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

export GOOGLE_OAUTH_CLIENT_ID=$(get_credential "GOOGLE_OAUTH_CLIENT_ID" "op://Employee/GOOGLE_OAUTH_CLIENT_ID/credential")
export GOOGLE_OAUTH_CLIENT_SECRET=$(get_credential "GOOGLE_OAUTH_CLIENT_SECRET" "op://Employee/GOOGLE_OAUTH_CLIENT_SECRET/credential")
export OAUTHLIB_INSECURE_TRANSPORT=$(get_credential "OAUTHLIB_INSECURE_TRANSPORT" "op://Employee/OAUTHLIB_INSECURE_TRANSPORT/credential")
export USER_GOOGLE_EMAIL="mferradou@grubhub.com"
export GOOGLE_PSE_ENGINE_ID=$(get_credential "GOOGLE_PSE_ENGINE_ID" "op://Employee/GOOGLE_PSE_ENGINE_ID/credential")
export GOOGLE_PSE_API_KEY=$(get_credential "GOOGLE_PSE_API_KEY" "op://Employee/GOOGLE_PSE_API_KEY/credential")

uvx workspace-mcp
