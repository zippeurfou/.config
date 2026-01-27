# MCP Setup Guide for OpenCode

This guide explains how to configure MCP (Model Context Protocol) servers for OpenCode.

## Quick Start

```bash
# Interactive setup wizard
./setup-mcp.sh

# Migrate existing credentials from 1Password/env vars to Keychain
./setup-mcp.sh --migrate

# Test all configured MCPs
./setup-mcp.sh --test

# Setup a specific MCP
./setup-mcp.sh github
./setup-mcp.sh atlassian
./setup-mcp.sh slack
```

## Credential Storage

Credentials are stored in **macOS Keychain** under the service name `opencode-mcp`.

### Lookup Priority

When an MCP script runs, it looks for credentials in this order:

1. **macOS Keychain** (preferred) - Most secure, persists across sessions
2. **1Password CLI** - Falls back if not in Keychain
3. **Environment Variables** - Last resort fallback

### Managing Keychain Credentials

```bash
# View a credential
security find-generic-password -s "opencode-mcp" -a "GITHUB_TOKEN" -w

# Store a credential manually
security add-generic-password -s "opencode-mcp" -a "GITHUB_TOKEN" -w "ghp_xxx" -U

# Delete a credential
security delete-generic-password -s "opencode-mcp" -a "GITHUB_TOKEN"

# List all opencode-mcp credentials
security dump-keychain 2>/dev/null | grep -A 5 '"svce"<blob>="opencode-mcp"' | grep '"acct"'
```

## MCP Requirements

### GitHub MCP
- **Credential**: `GITHUB_TOKEN`
- **Type**: Personal Access Token (PAT)
- **Scopes**: `repo`, `read:packages`, `read:org`
- **Get it**: [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)

### Atlassian MCP (Jira & Confluence)
- **Credentials**: `JIRA_PERSONAL_TOKEN`, `CONFLUENCE_PERSONAL_TOKEN`
- **Type**: Personal Access Tokens (for Server/Data Center)
- **Get it**: Profile → Personal Access Tokens in each app

### Google Workspace MCP
- **Credentials**: 
  - `GOOGLE_OAUTH_CLIENT_ID` - OAuth 2.0 Client ID
  - `GOOGLE_OAUTH_CLIENT_SECRET` - OAuth 2.0 Client Secret
  - `GOOGLE_PSE_ENGINE_ID` (optional) - Programmable Search Engine ID
  - `GOOGLE_PSE_API_KEY` (optional) - Custom Search API Key
  - `USER_GOOGLE_EMAIL` - Your Google email
- **Setup**: Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
- **APIs to enable**: Gmail, Calendar, Drive, Docs, Sheets, Slides, Tasks, Custom Search

### Slack MCP
- **Credentials**: `SLACK_MCP_XOXC_TOKEN`, `SLACK_MCP_XOXD_TOKEN`
- **Type**: Browser session tokens
- **Get it**: Extract from browser DevTools (see wizard for instructions)
- **Note**: Tokens expire when you log out of Slack in browser

### LinkedIn MCP
- **Credential**: `LINKEDIN_COOKIE`
- **Type**: `li_at` cookie from browser
- **Get it**: DevTools → Application → Cookies → linkedin.com → `li_at`
- **Tip**: Use incognito window to avoid session conflicts

### Railway MCP
- **Credential**: None stored - uses Railway CLI authentication
- **Setup**: Run `railway login` to authenticate
- **Check**: `railway whoami`

