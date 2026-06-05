import json
import os
import tempfile
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

GROQ_KEY = os.environ.get("GROQ_API_KEY", "")
GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
EVO_KEY = os.environ.get("EVOLUTION_API_KEY", "")
EVO_BASE = os.environ.get("EVOLUTION_BASE", "https://evolution.sunstein.cloud")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        audio_url = body.get("audioUrl", "")
        audio_base64 = body.get("audioBase64", "")
        
        if not audio_url and not audio_base64:
            self._json({"error": "missing audioUrl or audioBase64"}, 400)
            return
        
        try:
            if audio_url:
                text = self._transcribe_url(audio_url)
            else:
                text = self._transcribe_base64(audio_base64)
            self._json({"text": text, "success": True})
        except Exception as e:
            self._json({"error": str(e), "success": False}, 500)
    
    def _transcribe_url(self, url):
        with tempfile.NamedTemporaryFile(suffix=".ogg", delete=False) as tmp:
            tmp_path = tmp.name
        
        try:
            headers = {}
            if "evolution" in url.lower() or "sunstein" in url.lower():
                headers["apikey"] = EVO_KEY
            
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                with open(tmp_path, "wb") as f:
                    f.write(resp.read())
            
            return self._send_to_groq(tmp_path)
        finally:
            os.unlink(tmp_path)
    
    def _transcribe_base64(self, b64_data):
        import base64
        with tempfile.NamedTemporaryFile(suffix=".ogg", delete=False) as tmp:
            tmp_path = tmp.name
            tmp.write(base64.b64decode(b64_data))
        
        try:
            return self._send_to_groq(tmp_path)
        finally:
            os.unlink(tmp_path)
    
    def _send_to_groq(self, file_path):
        import mimetypes
        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        lines = []
        
        lines.append(f"--{boundary}".encode())
        lines.append(f'Content-Disposition: form-data; name="model"'.encode())
        lines.append(b"")
        lines.append("whisper-large-v3".encode())
        
        lines.append(f"--{boundary}".encode())
        lines.append(f'Content-Disposition: form-data; name="response_format"'.encode())
        lines.append(b"")
        lines.append("json".encode())
        
        lines.append(f"--{boundary}".encode())
        filename = os.path.basename(file_path)
        lines.append(f'Content-Disposition: form-data; name="file"; filename="{filename}"'.encode())
        lines.append(f"Content-Type: audio/ogg".encode())
        lines.append(b"")
        
        with open(file_path, "rb") as f:
            lines.append(f.read())
        lines.append(f"--{boundary}--".encode())
        lines.append(b"")
        
        body = b"\r\n".join(lines)
        
        req = urllib.request.Request(GROQ_URL, data=body)
        req.add_header("Authorization", f"Bearer {GROQ_KEY}")
        req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        
        resp = urllib.request.urlopen(req, timeout=30)
        result = json.loads(resp.read().decode())
        return result.get("text", "")
    
    def do_GET(self):
        self._json({"status": "ok", "service": "aiw-stt"})
    
    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 3300), Handler)
    print(f"STT service running on :3300")
    server.serve_forever()
