#!/usr/bin/env bash
# keychain-helper.sh - Helper functions for MCP credential management
# Reads from macOS Keychain first, falls back to 1Password if not found
#
# Usage: source this file and use get_credential function
#
# Service name for all opencode MCP credentials: "opencode-mcp"
# Account name matches the credential key (e.g., "GITHUB_TOKEN", "JIRA_PERSONAL_TOKEN")

KEYCHAIN_SERVICE="opencode-mcp"

# Get a credential from Keychain, fallback to 1Password
# Usage: get_credential "KEY_NAME" "op://vault/item/field" (optional 1Password reference)
get_credential() {
    local key_name="$1"
    local op_ref="${2:-}"
    local value=""
    
    # Try Keychain first (silent failure)
    value=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$key_name" -w 2>/dev/null) || true
    
    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi
    
    # Try 1Password fallback if reference provided
    if [[ -n "$op_ref" ]]; then
        if command -v op &>/dev/null; then
            value=$(op read "$op_ref" 2>/dev/null) || true
            if [[ -n "$value" ]]; then
                echo "$value"
                return 0
            fi
        fi
    fi
    
    # Try environment variable as final fallback (eval for compatibility with zsh)
    local env_value=""
    eval "env_value=\"\${$key_name:-}\""
    if [[ -n "$env_value" ]]; then
        echo "$env_value"
        return 0
    fi
    
    # Return empty string if not found anywhere
    echo ""
    return 1
}

# Check if a credential exists in Keychain
credential_in_keychain() {
    local key_name="$1"
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$key_name" &>/dev/null
}

# Store a credential in Keychain
# Usage: store_credential "KEY_NAME" "value"
store_credential() {
    local key_name="$1"
    local value="$2"
    
    # Delete existing if present (silent failure)
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$key_name" &>/dev/null || true
    
    # Add new credential
    security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$key_name" -w "$value" -U
}

# Delete a credential from Keychain
delete_credential() {
    local key_name="$1"
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$key_name" &>/dev/null || true
}

# List all credentials in Keychain for opencode-mcp service
list_credentials() {
    security dump-keychain 2>/dev/null | grep -A 5 "\"svce\"<blob>=\"$KEYCHAIN_SERVICE\"" | grep "\"acct\"<blob>=" | sed 's/.*=\"\(.*\)\"/\1/' | sort -u
}
