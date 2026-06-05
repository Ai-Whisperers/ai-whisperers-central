#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
PASS=0
FAIL=0

test_case() {
    local name="$1"
    local result="$2"
    local expected="$3"
    
    if echo "$result" | grep -q "$expected"; then
        echo -e "  ${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (expected: $expected, got: ${result:0:100})"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Nyx Pipeline Test Suite ==="
echo "Date: $(date)"
echo ""

# Test 1: LiteLLM health
echo "--- LiteLLM ---"
result=$(docker exec litellm python -c "import urllib.request; r=urllib.request.Request('http://localhost:4000/health'); r.add_header('Authorization','Bearer sk-hermes-litellm-sunstein-2026'); print(urllib.request.urlopen(r).read().decode())" 2>&1)
test_case "LiteLLM health endpoint" "$result" "healthy"

# Test 2: LiteLLM fast model
echo "--- Model Routing ---"
result=$(docker exec litellm python -c "
import urllib.request, json
data = json.dumps({'model':'fast','messages':[{'role':'user','content':'hi'}],'max_tokens':5}).encode()
r = urllib.request.Request('http://localhost:4000/v1/chat/completions', data=data)
r.add_header('Authorization','Bearer sk-hermes-litellm-sunstein-2026')
r.add_header('Content-Type','application/json')
resp = json.loads(urllib.request.urlopen(r, timeout=30).read().decode())
print(json.dumps({'model':resp.get('model',''),'has_choices':'choices' in resp}))
" 2>&1)
test_case "Fast model call" "$result" "has_choices"

# Test 3: LiteLLM primary model
result=$(docker exec litellm python -c "
import urllib.request, json
data = json.dumps({'model':'primary','messages':[{'role':'user','content':'hello'}],'max_tokens':5}).encode()
r = urllib.request.Request('http://localhost:4000/v1/chat/completions', data=data)
r.add_header('Authorization','Bearer sk-hermes-litellm-sunstein-2026')
r.add_header('Content-Type','application/json')
resp = json.loads(urllib.request.urlopen(r, timeout=30).read().decode())
print(json.dumps({'model':resp.get('model',''),'has_choices':'choices' in resp}))
" 2>&1)
test_case "Primary model call" "$result" "has_choices"

# Test 4: Context API
echo "--- Context API ---"
result=$(docker exec aiw-context-api python -c "
import urllib.request, json
r = urllib.request.Request('http://localhost:3100/test@test.com')
resp = json.loads(urllib.request.urlopen(r).read().decode())
print(json.dumps(resp))
" 2>&1)
test_case "Context API GET" "$result" "chatJid"

# Test 5: Context API POST
result=$(docker exec aiw-context-api python -c "
import urllib.request, json
data = json.dumps({'messages':[{'role':'user','content':'test'}]}).encode()
r = urllib.request.Request('http://localhost:3100/test-pipeline@test.com', data=data)
r.add_header('Content-Type','application/json')
resp = json.loads(urllib.request.urlopen(r).read().decode())
print(json.dumps(resp))
" 2>&1)
test_case "Context API POST" "$result" "saved"

# Test 6: n8n webhook accepts
echo "--- n8n Webhook ---"
N8N=$(docker ps -q --filter "name=n8n_n8n" | head -1)
result=$(docker exec $N8N wget -qO- --post-data='{"data":{"key":{"fromMe":false,"remoteJid":"test@s.whatsapp.net","id":"ci-test-001"},"message":{"conversation":"test"},"pushName":"CI"}}' --header='Content-Type: application/json' 'http://localhost:5678/webhook/whatsapp-incoming' 2>&1)
test_case "n8n webhook endpoint" "$result" "started"

# Test 7: Evolution API reachable
echo "--- Evolution API ---"
EVO=$(docker ps -q --filter "name=evolution_evolution_api" | head -1)
result=$(docker exec $EVO wget -qO- --timeout=5 'http://localhost:8080/instance/fetchInstances' --header='apikey: a53c00ff3726d2ced6bbfeba8d1a1e90' 2>&1 | head -50)
test_case "Evolution API fetchInstances" "$result" "instance"

# Test 8: Redis connectivity
echo "--- Redis ---"
result=$(docker exec litellm-redis redis-cli -n 1 DBSIZE 2>&1)
test_case "Redis DB1 accessible" "$result" "" && echo "    (DB has $result keys)"

# Test 9: Prometheus targets
echo "--- Monitoring ---"
result=$(docker exec prometheus wget -qO- http://localhost:9090/api/v1/targets 2>&1)
up_count=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(sum(1 for t in d['data']['activeTargets'] if t['health']=='up'))" 2>/dev/null || echo "0")
test_case "Prometheus targets up (need >=4)" "$up_count" "" && [ "$up_count" -ge 4 ] && echo -e "    ($up_count targets up)"

echo ""
echo "=== Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} ==="
exit $FAIL
