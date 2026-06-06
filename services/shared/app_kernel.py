import json
import os
import time
import redis
import urllib.request
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

REDIS_HOST = os.environ.get("REDIS_HOST", "litellm-redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
CONTEXT_DB = int(os.environ.get("REDIS_DB", 1))
KNOWLEDGE_DB = int(os.environ.get("KNOWLEDGE_DB", 2))
ANALYTICS_DB = int(os.environ.get("ANALYTICS_DB", 3))
SEARXNG_URL = os.environ.get("SEARXNG_URL", "http://searxng:8080")
EVO_URL = os.environ.get("EVO_URL", "https://evolution.sunstein.cloud")
EVO_KEY = os.environ.get("EVO_KEY", "a53c00ff3726d2ced6bbfeba8d1a1e90")
EVO_INSTANCE = os.environ.get("EVO_INSTANCE", "hermes-whatsapp")
ALERT_NUMBER = os.environ.get("ALERT_NUMBER", "595981324569")
CONTEXT_PREFIX = "nyx:ctx:"
META_PREFIX = "nyx:meta:"
MAX_MESSAGES = int(os.environ.get("MAX_MESSAGES", 20))
TTL_SECONDS = int(os.environ.get("TTL_SECONDS", 86400))
MAX_TOKENS_ESTIMATE = int(os.environ.get("MAX_TOKENS_ESTIMATE", 3000))

r_ctx = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=CONTEXT_DB, decode_responses=True)
r_kb = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=KNOWLEDGE_DB, decode_responses=True)
r_an = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=ANALYTICS_DB, decode_responses=True)

def estimate_tokens(messages):
    return sum(len(m.get("content", "")) // 4 + 10 for m in messages)

def trim_messages(messages, max_tokens):
    while estimate_tokens(messages) > max_tokens and len(messages) > 2:
        messages.pop(0)
    return messages

def lookup_knowledge(text):
    text_lower = text.lower()
    results = []
    for key in r_kb.keys("kb:*"):
        try:
            data = json.loads(r_kb.get(key))
            kws = data.get("keywords", [key.split(":")[-1]])
            if any(kw in text_lower for kw in kws):
                results.append(data.get("text", ""))
        except:
            pass
    return results

def web_search(query, max_results=5):
    try:
        params = urllib.parse.urlencode({"q": query, "format": "json", "language": "auto"})
        url = f"{SEARXNG_URL}/search?{params}"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read())
        results = []
        for r in data.get("results", [])[:max_results]:
            results.append({
                "title": r.get("title", ""),
                "url": r.get("url", ""),
                "snippet": r.get("content", ""),
                "engine": r.get("engine", ""),
            })
        return results
    except Exception as e:
        return [{"error": str(e)}]

def send_whatsapp(text):
    try:
        url = f"{EVO_URL}/message/sendText/{EVO_INSTANCE}"
        payload = json.dumps({"number": ALERT_NUMBER, "text": text}).encode()
        req = urllib.request.Request(url, data=payload,
            headers={"Content-Type": "application/json", "apikey": EVO_KEY})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status in (200, 201)
    except Exception as e:
        print(f"WhatsApp alert failed: {e}")
        return False

def track_analytics(event_type, data):
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        hour = datetime.now().strftime("%H")
        pipe = r_an.pipeline()
        pipe.hincrby(f"an:daily:{today}", "total_messages", 1)
        pipe.hincrby(f"an:hourly:{today}:{hour}", "messages", 1)
        if event_type == "message":
            agent = data.get("agent", "general")
            tier = data.get("tier", "fast")
            sender = data.get("sender", "unknown")
            is_group = data.get("isGroup", False)
            pipe.hincrby(f"an:daily:{today}", f"agent_{agent}", 1)
            pipe.hincrby(f"an:daily:{today}", f"tier_{tier}", 1)
            pipe.hincrby(f"an:daily:{today}", "group_messages" if is_group else "dm_messages", 1)
            pipe.hincrby(f"an:user:{sender}", "messages", 1)
            pipe.hincrby(f"an:user:{sender}", f"agent_{agent}", 1)
            pipe.hset(f"an:user:{sender}", "lastSeen", datetime.now().isoformat())
            if data.get("senderName"):
                pipe.hset(f"an:user:{sender}", "name", data["senderName"])
        elif event_type == "web_search":
            pipe.hincrby(f"an:daily:{today}", "web_searches", 1)
        elif event_type == "kb_hit":
            pipe.hincrby(f"an:daily:{today}", "kb_hits", 1)
        pipe.execute()
    except Exception:
        pass

