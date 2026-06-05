#!/usr/bin/env python3
"""Lightweight HTTP API for Hermes Agent CLI wrapper."""
import http.server
import json
import subprocess
import os

PORT = 3600

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.strip("/") == "health":
            self._json({"status": "ok"})
        else:
            self._json({"error": "POST to / with {message: ...}"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        query = body.get("message", "")
        if not query:
            self._json({"error": "message required"}, 400)
            return

        try:
            result = subprocess.run(
                ["bash", "/opt/aiw-infra/scripts/hermes-api.sh", query],
                capture_output=True, text=True, timeout=120,
                env={**os.environ, "PATH": os.path.expanduser("~") + "/.local/bin:" + os.environ.get("PATH", "")}
            )
            text = result.stdout.strip()
            if not text and result.stderr:
                text = f"Error: {result.stderr.strip()[:200]}"
            self._json({"response": text})
        except subprocess.TimeoutExpired:
            self._json({"error": "Hermes timeout (120s)"}, 504)
        except Exception as e:
            self._json({"error": str(e)}, 500)

    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Hermes HTTP API on :{PORT}")
    server.serve_forever()
