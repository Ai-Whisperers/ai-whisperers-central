#!/bin/bash
# Send WhatsApp alert via Evolution API
# Usage: send-whatsapp-alert.sh "message"
MSG="$1"
NUMBER="595981324569"
EVO_URL="https://evolution.sunstein.cloud/message/sendText/hermes-whatsapp"
EVO_KEY="a53c00ff3726d2ced6bbfeba8d1a1e90"
curl -sk --max-time 10 -X POST "$EVO_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: $EVO_KEY" \
  -d "{\"number\":\"$NUMBER\",\"text\":$(echo "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')}" >/dev/null 2>&1
