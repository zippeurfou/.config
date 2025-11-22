#!/usr/bin/env bash
set -euo pipefail
export LINKEDIN_COOKIE=$(op read "op://Employee/LINKEDIN_COOKIE/credential")
# docker run --rm -i \
#         -e LINKEDIN_COOKIE="$LINKEDIN_COOKIE" \
#         stickerdaniel/linkedin-mcp-server:latest
#

# Navigate to project directory
cd "/Users/mferradou/Projects/linkedin-mcp-server"

# Activate Python environment
if [ -f ".python-version" ]; then
  # assuming pyenv; adapt if using another version manager
  eval "$(pyenv init -)"
  pyenv shell "$(cat .python-version)"
else
  echo "Warning: .python-version not found—making sure uv venv exists"
fi

# Ensure uv virtual environment exists
if [ ! -d ".venv" ]; then
  echo "Creating uv venv..."
  uv venv
fi
uv sync --reinstall
uv sync --dev
# Activate uv venv
source .venv/bin/activate

# Install editable (in case not installed);
# if already done, this is no-op
# uv add -e .

# Export optional Semantic Scholar API key if you have one
# export SEMANTIC_SCHOLAR_API_KEY="${SEMANTIC_SCHOLAR_API_KEY:-}"


# Launch the MCP server
uv run main.py \
  --cookie "$LINKEDIN_COOKIE" \
  --no-lazy-init  \
  --transport stdio


