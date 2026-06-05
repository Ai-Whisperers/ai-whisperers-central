import json
import os
import base64
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

LITELLM_URL = os.environ.get("LITELLM_URL", "http://litellm:4000")
LITELLM_KEY = os.environ.get("LITELLM_KEY", "sk-hermes-litellm-sunstein-2026")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        image_url = body.get("imageUrl", "")
        image_base64 = body.get("imageBase64", "")
        prompt = body.get("prompt", "Describe this image briefly in the language it appears to be from.")
        
        if not image_url and not image_base64:
            self._json({"error": "missing imageUrl or imageBase64"}, 400)
            return
        
        try:
            content = []
            content.append({"type": "text", "text": prompt})
            
            if image_url:
                content.append({"type": "image_url", "image_url": {"url": image_url}})
            else:
                content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}})
            
            payload = {
                "model": "vision",
                "messages": [{"role": "user", "content": content}],
                "max_tokens": 200,
                "temperature": 0.3
            }
            
            req = urllib.request.Request(
                f"{LITELLM_URL}/v1/chat/completions",
                json.dumps(payload).encode()
            )
            req.add_header("Authorization", f"Bearer {LITELLM_KEY}")
            req.add_header("Content-Type", "application/json")
            
            resp = urllib.request.urlopen(req, timeout=30)
            result = json.loads(resp.read().decode())
            description = result["choices"][0]["message"]["content"]
            self._json({"description": description, "success": True})
        except Exception as e:
            self._json({"error": str(e), "success": False}, 500)
    
    def do_GET(self):
        self._json({"status": "ok", "service": "aiw-vision"})
    
    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 3400), Handler)
    print(f"Vision service running on :3400")
    server.serve_forever()
