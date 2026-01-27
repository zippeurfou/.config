#!/usr/bin/env bash
#
# MCP Setup Wizard for OpenCode
# Interactive tool to configure MCP server credentials and dependencies
#
# Usage:
#   ./setup-mcp.sh              # Interactive setup wizard
#   ./setup-mcp.sh --test       # Test all configured MCPs
#   ./setup-mcp.sh --migrate    # Migrate credentials from 1Password to Keychain
#   ./setup-mcp.sh github       # Setup specific MCP only
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="${SCRIPT_DIR}/mcp"
KEYCHAIN_SERVICE="opencode-mcp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        read -r -p "$(echo -e "${CYAN}?${NC} ${prompt} [Y/n] ")" response
        response=${response:-y}
    else
        read -r -p "$(echo -e "${CYAN}?${NC} ${prompt} [y/N] ")" response
        response=${response:-n}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    
    echo -ne "${CYAN}?${NC} ${prompt}: "
    read -rs value
    echo ""
    eval "$var_name='$value'"
}

prompt_value() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    
    if [[ -n "$default" ]]; then
        read -r -p "$(echo -e "${CYAN}?${NC} ${prompt} [${default}]: ")" value
        value=${value:-$default}
    else
        read -r -p "$(echo -e "${CYAN}?${NC} ${prompt}: ")" value
    fi
    eval "$var_name='$value'"
}

open_url() {
    local url="$1"
    print_info "Opening: $url"
    open "$url" 2>/dev/null || xdg-open "$url" 2>/dev/null || echo "Please open: $url"
}

wait_for_enter() {
    read -r -p "$(echo -e "${CYAN}Press Enter when ready...${NC}")"
}

# ============================================================================
# Keychain Functions
# ============================================================================

keychain_store() {
    local key="$1"
    local value="$2"
    
    # Delete existing entry if it exists (suppress errors)
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$key" 2>/dev/null || true
    
    # Add new entry
    security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$key" -w "$value" -U
    
    if [[ $? -eq 0 ]]; then
        print_success "Stored '$key' in Keychain"
        return 0
    else
        print_error "Failed to store '$key' in Keychain"
        return 1
    fi
}

keychain_get() {
    local key="$1"
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$key" -w 2>/dev/null
}

keychain_exists() {
    local key="$1"
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$key" -w >/dev/null 2>&1
}

keychain_delete() {
    local key="$1"
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$key" 2>/dev/null
}

keychain_list() {
    security dump-keychain 2>/dev/null | grep -A 4 "\"svce\"<blob>=\"$KEYCHAIN_SERVICE\"" | grep "\"acct\"" | sed 's/.*="//;s/".*//' | sort -u
}

# ============================================================================
# 1Password Migration Functions
# ============================================================================

