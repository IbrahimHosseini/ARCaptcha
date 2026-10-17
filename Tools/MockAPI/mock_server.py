"""Fake ARCaptcha mobile API for testing the native renderer's UI without real challenges.

Serves synthetic images and never accepts an answer. Usage:
    python3 Tools/MockAPI/mock_server.py 8798 [puzzle|images]
Then launch the demo with `-nativeAPIBaseURL http://127.0.0.1:8798/`.
GET /mode/puzzle or /mode/images switches the challenge type.
"""
import json, struct, sys, zlib, itertools
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

def png(width, height, rgb):
    raw = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")

BACKGROUND = png(260, 160, (90, 140, 220))
PIECE = png(50, 43, (250, 200, 40))
TILE = png(100, 100, (120, 200, 140))
counter = itertools.count(1)
MODE = sys.argv[2] if len(sys.argv) > 2 else "puzzle"

class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        print("POST", self.path, body, flush=True)
        if self.path.endswith("/create/voice"):
            return self._send(201, {"captcha_type": "voice_question", "content": {"challenge_id": f"mock-{next(counter)}", "site_key": "mock", "path": "clip", "lang": "fa"}})
        if self.path.endswith("/create"):
            cid = f"mock-{next(counter)}"
            if MODE == "images":
                return self._send(201, {"captcha_type": "question", "content": {"challenge_id": cid, "site_key": "mock", "category": "mock tiles", "image_urls": [f"t{i}" for i in range(9)]}})
            return self._send(201, {"captcha_type": "puzzle", "content": {"challenge_id": cid, "site_key": "mock", "puzzle_background": "bg", "puzzle_piece": "pc", "y": 80}})
        if self.path.endswith("/answer"):
            return self._send(200, {"success": False})
        self._send(404, {"status": 404, "message": "not found"})

    def do_GET(self):
        global MODE
        print("GET", self.path, flush=True)
        if self.path.startswith("/mode/"):
            MODE = self.path.split("/")[-1]
            return self._send(200, {"mode": MODE})
        if "/puzzles/" in self.path:
            return self._send(200, PIECE if self.path.endswith("/pc") else BACKGROUND, "image/png")
        if "/images/" in self.path:
            return self._send(200, TILE, "image/png")
        self._send(404, {"status": 404, "message": "not found"})

    def log_message(self, *args):
        pass

ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
