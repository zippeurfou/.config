#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/keychain-helper.sh"

export LINKEDIN_COOKIE=$(get_credential "LINKEDIN_COOKIE" "op://Employee/LINKEDIN_COOKIE/credential")

cd "/Users/mferradou/Projects/linkedin-mcp-server"

if [ -f ".python-version" ]; then
  eval "$(pyenv init -)"
  pyenv shell "$(cat .python-version)"
else
  echo "Warning: .python-version not found—making sure uv venv exists" >&2
fi

if [ ! -d ".venv" ]; then
  echo "Creating uv venv..." >&2
  uv venv
fi
uv sync --reinstall
uv sync --dev
source .venv/bin/activate

uv run main.py \
  --cookie "$LINKEDIN_COOKIE" \
  --no-lazy-init \
  --transport stdio
