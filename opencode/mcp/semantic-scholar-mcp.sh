#!/usr/bin/env bash
set -euo pipefail

# Navigate to project directory
cd "/Users/mferradou/Projects/semantic-scholar-fastmcp-mcp-server"

uvx fastmcp run run.py
