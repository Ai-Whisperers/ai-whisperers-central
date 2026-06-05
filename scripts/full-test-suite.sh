#!/bin/bash
# AI Whisperers Full Test Suite
# Usage: bash full-test-suite.sh [--layer 1-3] [--verbose]

set -euo pipefail

PASS=0
FAIL=0
WARN=0
TOTAL=0

LAYER=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --layer) LAYER="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    *) shift ;;
  esac
done

log_pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  PASS: $1"; }
log_fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  FAIL: $1"; }
log_warn() { WARN=$((WARN+1)); TOTAL=$((TOTAL+1)); echo "  WARN: $1"; }

# --- LAYER 1: Infrastructure ---
if [ -z "$LAYER" ] || [ "$LAYER" = "1" ]; then
echo "=== LAYER 1: Infrastructure ==="

# 1.1 Swarm services
down=$(docker service ls --format '{{.Name}}: {{.Replicas}}' | grep -v '1/1' || true)
[ -z "$down" ] && log_pass "All swarm services 1/1" || log_fail "Services not 1/1: $down"

# 1.2 Critical containers
for c in n8n_n8n postgres_postgres litellm litellm-redis evolution_evolution_api \
         aiw-context-api aiw-stt aiw-vision aiw-tts searxng prometheus grafana; do
  status=$(docker ps --filter "name=$c" --format '{{.Status}}' 2>/dev/null)
  [ -n "$status" ] && echo "$status" | grep -q "Up" && log_pass "$c running" || log_fail "$c MISSING/DOWN"
done

# 1.3 Network
docker network inspect aiw-infra-net --format '{{.Name}}' 2>/dev/null | grep -q 'aiw-infra-net' \
  && log_pass "aiw-infra-net exists" || log_fail "aiw-infra-net missing"

# 1.4 Resources
disk_pct=$(df / --output=pcent | tail -1 | tr -d ' %')
[ "$disk_pct" -lt 80 ] && log_pass "Disk at ${disk_pct}%" || log_warn "Disk at ${disk_pct}%"

ram_avail=$(free -g | grep Mem | awk '{print $7}')
[ "$ram_avail" -ge 4 ] && log_pass "RAM available: ${ram_avail}GB" || log_warn "RAM low: ${ram_avail}GB"

# 1.5 PostgreSQL
PGC=$(docker ps -q --filter "name=postgres_postgres" | head -1)
docker exec "$PGC" psql -U n8n -d n8n -c "SELECT 1" -t -A >/dev/null 2>&1 \
  && log_pass "PostgreSQL n8n DB" || log_fail "PostgreSQL n8n DB"
docker exec "$PGC" psql -U litellm -d litellm -c "SELECT 1" -t -A >/dev/null 2>&1 \
  && log_pass "PostgreSQL litellm DB" || log_fail "PostgreSQL litellm DB"

# 1.6 Redis
docker exec litellm-redis redis-cli PING 2>&1 | grep -q PONG \
  && log_pass "Redis PING" || log_fail "Redis PING"
kb_count=$(docker exec litellm-redis redis-cli -n 2 DBSIZE 2>&1 | grep -o '[0-9]*')
[ "${kb_count:-0}" -ge 24 ] && log_pass "KB has ${kb_count:-0} entries" || log_warn "KB has ${kb_count:-0} entries (expected >=24)"
fi

# --- LAYER 2: Service Health ---
if [ -z "$LAYER" ] || [ "$LAYER" = "2" ]; then
echo ""
echo "=== LAYER 2: Service Health ==="

