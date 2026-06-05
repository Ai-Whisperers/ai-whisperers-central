import json
import subprocess
import os
import hashlib
import hmac
from http.server import HTTPServer, BaseHTTPRequestHandler

SECRET = os.environ.get("WEBHOOK_SECRET", "aiw-deploy-webhook-2026")
DEPLOY_DIR = "/opt/aiw-infra"

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        
        sig = self.headers.get("X-Hub-Signature-256", "")
        if sig:
            expected = "sha256=" + hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(sig, expected):
                self._json({"error": "invalid signature"}, 403)
                return
        
        try:
            payload = json.loads(body) if body else {}
        except:
            payload = {}
        
        action = self.path.strip("/")
        
        if action == "deploy":
            result = subprocess.run(
                ["bash", f"{DEPLOY_DIR}/deploy.sh", "deploy"],
                capture_output=True, text=True, timeout=300
            )
            self._json({
                "action": "deploy",
                "exitCode": result.returncode,
                "output": result.stdout[-500:] + result.stderr[-500:]
            })
        elif action == "status":
            result = subprocess.run(
                ["bash", f"{DEPLOY_DIR}/scripts/health-check.sh"],
                capture_output=True, text=True, timeout=60
            )
            self._json({"status": result.stdout, "exitCode": result.returncode})
        elif action == "test":
            result = subprocess.run(
                ["bash", f"{DEPLOY_DIR}/scripts/test-pipeline.sh"],
                capture_output=True, text=True, timeout=120
            )
            self._json({"test": result.stdout, "exitCode": result.returncode})
        else:
            self._json({"error": f"unknown action: {action}"}, 400)
    
    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 3200), Handler)
    print(f"Deploy webhook running on :3200")
    server.serve_forever()