def get_prometheus_metrics():
    lines = []
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        daily = r_an.hgetall(f"an:daily:{today}")
        total = int(daily.get("total_messages", 0))
        lines.append("# HELP nyx_messages_total Total messages processed today")
        lines.append("# TYPE nyx_messages_total counter")
        lines.append(f'nyx_messages_total{{date="{today}"}} {total}')
        for key in sorted(daily.keys()):
            if key.startswith("agent_"):
                agent = key.replace("agent_", "")
                lines.append(f'nyx_agent_usage{{agent="{agent}",date="{today}"}} {daily[key]}')
            elif key.startswith("tier_"):
                tier = key.replace("tier_", "")
                lines.append(f'nyx_tier_usage{{tier="{tier}",date="{today}"}} {daily[key]}')
        lines.append(f'nyx_dm_messages{{date="{today}"}} {daily.get("dm_messages",0)}')
        lines.append(f'nyx_group_messages{{date="{today}"}} {daily.get("group_messages",0)}')
        lines.append(f'nyx_web_searches{{date="{today}"}} {daily.get("web_searches",0)}')
        lines.append(f'nyx_kb_hits{{date="{today}"}} {daily.get("kb_hits",0)}')
        user_count = len([k for k in r_an.keys("an:user:*") if r_an.hexists(k, "messages")])
        lines.append(f'nyx_unique_users {user_count}')
        kb_count = len(r_kb.keys("kb:*"))
        ctx_count = len(r_ctx.keys("nyx:ctx:*"))
        lines.append(f'nyx_knowledge_entries {kb_count}')
        lines.append(f'nyx_active_contexts {ctx_count}')
    except Exception as e:
        lines.append(f'# ERROR: {e}')
    return "\n".join(lines) + "\n"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.strip("/")
        if path == "health" or path == "":
            self._json({"status": "ok", "version": "v6"})
            return
        if path == "metrics":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.end_headers()
            self.wfile.write(get_prometheus_metrics().encode())
            return
        if path == "analytics":
            today = datetime.now().strftime("%Y-%m-%d")
            daily = r_an.hgetall(f"an:daily:{today}")
            users = {}
            for key in r_an.keys("an:user:*"):
                uid = key.split(":")[-1]
                udata = r_an.hgetall(key)
                if udata.get("messages"):
                    users[uid] = udata
            self._json({"date": today, "daily": daily, "users": users, "uniqueUsers": len(users)})
            return
        chat_jid = path
        key = f"{CONTEXT_PREFIX}{chat_jid}"
        data = r_ctx.get(key)
        messages = json.loads(data) if data else []
        meta_key = f"{META_PREFIX}{chat_jid}"
        meta = json.loads(r_ctx.get(meta_key) or "{}")
        self._json({"chatJid": chat_jid, "messages": messages, "messageCount": len(messages), "senderName": meta.get("senderName", ""), "lastSeen": meta.get("lastSeen", "")})

    def do_POST(self):
        path = self.path.strip("/")
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}

        if path == "alert":
            status = body.get("status", "unknown")
            title = body.get("title", "Alert")
            state = body.get("state", status)
            alerts = body.get("alerts", [])
            msg_parts = [f"*[NYX ALERT - {state.upper()}]*"]
            msg_parts.append(title)
            for a in alerts[:5]:
                labels = a.get("labels", {})
                astatus = a.get("status", "?")
                aname = labels.get("alertname", "Unknown")
                msg_parts.append(f"- {aname}: {astatus}")
                vals = a.get("values", {})
                for k, v in list(vals.items())[:3]:
                    msg_parts.append(f"  {k}={v}")
            text = "\n".join(msg_parts)
            ok = send_whatsapp(text)
            self._json({"relayed": ok, "alerts": len(alerts), "status": state})
            return

        if path == "lookup":
            query_text = body.get("query", "")
            results = lookup_knowledge(query_text)
            if results:
                track_analytics("kb_hit", {})
            self._json({"results": results, "count": len(results)})
            return

        if path == "search":
            query = body.get("query", "")
            max_results = body.get("maxResults", 5)
            results = web_search(query, max_results)
            track_analytics("web_search", {})
            self._json({"query": query, "results": results, "count": len(results)})
            return

        if path == "hybrid-lookup":
            query_text = body.get("query", "")
            kb_results = lookup_knowledge(query_text)
            web_results = []
            if not kb_results:
                web_results = web_search(query_text, 3)
                if web_results:
                    track_analytics("web_search", {})
            else:
                track_analytics("kb_hit", {})
            self._json({"knowledge": kb_results, "webResults": web_results, "kbCount": len(kb_results), "webCount": len(web_results)})
            return

        if path == "track":
            track_analytics(body.get("event", "message"), body)
            self._json({"tracked": True})
            return

        chat_jid = path
        new_messages = body.get("messages", [])
        sender_name = body.get("senderName", "")
        query_text = body.get("query", "")

        key = f"{CONTEXT_PREFIX}{chat_jid}"
        existing = json.loads(r_ctx.get(key) or "[]")
        all_messages = existing + new_messages
        all_messages = all_messages[-MAX_MESSAGES:]
        all_messages = trim_messages(all_messages, MAX_TOKENS_ESTIMATE)
        r_ctx.setex(key, TTL_SECONDS, json.dumps(all_messages))

        meta_key = f"{META_PREFIX}{chat_jid}"
        meta = json.loads(r_ctx.get(meta_key) or "{}")
        if sender_name:
            meta["senderName"] = sender_name
        meta["lastSeen"] = datetime.now().isoformat()
        meta["messageCount"] = len(all_messages)
        r_ctx.setex(meta_key, TTL_SECONDS, json.dumps(meta))

        knowledge = []
        for m in new_messages:
            if m.get("role") == "user":
                knowledge.extend(lookup_knowledge(m.get("content", "")))

        track_analytics("message", {
            "sender": chat_jid,
            "senderName": sender_name,
            "agent": body.get("agent", "general"),
            "tier": body.get("tier", "fast"),
            "isGroup": body.get("isGroup", False),
        })

        self._json({"chatJid": chat_jid, "totalMessages": len(all_messages), "saved": len(new_messages), "estimatedTokens": estimate_tokens(all_messages), "knowledge": knowledge[:3]})

    def do_DELETE(self):
        chat_jid = self.path.strip("/")
        r_ctx.delete(f"{CONTEXT_PREFIX}{chat_jid}", f"{META_PREFIX}{chat_jid}")
        self._json({"deleted": chat_jid})

    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 3100), Handler)
    print(f"Context API v6 (RAG + Web Search + Analytics + Alert Relay) running on :3100")
    server.serve_forever()