# 2.1 Context API
ctx_health=$(docker exec aiw-context-api python3 -c "
import urllib.request, json
r = urllib.request.urlopen('http://127.0.0.1:3100/health', timeout=5)
print(json.loads(r.read())['status'])
" 2>/dev/null)
[ "$ctx_health" = "ok" ] && log_pass "Context API health" || log_fail "Context API health: $ctx_health"

# 2.2 STT
stt_health=$(docker exec aiw-context-api python3 -c "
import urllib.request, json
r = urllib.request.urlopen('http://aiw-stt:3300/health', timeout=5)
print(json.loads(r.read())['status'])
" 2>/dev/null)
[ "$stt_health" = "ok" ] && log_pass "STT health" || log_fail "STT health: $stt_health"

# 2.3 Vision
vis_health=$(docker exec aiw-context-api python3 -c "
import urllib.request, json
r = urllib.request.urlopen('http://aiw-vision:3400/health', timeout=5)
print(json.loads(r.read())['status'])
" 2>/dev/null)
[ "$vis_health" = "ok" ] && log_pass "Vision health" || log_fail "Vision health: $vis_health"

# 2.4 TTS
tts_health=$(docker exec aiw-context-api python3 -c "
import urllib.request, json
r = urllib.request.urlopen('http://aiw-tts:3500/health', timeout=5)
print(json.loads(r.read())['status'])
" 2>/dev/null)
[ "$tts_health" = "ok" ] && log_pass "TTS health" || log_fail "TTS health: $tts_health"

# 2.5 SearXNG
searx_results=$(docker exec aiw-context-api python3 -c "
import urllib.request, json
r = urllib.request.urlopen('http://searxng:8080/search?q=test&format=json', timeout=20)
print(len(json.loads(r.read()).get('results', [])))
" 2>/dev/null)
[ "${searx_results:-0}" -gt 0 ] 2>/dev/null && log_pass "SearXNG ($searx_results results)" || log_warn "SearXNG: ${searx_results:-0} results"

# 2.6 LiteLLM all tiers
all_tiers_ok=true
failed_tier=""
for tier in fast primary reasoning vision; do
  ok=$(docker exec aiw-context-api python3 -c "
import urllib.request, json
req = urllib.request.Request('http://litellm:4000/v1/chat/completions',
    data=json.dumps({'model': '$tier', 'messages': [{'role': 'user', 'content': 'OK'}], 'max_tokens': 3}).encode(),
    headers={'Authorization': 'Bearer sk-hermes-litellm-sunstein-2026', 'Content-Type': 'application/json'})
r = urllib.request.urlopen(req, timeout=30)
d = json.loads(r.read())
print('ok' if d.get('choices',[{}])[0].get('message',{}).get('content','') else 'fail')
" 2>/dev/null)
  if [ "$ok" != "ok" ]; then
    all_tiers_ok=false
    failed_tier="$tier"
    break
  fi
done
$all_tiers_ok && log_pass "LiteLLM all tiers" || log_fail "LiteLLM tier $failed_tier failed"

# 2.7 Evolution
evo_status=$(curl -sk --max-time 10 'https://evolution.sunstein.cloud/instance/fetchInstances' \
  -H 'apikey: a53c00ff3726d2ced6bbfeba8d1a1e90' 2>/dev/null | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
print(data[0].get('connectionStatus','?') if data else '?')
" 2>/dev/null)
[ "$evo_status" = "open" ] && log_pass "Evolution API (open)" || log_fail "Evolution API ($evo_status)"
fi

# --- LAYER 3: Pipeline ---
if [ -z "$LAYER" ] || [ "$LAYER" = "3" ]; then
echo ""
echo "=== LAYER 3: Pipeline Quick Test ==="

PGC=$(docker ps -q --filter "name=postgres_postgres" | head -1)

# Send a test message and check execution
test_id="health_$(date +%s)"
curl -sk --max-time 10 -X POST "https://n8n.sunstein.cloud/webhook/whatsapp-incoming" \
  -H "Content-Type: application/json" \
  -d "{\"data\":{\"key\":{\"remoteJid\":\"595981324569@s.whatsapp.net\",\"fromMe\":false,\"id\":\"$test_id\"},\"message\":{\"conversation\":\"ping test\"},\"pushName\":\"HealthCheck\"}}" >/dev/null 2>&1

sleep 20
last_exec=$(docker exec "$PGC" psql -U n8n -d n8n -t -A -c "SELECT status FROM execution_entity ORDER BY \"createdAt\" DESC LIMIT 1" 2>/dev/null | tr -d ' ')
[ "$last_exec" = "success" ] && log_pass "Pipeline execution (latest)" || log_fail "Pipeline execution: $last_exec"
fi

# --- SUMMARY ---
echo ""
echo "=============================="
echo "RESULTS: $PASS PASS | $FAIL FAIL | $WARN WARN | $TOTAL TOTAL"
echo "=============================="

# Send WhatsApp alert on failure
if [ "$FAIL" -gt 0 ]; then
  ALERT_MSG="[NYX HEALTH ALERT] $FAIL failures detected at $(date '+%Y-%m-%d %H:%M:%S')"
  ALERT_MSG="$ALERT_MSG
Pass: $PASS | Fail: $FAIL | Warn: $WARN | Total: $TOTAL"
  /opt/aiw-infra/scripts/send-whatsapp-alert.sh "$ALERT_MSG" 2>/dev/null || true
fi

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
