#!/bin/bash

################################################################################
# Convenience wrapper to run listener with .env file
################################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Load .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "✓ Loaded configuration from .env"
else
    echo "⚠ No .env file found. Copy .env.example to .env and configure it."
    echo ""
    echo "Quick setup:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your webhook URL"
    echo "  ./run.sh"
    exit 1
fi

# Run the listener
exec ./listener.sh