op_read_safe() {
    local ref="$1"
    if command -v op &>/dev/null; then
        op read "$ref" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

migrate_from_1password() {
    print_header "Migrating Credentials from 1Password to Keychain"
    
    if ! command -v op &>/dev/null; then
        print_error "1Password CLI (op) not found. Cannot migrate."
        return 1
    fi
    
    print_info "This will copy credentials from 1Password to macOS Keychain."
    print_info "Your 1Password entries will NOT be deleted."
    echo ""
    
    # Define 1Password references to migrate
    # NOTE: bash 3.2 (macOS default) has a bug where `local -A arr=(...)` resets
    # the array after assignment. Must declare first, then assign separately.
    local -A op_refs
    op_refs=(
        ["GITHUB_TOKEN"]="op://Employee/GitHub PAT/credential"
        ["JIRA_PERSONAL_TOKEN"]="op://Employee/Jira Access Token/credential"
        ["CONFLUENCE_PERSONAL_TOKEN"]="op://Employee/Confluence Access Token/credential"
        ["GOOGLE_OAUTH_CLIENT_ID"]="op://Employee/GOOGLE_OAUTH_CLIENT_ID/credential"
        ["GOOGLE_OAUTH_CLIENT_SECRET"]="op://Employee/GOOGLE_OAUTH_CLIENT_SECRET/credential"
        ["GOOGLE_PSE_ENGINE_ID"]="op://Employee/GOOGLE_PSE_ENGINE_ID/credential"
        ["GOOGLE_PSE_API_KEY"]="op://Employee/GOOGLE_PSE_API_KEY/credential"
        ["SLACK_MCP_XOXC_TOKEN"]="op://Employee/SLACK_MCP_XOXC_TOKEN/credential"
        ["SLACK_MCP_XOXD_TOKEN"]="op://Employee/SLACK_MCP_XOXD_TOKEN/credential"
        ["LINKEDIN_COOKIE"]="op://Employee/LINKEDIN_COOKIE/credential"
        ["GDP_PRESTO_USER"]="op://Employee/Okta/username"
        ["GDP_PRESTO_PASSWORD"]="op://Employee/Okta/credential"
        ["REDASH_API_KEY"]="op://Employee/Redash/credential"
    )
    
    local migrated=0
    local failed=0
    local skipped=0
    
    for key in "${!op_refs[@]}"; do
        local ref="${op_refs[$key]}"
        print_step "Migrating $key..."
        
        if keychain_exists "$key"; then
            print_warning "  Already exists in Keychain, skipping"
            ((++skipped))
            continue
        fi
        
        local value
        value=$(op_read_safe "$ref")
        
        if [[ -z "$value" ]]; then
            eval "value=\"\${$key:-}\""
        fi
        
        if [[ -n "$value" ]]; then
            if keychain_store "$key" "$value"; then
                ((++migrated))
            else
                ((++failed))
            fi
        else
            print_warning "  Not found in 1Password or environment"
            ((++skipped))
        fi
    done
    
    echo ""
    print_header "Migration Complete"
    print_success "Migrated: $migrated"
    print_warning "Skipped: $skipped"
    if [[ $failed -gt 0 ]]; then
        print_error "Failed: $failed"
    fi
}

# ============================================================================
# Dependency Management
# ============================================================================

check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing=()
    
    # Check for Homebrew
    if ! command -v brew &>/dev/null; then
        missing+=("homebrew")
        print_error "Homebrew not found"
    else
        print_success "Homebrew installed"
    fi
    
    # Check for Node.js/npm
    if ! command -v node &>/dev/null; then
        missing+=("node")
        print_error "Node.js not found"
    else
        print_success "Node.js $(node --version) installed"
    fi
    
    # Check for npm/npx
    if ! command -v npx &>/dev/null; then
        missing+=("npm")
        print_error "npx not found"
    else
        print_success "npx installed"
    fi
    
    # Check for Docker
    if ! command -v docker &>/dev/null; then
        missing+=("docker")
        print_error "Docker not found"
    else
        if docker info &>/dev/null; then
            print_success "Docker installed and running"
        else
            print_warning "Docker installed but not running"
            missing+=("docker-running")
        fi
    fi
    
    # Check for uv/uvx
    if ! command -v uvx &>/dev/null; then
        missing+=("uv")
        print_error "uvx not found"
    else
        print_success "uvx installed"
    fi
    
    # Check for 1Password CLI (optional)
    if command -v op &>/dev/null; then
        print_success "1Password CLI installed (for migration)"
    else
        print_info "1Password CLI not found (optional, for migration)"
    fi
    
    # Check for Railway CLI (optional for Railway MCP)
    if command -v railway &>/dev/null; then
        print_success "Railway CLI installed"
    else
        print_info "Railway CLI not found (needed for Railway MCP)"
    fi
    
    echo ""
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Some dependencies are missing. Install them?"
        if confirm "Install missing dependencies?"; then
            install_dependencies "${missing[@]}"
        fi
    else
        print_success "All dependencies installed!"
    fi
}

install_dependencies() {
    local deps=("$@")
    
    for dep in "${deps[@]}"; do
        case "$dep" in
            homebrew)
                print_step "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                ;;
            node)
                print_step "Installing Node.js..."
                brew install node
                ;;
            npm)
                print_step "npm comes with Node.js, installing Node..."
                brew install node
                ;;
            docker)
                print_step "Installing Docker..."
                brew install --cask docker
                print_info "Please start Docker Desktop from Applications"
                ;;
            docker-running)
                print_step "Starting Docker..."
                open -a Docker
                print_info "Waiting for Docker to start..."
                sleep 10
                ;;
            uv)
                print_step "Installing uv..."
                curl -LsSf https://astral.sh/uv/install.sh | sh
                # Add to PATH for current session
                export PATH="$HOME/.local/bin:$PATH"
                ;;
            railway)
                print_step "Installing Railway CLI..."
                brew install railway
                ;;
        esac
    done
}

# ============================================================================
# MCP Setup Functions
# ============================================================================

# GitHub MCP Setup
setup_github() {
    print_header "GitHub MCP Setup"
    
    print_info "The GitHub MCP requires a Personal Access Token (PAT)."
    print_info "The token needs these scopes: repo, read:packages, read:org"
    echo ""
    
    # Check if already configured
    if keychain_exists "GITHUB_TOKEN"; then
        print_success "GitHub token already configured in Keychain"
        if ! confirm "Reconfigure?"; then
            return 0
        fi
    fi
    
    print_step "Step 1: Create a GitHub Personal Access Token"
    echo ""
    echo "   1. Go to GitHub → Settings → Developer settings → Personal access tokens"
    echo "   2. Click 'Generate new token' (classic)"
    echo "   3. Name it (e.g., 'OpenCode MCP')"
    echo "   4. Select scopes: repo, read:packages, read:org"
    echo "   5. Click 'Generate token' and copy it"
    echo ""
    
    if confirm "Open GitHub token page in browser?"; then
        open_url "https://github.com/settings/tokens/new?description=OpenCode%20MCP&scopes=repo,read:packages,read:org"
    fi
    
    wait_for_enter
    
    prompt_secret "Paste your GitHub token (ghp_...)" GITHUB_TOKEN
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        print_error "No token provided"
        return 1
    fi
    
    keychain_store "GITHUB_TOKEN" "$GITHUB_TOKEN"
    
    # Test the token
    print_step "Testing GitHub token..."
    if test_github; then
        print_success "GitHub MCP configured successfully!"
    else
        print_error "Token test failed. Please verify and try again."
        return 1
    fi
}

