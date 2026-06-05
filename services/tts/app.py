import json
import os
import tempfile
import asyncio
import edge_tts
from http.server import HTTPServer, BaseHTTPRequestHandler

VOICE_MAP = {
    "es": "es-ES-ElviraNeural",
    "es-MX": "es-MX-DaliaNeural",
    "en": "en-US-JennyNeural",
    "en-US": "en-US-JennyNeural",
    "gu": "es-ES-ElviraNeural",
    "pt": "pt-BR-FranciscaNeural",
    "default": "es-ES-ElviraNeural",
}

def detect_language(text):
    has_guarani = any(w in text.lower() for w in ["che", "nde", "ha'e", "mba'e", "pe", "ko", "nte"])
    if has_guarani:
        return "gu"
    has_spanish = any(w in text.lower() for w in ["que", "como", "hola", "gracias", "bueno", "si", "por favor", "estoy", "eres", "puedes"])
    if has_spanish:
        return "es"
    return "en"

def get_voice(lang):
    return VOICE_MAP.get(lang, VOICE_MAP["default"])

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.strip("/")
        if path == "health" or path == "":
            self._json({"status": "ok", "service": "aiw-tts"})
            return
        if path == "voices":
            self._json({"voices": VOICE_MAP})
            return
        self._json({"error": "use POST /synthesize"}, 404)

    def do_POST(self):
        path = self.path.strip("/")
        if path != "synthesize":
            self._json({"error": "use POST /synthesize"}, 404)
            return

        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        text = body.get("text", "")
        lang = body.get("lang", "")
        voice = body.get("voice", "")

        if not text:
            self._json({"error": "text is required"}, 400)
            return

        if not lang:
            lang = detect_language(text)
        if not voice:
            voice = get_voice(lang)

        try:
            output_path = tempfile.mktemp(suffix=".mp3")
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            async def gen():
                comm = edge_tts.Communicate(text, voice)
                await comm.save(output_path)
            
            loop.run_until_complete(gen())
            loop.close()

            with open(output_path, "rb") as f:
                audio_data = f.read()
            
            os.unlink(output_path)

            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self.send_header("Content-Length", str(len(audio_data)))
            self.end_headers()
            self.wfile.write(audio_data)
        except Exception as e:
            self._json({"error": str(e)}, 500)

    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 3500), Handler)
    print("TTS Service running on :3500 (edge-tts)")
    server.serve_forever()
