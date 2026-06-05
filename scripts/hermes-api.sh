#!/bin/bash
# Hermes Agent API wrapper - runs a query and returns the text response
QUERY="$1"
export PATH="$HOME/.local/bin:$PATH"
cd /root/.hermes/hermes-agent
source venv/bin/activate
hermes chat -q "$QUERY" 2>/dev/null | sed -n '/^╭─ ⚕ Hermes/,/^╰─/p' | sed '1d;$d' | sed 's/^│//'