### Playwright MCP
- **Credential**: `PLAYWRIGHT_MCP_EXTENSION_TOKEN` (optional)
- **Setup**: Install Chrome extension from [Playwright MCP releases](https://github.com/microsoft/playwright-mcp/releases)
- **Mode**: Connects to existing Chrome browser with extension

### Peekaboo MCP (macOS)
- **Credentials**: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` (optional, for image analysis)
- **Requirements**: macOS 15+, Screen Recording permission, Accessibility permission
- **Setup**: Grant permissions in System Settings → Privacy & Security

### GDP MCP (Grubhub Data Platform)
- **Credentials**:
  - `GDP_PRESTO_USER` - Okta username
  - `GDP_PRESTO_PASSWORD` - Okta password
  - `REDASH_API_KEY` - Redash API key
- **Get Redash key**: [Redash Profile](https://redash.gdp.data.grubhub.com/users/me)

## File Structure

```
~/.config/opencode/
├── setup-mcp.sh              # Interactive setup wizard
├── mcp/
│   ├── keychain-helper.sh    # Shared credential lookup functions
│   ├── github.sh             # GitHub MCP wrapper
│   ├── atlassian.sh          # Jira/Confluence MCP wrapper
│   ├── google_workspace.sh   # Google Workspace MCP wrapper
│   ├── mcp-slack.sh          # Slack MCP wrapper
│   ├── linkedin-mcp-server.sh# LinkedIn MCP wrapper
│   ├── railway.sh            # Railway MCP wrapper
│   ├── playwright.sh         # Playwright MCP wrapper
│   ├── peekaboo.sh           # Peekaboo MCP wrapper
│   └── ...                   # Other MCP wrappers
└── mcp.json                  # OpenCode MCP configuration
```

## How Wrapper Scripts Work

Each MCP wrapper script in `mcp/`:

1. Sources `keychain-helper.sh` for credential lookup
2. Uses `get_credential "KEY_NAME"` to retrieve secrets
3. Exports credentials as environment variables
4. Launches the actual MCP server (via npx, uvx, or direct binary)

Example from `github.sh`:
```bash
source "$(dirname "$0")/keychain-helper.sh"
export GITHUB_PERSONAL_ACCESS_TOKEN="$(get_credential "GITHUB_TOKEN")"
exec npx -y @modelcontextprotocol/server-github
```

## Troubleshooting

### Credential not found
```bash
# Check if credential exists in Keychain
security find-generic-password -s "opencode-mcp" -a "CREDENTIAL_NAME" 2>/dev/null && echo "Found" || echo "Not found"

# Run migration to populate Keychain
./setup-mcp.sh --migrate
```

### MCP fails to start
```bash
# Test the MCP configuration
./setup-mcp.sh --test

# Check specific MCP logs
# MCPs run via shell wrappers - add debugging to the wrapper script
```

### Token expired
- **Slack**: Re-extract tokens from browser (they expire on logout)
- **LinkedIn**: Re-extract `li_at` cookie
- **GitHub**: Generate new PAT if expired
- **Atlassian**: Generate new PAT if expired

### 1Password not working
```bash
# Check if op CLI is installed and signed in
op whoami

# Sign in if needed
op signin
```

### Reset a credential
```bash
# Delete from Keychain
security delete-generic-password -s "opencode-mcp" -a "CREDENTIAL_NAME"

# Re-run setup for that MCP
./setup-mcp.sh github  # or whichever MCP
```

## Migration from 1Password

If you previously stored credentials in 1Password, migrate them to Keychain:

```bash
./setup-mcp.sh --migrate
```

This will:
1. Read each credential from 1Password (using `op read`)
2. Fall back to environment variables if not in 1Password
3. Store found credentials in macOS Keychain
4. Skip credentials already in Keychain

After migration, credentials load faster (no 1Password CLI calls) and work offline.

## Adding New MCPs

1. Create a wrapper script in `mcp/your-mcp.sh`:
```bash
#!/usr/bin/env bash
source "$(dirname "$0")/keychain-helper.sh"
export YOUR_API_KEY="$(get_credential "YOUR_API_KEY")"
exec npx -y @your/mcp-server
```

2. Make it executable: `chmod +x mcp/your-mcp.sh`

3. Add to `mcp.json`:
```json
"your-mcp": {
  "command": "/Users/you/.config/opencode/mcp/your-mcp.sh"
}
```

4. Optionally add setup function to `setup-mcp.sh`
