#!/bin/bash
# Load environment variables from .env.local file permanently
# This will be sourced from ~/.zshrc to load on every shell startup

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.local"

if [ -f "$ENV_FILE" ]; then
    # Read and export variables safely
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^#.* ]] && continue
        # Remove quotes if present
        value="${value%\"}"
        value="${value#\"}"
        export "$key=$value"
    done < "$ENV_FILE"
else
    echo "⚠ Warning: $ENV_FILE not found"
    echo "Copy .env.local.example to .env.local and add your tokens"
fi
