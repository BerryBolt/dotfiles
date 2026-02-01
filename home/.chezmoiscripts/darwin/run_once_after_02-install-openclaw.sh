#!/bin/bash
# Install OpenClaw

set -e

# Skip if already installed
if command -v openclaw &> /dev/null; then
    echo "OpenClaw already installed, skipping..."
    exit 0
fi

echo "Installing OpenClaw..."

curl -fsSL https://openclaw.ai/install.sh | bash

echo "OpenClaw installed successfully."
