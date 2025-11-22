#!/bin/bash
docker run -i --rm \
  --platform linux/amd64 \
  -v "$PWD:/app" \
  sylphlab/pdf-reader-mcp:latest