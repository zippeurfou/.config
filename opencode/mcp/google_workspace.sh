#!/bin/bash

export GOOGLE_OAUTH_CLIENT_ID=$(op read "op://Employee/GOOGLE_OAUTH_CLIENT_ID/credential")
export GOOGLE_OAUTH_CLIENT_SECRET=$(op read "op://Employee/GOOGLE_OAUTH_CLIENT_SECRET/credential")
export OAUTHLIB_INSECURE_TRANSPORT=$(op read "op://Employee/OAUTHLIB_INSECURE_TRANSPORT/credential")
export USER_GOOGLE_EMAIL="mferradou@grubhub.com"
export GOOGLE_PSE_ENGINE_ID=$(op read "op://Employee/GOOGLE_PSE_ENGINE_ID/credential")
export GOOGLE_PSE_API_KEY=$(op read "op://Employee/GOOGLE_PSE_API_KEY/credential")

uvx workspace-mcp