test_github() {
    local token
    token=$(keychain_get "GITHUB_TOKEN" 2>/dev/null) || return 1
    
    local response
    response=$(curl -s -H "Authorization: Bearer $token" https://api.github.com/user 2>/dev/null)
    
    if echo "$response" | grep -q '"login"'; then
        local username
        username=$(echo "$response" | grep -o '"login": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/".*//')
        print_success "Authenticated as: $username"
        return 0
    else
        print_error "Authentication failed"
        return 1
    fi
}

# Atlassian MCP Setup
setup_atlassian() {
    print_header "Atlassian MCP Setup (Jira & Confluence)"
    
    print_info "The Atlassian MCP requires Personal Access Tokens for Jira and Confluence."
    print_info "For Server/Data Center deployments (like jira.grubhub.com)."
    echo ""
    
    # Check existing configuration
    local jira_exists=false
    local confluence_exists=false
    
    if keychain_exists "JIRA_PERSONAL_TOKEN"; then
        jira_exists=true
        print_success "Jira token already configured"
    fi
    
    if keychain_exists "CONFLUENCE_PERSONAL_TOKEN"; then
        confluence_exists=true
        print_success "Confluence token already configured"
    fi
    
    if $jira_exists && $confluence_exists; then
        if ! confirm "Both tokens exist. Reconfigure?"; then
            return 0
        fi
    fi
    
    # Jira Setup
    print_step "Step 1: Create Jira Personal Access Token"
    echo ""
    echo "   1. Go to Jira → Click your avatar → Profile"
    echo "   2. Select 'Personal Access Tokens'"
    echo "   3. Click 'Create token'"
    echo "   4. Name it (e.g., 'OpenCode MCP') and set expiry"
    echo "   5. Copy the token immediately"
    echo ""
    
    if confirm "Open Jira profile page?"; then
        open_url "https://jira.grubhub.com/secure/ViewProfile.jspa"
    fi
    
    wait_for_enter
    
    prompt_secret "Paste your Jira Personal Access Token" JIRA_TOKEN
    
    if [[ -n "$JIRA_TOKEN" ]]; then
        keychain_store "JIRA_PERSONAL_TOKEN" "$JIRA_TOKEN"
    fi
    
    # Confluence Setup
    print_step "Step 2: Create Confluence Personal Access Token"
    echo ""
    echo "   1. Go to Confluence → Click your avatar → Profile"
    echo "   2. Select 'Personal Access Tokens'"
    echo "   3. Click 'Create token'"
    echo "   4. Name it and copy the token"
    echo ""
    
    if confirm "Open Confluence profile page?"; then
        open_url "https://wiki.grubhub.com/users/viewmyprofile.action"
    fi
    
    wait_for_enter
    
    prompt_secret "Paste your Confluence Personal Access Token" CONFLUENCE_TOKEN
    
    if [[ -n "$CONFLUENCE_TOKEN" ]]; then
        keychain_store "CONFLUENCE_PERSONAL_TOKEN" "$CONFLUENCE_TOKEN"
    fi
    
    # Test
    print_step "Testing Atlassian tokens..."
    if test_atlassian; then
        print_success "Atlassian MCP configured successfully!"
    else
        print_warning "Token test had issues. Check the errors above."
    fi
}

test_atlassian() {
    local success=true
    
    # Test Jira
    local jira_token
    jira_token=$(keychain_get "JIRA_PERSONAL_TOKEN" 2>/dev/null)
    
    if [[ -n "$jira_token" ]]; then
        local response
        response=$(curl -s -H "Authorization: Bearer $jira_token" "https://jira.grubhub.com/rest/api/2/myself" 2>/dev/null)
        
        if echo "$response" | grep -q '"displayName"'; then
            local name
            name=$(echo "$response" | grep -o '"displayName": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/".*//')
            print_success "Jira: Authenticated as $name"
        else
            print_error "Jira: Authentication failed"
            success=false
        fi
    else
        print_warning "Jira: No token configured"
    fi
    
    # Test Confluence
    local confluence_token
    confluence_token=$(keychain_get "CONFLUENCE_PERSONAL_TOKEN" 2>/dev/null)
    
    if [[ -n "$confluence_token" ]]; then
        local response
        response=$(curl -s -H "Authorization: Bearer $confluence_token" "https://wiki.grubhub.com/rest/api/user/current" 2>/dev/null)
        
        if echo "$response" | grep -q '"displayName"\|"username"'; then
            print_success "Confluence: Authentication successful"
        else
            print_error "Confluence: Authentication failed"
            success=false
        fi
    else
        print_warning "Confluence: No token configured"
    fi
    
    $success
}

# Google Workspace MCP Setup
setup_google_workspace() {
    print_header "Google Workspace MCP Setup"
    
    print_info "This MCP requires OAuth 2.0 credentials from Google Cloud Console."
    print_info "You'll need to create a project and enable several APIs."
    echo ""
    
    # Check existing
    if keychain_exists "GOOGLE_OAUTH_CLIENT_ID" && keychain_exists "GOOGLE_OAUTH_CLIENT_SECRET"; then
        print_success "Google OAuth credentials already configured"
        if ! confirm "Reconfigure?"; then
            return 0
        fi
    fi
    
    print_step "Step 1: Create or select a Google Cloud Project"
    echo ""
    echo "   1. Go to Google Cloud Console"
    echo "   2. Create a new project or select existing"
    echo ""
    
    if confirm "Open Google Cloud Console?"; then
        open_url "https://console.cloud.google.com/"
    fi
    
    wait_for_enter
    
    print_step "Step 2: Enable required APIs"
    echo ""
    echo "   Enable these APIs in your project:"
    echo "   • Gmail API"
    echo "   • Google Calendar API"
    echo "   • Google Drive API"
    echo "   • Google Docs API"
    echo "   • Google Sheets API"
    echo "   • Google Slides API"
    echo "   • Google Tasks API"
    echo "   • Custom Search API (for web search)"
    echo ""
    
    if confirm "Open API Library to enable APIs?"; then
        open_url "https://console.cloud.google.com/apis/library"
    fi
    
    wait_for_enter
    
    print_step "Step 3: Configure OAuth Consent Screen"
    echo ""
    echo "   1. Go to APIs & Services → OAuth consent screen"
    echo "   2. Choose 'Internal' (for Workspace) or 'External'"
    echo "   3. Fill in app name, support email"
    echo "   4. Add scopes for the APIs you enabled"
    echo ""
    
    if confirm "Open OAuth consent screen?"; then
        open_url "https://console.cloud.google.com/apis/credentials/consent"
    fi
    
    wait_for_enter
    
    print_step "Step 4: Create OAuth 2.0 Credentials"
    echo ""
    echo "   1. Go to APIs & Services → Credentials"
    echo "   2. Click 'Create Credentials' → 'OAuth client ID'"
    echo "   3. Application type: 'Desktop app'"
    echo "   4. Name it (e.g., 'OpenCode MCP')"
    echo "   5. Copy the Client ID and Client Secret"
    echo ""
    
    if confirm "Open Credentials page?"; then
        open_url "https://console.cloud.google.com/apis/credentials"
    fi
    
    wait_for_enter
    
    prompt_value "Enter Google OAuth Client ID" GOOGLE_CLIENT_ID
    prompt_secret "Enter Google OAuth Client Secret" GOOGLE_CLIENT_SECRET
    
    if [[ -n "$GOOGLE_CLIENT_ID" ]]; then
        keychain_store "GOOGLE_OAUTH_CLIENT_ID" "$GOOGLE_CLIENT_ID"
    fi
    
    if [[ -n "$GOOGLE_CLIENT_SECRET" ]]; then
        keychain_store "GOOGLE_OAUTH_CLIENT_SECRET" "$GOOGLE_CLIENT_SECRET"
    fi
    
    # Optional: Programmable Search Engine
    echo ""
    if confirm "Configure Google Programmable Search Engine (for web search)?"; then
        print_step "Step 5: Create Programmable Search Engine"
        echo ""
        echo "   1. Go to Programmable Search Engine control panel"
        echo "   2. Create a new search engine"
        echo "   3. Choose 'Search the entire web'"
        echo "   4. Copy the Search Engine ID"
        echo ""
        
        if confirm "Open Programmable Search Engine?"; then
            open_url "https://programmablesearchengine.google.com/controlpanel/create"
        fi
        
        wait_for_enter
        
        prompt_value "Enter Search Engine ID" PSE_ENGINE_ID
        
        print_step "Step 6: Get Custom Search API Key"
        echo ""
        echo "   1. Go to Credentials page"
        echo "   2. Create an API Key"
        echo "   3. Restrict it to 'Custom Search API'"
        echo ""
        
        if confirm "Open Credentials page?"; then
            open_url "https://console.cloud.google.com/apis/credentials"
        fi
        
        wait_for_enter
        
        prompt_secret "Enter Custom Search API Key" PSE_API_KEY
        
        if [[ -n "$PSE_ENGINE_ID" ]]; then
            keychain_store "GOOGLE_PSE_ENGINE_ID" "$PSE_ENGINE_ID"
        fi
        
        if [[ -n "$PSE_API_KEY" ]]; then
            keychain_store "GOOGLE_PSE_API_KEY" "$PSE_API_KEY"
        fi
    fi
    
    # Store email
    prompt_value "Enter your Google email address" GOOGLE_EMAIL "mferradou@grubhub.com"
    if [[ -n "$GOOGLE_EMAIL" ]]; then
        keychain_store "USER_GOOGLE_EMAIL" "$GOOGLE_EMAIL"
    fi
    
    print_success "Google Workspace MCP configured!"
    print_info "Note: You'll need to complete OAuth flow on first use."
}

test_google_workspace() {
    local success=true
    
    if keychain_exists "GOOGLE_OAUTH_CLIENT_ID"; then
        print_success "Google OAuth Client ID: configured"
    else
        print_error "Google OAuth Client ID: missing"
        success=false
    fi
    
    if keychain_exists "GOOGLE_OAUTH_CLIENT_SECRET"; then
        print_success "Google OAuth Client Secret: configured"
    else
        print_error "Google OAuth Client Secret: missing"
        success=false
    fi
    
    if keychain_exists "GOOGLE_PSE_ENGINE_ID"; then
        print_success "Google PSE Engine ID: configured"
    else
        print_info "Google PSE Engine ID: not configured (optional)"
    fi
    
    $success
}

# Slack MCP Setup
setup_slack() {
    print_header "Slack MCP Setup"
    
    print_info "The Slack MCP requires xoxc and xoxd tokens from your browser session."
    print_warning "These tokens give full access to your Slack account - keep them secure!"
    echo ""
    
    if keychain_exists "SLACK_MCP_XOXC_TOKEN" && keychain_exists "SLACK_MCP_XOXD_TOKEN"; then
        print_success "Slack tokens already configured"
        if ! confirm "Reconfigure?"; then
            return 0
        fi
    fi
    
    print_step "Step 1: Extract xoxc token"
    echo ""
    echo "   1. Open Slack in your browser and log in"
    echo "   2. Open Developer Tools (F12 or Cmd+Option+I)"
    echo "   3. Go to Console tab"
    echo "   4. Type 'allow pasting' and press Enter"
    echo "   5. Paste this code and press Enter:"
    echo ""
    echo -e "   ${CYAN}JSON.parse(localStorage.localConfig_v2).teams[document.location.pathname.match(/^\\/client\\/([A-Z0-9]+)/)[1]].token${NC}"
    echo ""
    echo "   6. Copy the output (starts with xoxc-)"
    echo ""
    
    if confirm "Open Slack in browser?"; then
        open_url "https://app.slack.com/"
    fi
    
    wait_for_enter
    
    prompt_secret "Paste your xoxc token" XOXC_TOKEN
    
    print_step "Step 2: Extract xoxd token"
    echo ""
    echo "   1. In Developer Tools, go to Application tab"
    echo "   2. Expand Cookies → app.slack.com"
    echo "   3. Find the cookie named 'd' (just the letter d)"
    echo "   4. Double-click and copy the Value (starts with xoxd-)"
    echo ""
    
    wait_for_enter
    
    prompt_secret "Paste your xoxd token" XOXD_TOKEN
    
    if [[ -n "$XOXC_TOKEN" ]]; then
        keychain_store "SLACK_MCP_XOXC_TOKEN" "$XOXC_TOKEN"
    fi
    
    if [[ -n "$XOXD_TOKEN" ]]; then
        keychain_store "SLACK_MCP_XOXD_TOKEN" "$XOXD_TOKEN"
    fi
    
    print_success "Slack MCP configured!"
    print_warning "Note: These tokens expire when you log out of Slack in browser."
}

test_slack() {
    if keychain_exists "SLACK_MCP_XOXC_TOKEN" && keychain_exists "SLACK_MCP_XOXD_TOKEN"; then
        print_success "Slack tokens: configured"
        return 0
    else
        print_error "Slack tokens: missing"
        return 1
    fi
}

# LinkedIn MCP Setup
setup_linkedin() {
    print_header "LinkedIn MCP Setup"
    
    print_info "The LinkedIn MCP requires the li_at cookie from your browser."
    print_warning "This cookie gives access to your LinkedIn account!"
    echo ""
    
    if keychain_exists "LINKEDIN_COOKIE"; then
        print_success "LinkedIn cookie already configured"
        if ! confirm "Reconfigure?"; then
            return 0
        fi
    fi
    
    print_step "Extract li_at cookie"
    echo ""
    echo "   1. Open LinkedIn in an incognito/private browser window"
    echo "   2. Log in to LinkedIn"
    echo "   3. Open Developer Tools (F12 or Cmd+Option+I)"
    echo "   4. Go to Application tab → Cookies → linkedin.com"
    echo "   5. Find 'li_at' cookie"
    echo "   6. Double-click and copy the Value"
    echo ""
    print_warning "Use incognito to avoid session conflicts!"
    echo ""
    
    if confirm "Open LinkedIn in browser?"; then
        open_url "https://www.linkedin.com/"
    fi
    
    wait_for_enter
    
    prompt_secret "Paste your li_at cookie value" LI_AT_COOKIE
    
    if [[ -n "$LI_AT_COOKIE" ]]; then
        keychain_store "LINKEDIN_COOKIE" "$LI_AT_COOKIE"
        print_success "LinkedIn MCP configured!"
    else
        print_error "No cookie provided"
        return 1
    fi
}

test_linkedin() {
    if keychain_exists "LINKEDIN_COOKIE"; then
        print_success "LinkedIn cookie: configured"
        return 0
    else
        print_error "LinkedIn cookie: missing"
        return 1
    fi
}

# Railway MCP Setup
setup_railway() {
    print_header "Railway MCP Setup"
    
    print_info "The Railway MCP uses the Railway CLI for authentication."
    print_info "No API token needed - just authenticate via CLI."
    echo ""
    
    # Check if Railway CLI is installed
    if ! command -v railway &>/dev/null; then
        print_warning "Railway CLI not installed"
        if confirm "Install Railway CLI?"; then
            brew install railway
        else
            print_error "Railway CLI required"
            return 1
        fi
    fi
    
    # Check if already authenticated
    if railway whoami &>/dev/null 2>&1; then
        local user
        user=$(railway whoami 2>/dev/null)
        print_success "Already authenticated as: $user"
        if ! confirm "Re-authenticate?"; then
            return 0
        fi
    fi
    
    print_step "Authenticate with Railway"
    echo ""
    echo "   This will open a browser window for authentication."
    echo ""
    
    if confirm "Start Railway login?"; then
        railway login
    fi
    
    # Verify
    if railway whoami &>/dev/null 2>&1; then
        print_success "Railway MCP configured!"
    else
        print_error "Railway authentication failed"
        return 1
    fi
}

test_railway() {
    if command -v railway &>/dev/null && railway whoami &>/dev/null 2>&1; then
        local user
        user=$(railway whoami 2>/dev/null)
        print_success "Railway: authenticated as $user"
        return 0
    else
        print_error "Railway: not authenticated"
        return 1
    fi
}

# Playwright MCP Setup
setup_playwright() {
    print_header "Playwright MCP Setup"
    
    print_info "Playwright MCP can connect to your existing Chrome browser."
    print_info "This requires the Playwright MCP Bridge extension."
    echo ""
    
    print_step "Step 1: Install Chrome Extension"
    echo ""
    echo "   1. Download the extension from GitHub Releases:"
    echo "      https://github.com/microsoft/playwright-mcp/releases"
    echo "   2. Open chrome://extensions/"
    echo "   3. Enable 'Developer mode' (top right toggle)"
    echo "   4. Click 'Load unpacked' and select the extension folder"
    echo ""
    
    if confirm "Open Playwright MCP releases page?"; then
        open_url "https://github.com/microsoft/playwright-mcp/releases"
    fi
    
    wait_for_enter
    
    if confirm "Open Chrome extensions page?"; then
        open_url "chrome://extensions/"
    fi
    
    wait_for_enter
    
    print_step "Step 2: Get Extension Token (Optional)"
    echo ""
    echo "   For automatic connection without approval each time:"
    echo "   1. Click the extension icon in Chrome toolbar"
    echo "   2. Copy the PLAYWRIGHT_MCP_EXTENSION_TOKEN"
    echo ""
    
    if confirm "Configure extension token?"; then
        prompt_secret "Paste extension token (or press Enter to skip)" PW_TOKEN
        
        if [[ -n "$PW_TOKEN" ]]; then
            keychain_store "PLAYWRIGHT_MCP_EXTENSION_TOKEN" "$PW_TOKEN"
        fi
    fi
    
    print_success "Playwright MCP configured!"
    print_info "The extension mode will ask you to select a tab on first use."
}

test_playwright() {
    print_success "Playwright: Extension mode configured"
    print_info "Full test requires browser interaction"
    return 0
}

# Peekaboo MCP Setup
setup_peekaboo() {
    print_header "Peekaboo MCP Setup (macOS)"
    
    print_info "Peekaboo provides macOS screen capture and GUI automation."
    print_info "Requires: macOS 15+ and system permissions."
    echo ""
    
    # Check macOS version
    local macos_version
    macos_version=$(sw_vers -productVersion)
    local major_version
    major_version=$(echo "$macos_version" | cut -d. -f1)
    
    if [[ "$major_version" -lt 15 ]]; then
        print_error "macOS 15+ required (you have $macos_version)"
        return 1
    fi
    
    print_success "macOS version: $macos_version"
    
    print_step "Step 1: Grant Screen Recording Permission"
    echo ""
    echo "   1. Open System Settings → Privacy & Security → Screen & System Audio Recording"
    echo "   2. Enable access for:"
    echo "      • Terminal (if running from Terminal)"
    echo "      • Your IDE (Cursor, VS Code, etc.)"
    echo "      • Claude Desktop (if applicable)"
    echo ""
    
    if confirm "Open Screen Recording settings?"; then
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    fi
    
    wait_for_enter
    
    print_step "Step 2: Grant Accessibility Permission"
    echo ""
    echo "   1. Open System Settings → Privacy & Security → Accessibility"
    echo "   2. Enable the same applications"
    echo ""
    
    if confirm "Open Accessibility settings?"; then
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    fi
    
    wait_for_enter
    
    # Optional: AI Provider Configuration
    if confirm "Configure AI providers for image analysis? (optional)"; then
        echo ""
        echo "   Peekaboo can use AI to analyze screenshots."
        echo "   Supported: OpenAI, Anthropic, xAI/Grok, Google, Ollama"
        echo ""
        
        prompt_value "AI Providers (e.g., 'openai/gpt-4o,anthropic/claude-sonnet-4')" AI_PROVIDERS ""
        
        if [[ -n "$AI_PROVIDERS" ]]; then
            keychain_store "PEEKABOO_AI_PROVIDERS" "$AI_PROVIDERS"
        fi
        
        if confirm "Configure OpenAI API key?"; then
            prompt_secret "OpenAI API Key (sk-...)" OPENAI_KEY
            if [[ -n "$OPENAI_KEY" ]]; then
                keychain_store "OPENAI_API_KEY" "$OPENAI_KEY"
            fi
        fi
        
        if confirm "Configure Anthropic API key?"; then
            prompt_secret "Anthropic API Key (sk-ant-...)" ANTHROPIC_KEY
            if [[ -n "$ANTHROPIC_KEY" ]]; then
                keychain_store "ANTHROPIC_API_KEY" "$ANTHROPIC_KEY"
            fi
        fi
    fi
    
    print_success "Peekaboo MCP configured!"
    print_info "Test with: peekaboo permissions check"
}

test_peekaboo() {
    if command -v peekaboo &>/dev/null; then
        peekaboo permissions check 2>/dev/null && return 0
    fi
    
    # Try via npx
    print_info "Testing Peekaboo permissions..."
    npx -y @steipete/peekaboo peekaboo permissions check 2>/dev/null && return 0
    
    print_warning "Peekaboo permissions may need configuration"
    return 1
}

# GDP MCP Setup
setup_gdp() {
    print_header "GDP (Grubhub Data Platform) MCP Setup"
    
    print_info "The GDP MCP connects to Grubhub's internal data warehouse."
    print_info "Requires Okta credentials and Redash API key."
    echo ""
    
    if keychain_exists "GDP_PRESTO_USER" && keychain_exists "GDP_PRESTO_PASSWORD"; then
        print_success "GDP credentials already configured"
        if ! confirm "Reconfigure?"; then
            return 0
        fi
    fi
    
    print_step "Step 1: Okta Credentials"
    echo ""
    echo "   Enter your Okta username and password."
    echo "   These are used to authenticate with Presto."
    echo ""
    
    prompt_value "Okta username (email)" OKTA_USER
    prompt_secret "Okta password" OKTA_PASS
    
    if [[ -n "$OKTA_USER" ]]; then
        keychain_store "GDP_PRESTO_USER" "$OKTA_USER"
    fi
    
    if [[ -n "$OKTA_PASS" ]]; then
        keychain_store "GDP_PRESTO_PASSWORD" "$OKTA_PASS"
    fi
    
    print_step "Step 2: Redash API Key"
    echo ""
    echo "   1. Go to Redash → Profile → API Key"
    echo "   2. Copy your API key"
    echo ""
    
    if confirm "Open Redash?"; then
        open_url "https://redash.gdp.data.grubhub.com/users/me"
    fi
    
    wait_for_enter
    
    prompt_secret "Redash API Key" REDASH_KEY
    
    if [[ -n "$REDASH_KEY" ]]; then
        keychain_store "REDASH_API_KEY" "$REDASH_KEY"
    fi
    
    print_success "GDP MCP configured!"
}

test_gdp() {
    local success=true
    
    if keychain_exists "GDP_PRESTO_USER"; then
        print_success "GDP Presto user: configured"
    else
        print_error "GDP Presto user: missing"
        success=false
    fi
    
    if keychain_exists "GDP_PRESTO_PASSWORD"; then
        print_success "GDP Presto password: configured"
    else
        print_error "GDP Presto password: missing"
        success=false
    fi
    
    if keychain_exists "REDASH_API_KEY"; then
        print_success "Redash API key: configured"
    else
        print_warning "Redash API key: missing (optional)"
    fi
    
    $success
}

# ============================================================================
# Test All MCPs
# ============================================================================

test_all_mcps() {
    print_header "Testing All MCP Configurations"
    
    local total=0
    local passed=0
    
    echo ""
    print_step "GitHub MCP"
    ((total++))
    if test_github; then ((passed++)); fi
    
    echo ""
    print_step "Atlassian MCP"
    ((total++))
    if test_atlassian; then ((passed++)); fi
    
    echo ""
    print_step "Google Workspace MCP"
    ((total++))
    if test_google_workspace; then ((passed++)); fi
    
    echo ""
    print_step "Slack MCP"
    ((total++))
    if test_slack; then ((passed++)); fi
    
    echo ""
    print_step "LinkedIn MCP"
    ((total++))
    if test_linkedin; then ((passed++)); fi
    
    echo ""
    print_step "Railway MCP"
    ((total++))
    if test_railway; then ((passed++)); fi
    
    echo ""
    print_step "Playwright MCP"
    ((total++))
    if test_playwright; then ((passed++)); fi
    
    echo ""
    print_step "Peekaboo MCP"
    ((total++))
    if test_peekaboo; then ((passed++)); fi
    
    echo ""
    print_step "GDP MCP"
    ((total++))
    if test_gdp; then ((passed++)); fi
    
    echo ""
    print_header "Test Summary"
    echo ""
    if [[ $passed -eq $total ]]; then
        print_success "All $total MCPs configured!"
    else
        print_info "$passed of $total MCPs configured"
    fi
}

# ============================================================================
# Interactive Menu
# ============================================================================

show_menu() {
    print_header "MCP Setup Wizard"
    
    echo "  Select which MCP to configure:"
    echo ""
    echo "  ${CYAN}1)${NC} GitHub          - Repository management, issues, PRs"
    echo "  ${CYAN}2)${NC} Atlassian       - Jira issues, Confluence pages"
    echo "  ${CYAN}3)${NC} Google Workspace- Gmail, Calendar, Drive, Docs, Sheets"
    echo "  ${CYAN}4)${NC} Slack           - Messages, channels, search"
    echo "  ${CYAN}5)${NC} LinkedIn        - Profiles, companies, jobs"
    echo "  ${CYAN}6)${NC} Railway         - Deploy services, manage environments"
    echo "  ${CYAN}7)${NC} Playwright      - Browser automation"
    echo "  ${CYAN}8)${NC} Peekaboo        - macOS screen capture & GUI automation"
    echo "  ${CYAN}9)${NC} GDP             - Grubhub Data Platform queries"
    echo ""
    echo "  ${CYAN}a)${NC} Setup ALL MCPs"
    echo "  ${CYAN}t)${NC} Test all configurations"
    echo "  ${CYAN}m)${NC} Migrate from 1Password to Keychain"
    echo "  ${CYAN}d)${NC} Check dependencies"
    echo "  ${CYAN}q)${NC} Quit"
    echo ""
    
    read -r -p "$(echo -e "${CYAN}?${NC} Enter selection: ")" choice
    
    case "$choice" in
        1) setup_github ;;
        2) setup_atlassian ;;
        3) setup_google_workspace ;;
        4) setup_slack ;;
        5) setup_linkedin ;;
        6) setup_railway ;;
        7) setup_playwright ;;
        8) setup_peekaboo ;;
        9) setup_gdp ;;
        a|A) 
            setup_github
            setup_atlassian
            setup_google_workspace
            setup_slack
            setup_linkedin
            setup_railway
            setup_playwright
            setup_peekaboo
            setup_gdp
            ;;
        t|T) test_all_mcps ;;
        m|M) migrate_from_1password ;;
        d|D) check_dependencies ;;
        q|Q) exit 0 ;;
        *) print_error "Invalid selection" ;;
    esac
    
    echo ""
    if confirm "Return to menu?" "y"; then
        show_menu
    fi
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              OpenCode MCP Setup Wizard v1.0                      ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    case "${1:-}" in
        --test|-t)
            test_all_mcps
            ;;
        --migrate|-m)
            migrate_from_1password
            ;;
        --deps|-d)
            check_dependencies
            ;;
        --help|-h)
            echo "Usage: $0 [options] [mcp-name]"
            echo ""
            echo "Options:"
            echo "  --test, -t      Test all MCP configurations"
            echo "  --migrate, -m   Migrate credentials from 1Password to Keychain"
            echo "  --deps, -d      Check and install dependencies"
            echo "  --help, -h      Show this help"
            echo ""
            echo "MCP names: github, atlassian, google, slack, linkedin, railway, playwright, peekaboo, gdp"
            echo ""
            echo "Examples:"
            echo "  $0              # Interactive menu"
            echo "  $0 github       # Setup GitHub MCP only"
            echo "  $0 --test       # Test all MCPs"
            ;;
        github) setup_github ;;
        atlassian) setup_atlassian ;;
        google|google-workspace) setup_google_workspace ;;
        slack) setup_slack ;;
        linkedin) setup_linkedin ;;
        railway) setup_railway ;;
        playwright) setup_playwright ;;
        peekaboo) setup_peekaboo ;;
        gdp) setup_gdp ;;
        "")
            check_dependencies
            show_menu
            ;;
        *)
            print_error "Unknown option or MCP: $1"
            echo "Run '$0 --help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
