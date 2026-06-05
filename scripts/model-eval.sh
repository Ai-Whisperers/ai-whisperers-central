#!/bin/bash
set -euo pipefail

echo "=== Model Evaluation ==="
echo "Date: $(date)"
echo ""

KEY="sk-hermes-litellm-sunstein-2026"
URL="http://127.0.0.1:4000/v1/chat/completions"

evaluate_model() {
    local tier="$1"
    local prompt="$2"
    local start=$(date +%s%N)
    
    result=$(curl -s --max-time 30 "$URL" \
        -H "Authorization: Bearer $KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$tier\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}],\"max_tokens\":20}" 2>&1)
    
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    
    if echo "$result" | grep -q '"choices"'; then
        local model=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('model','?'))" 2>/dev/null || echo "?")
        local tokens=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); u=d.get('usage',{}); print(f\"in={u.get('prompt_tokens',0)} out={u.get('completion_tokens',0)}\")" 2>/dev/null || echo "?")
        echo "  OK  $tier -> $model | ${ms}ms | $tokens"
    else
        local err=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('error',{}).get('message','unknown')[:80])" 2>/dev/null || echo "${result:0:80}")
        echo "  ERR $tier | ${ms}ms | $err"
    fi
}

echo "--- Fast Tier ---"
evaluate_model "fast" "Say hello in 5 words"
evaluate_model "fast" "What is 2+2?"

echo ""
echo "--- Primary Tier ---"
evaluate_model "primary" "Explain quantum computing briefly"
evaluate_model "primary" "Write a haiku about AI"

echo ""
echo "--- Reasoning Tier ---"
evaluate_model "reasoning" "What is 15*37? Show your work."

echo ""
echo "=== Evaluation Complete ==="
