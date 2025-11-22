#!/bin/bash

export NEO4J_PASSWORD="my_fake_password_that_is_so_secure"
export NEO4J_CONTAINER="my-neo4j"

# Create and start Neo4j if the container doesn't exist
if ! docker ps -a --format '{{.Names}}' | grep -q "^$NEO4J_CONTAINER$"; then
  echo "Creating Neo4j container..."
  docker run -d \
    --name "$NEO4J_CONTAINER" \
    -p 7474:7474 -p 7687:7687 \
    -v "$HOME/neo4j/data:/data" \
    -v "$HOME/neo4j/logs:/logs" \
    -v "$HOME/neo4j/import:/import" \
    -v "$HOME/neo4j/plugins:/plugins" \
    -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
    -e NEO4J_AUTH="neo4j/$NEO4J_PASSWORD" \
    -e NEO4J_PLUGINS='[ "genai","graph-data-science" ]' \
    neo4j:2025.06.2
  sleep 15
elif ! docker ps --format '{{.Names}}' | grep -q "^$NEO4J_CONTAINER$"; then
  echo "Starting existing Neo4j container..."
  docker start "$NEO4J_CONTAINER"
else
  echo "Neo4j is already running."
fi

# Run MCP server with uvx
uvx mcp-neo4j-memory \
  --db-url bolt://localhost:7687 \
  --username neo4j \
  --password "$NEO4J_PASSWORD"

