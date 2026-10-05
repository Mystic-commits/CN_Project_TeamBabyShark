#!/usr/bin/env python3
"""Backend B — Aditya Verma (Mac 4), port 3002."""

import json
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = "0.0.0.0"
PORT = 3002
BACKEND_ID = "B"
ETAG_VALUE = '"B-v1"'


class BackendHandler(BaseHTTPRequestHandler):
    server_version = "BackendServer-B/1.0"

    def do_GET(self):
        if self.headers.get("If-None-Match") == ETAG_VALUE:
            self.send_response(304)
            self.send_header("ETag", ETAG_VALUE)
            self.send_header("Cache-Control", "max-age=60")
            self.send_header("X-Backend", BACKEND_ID)
            self.end_headers()
            return

        if self.path in ("/", ""):
            payload = {
                "backend": BACKEND_ID,
                "status": "ok",
                "service": "team-baby-shark",
            }
        elif self.path == "/api/status":
            payload = {"backend": BACKEND_ID, "status": "ok"}
        else:
            body = json.dumps({"error": "not found"}).encode("utf-8")
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "max-age=60")
        self.send_header("ETag", ETAG_VALUE)
        self.send_header("X-Backend", BACKEND_ID)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[{BACKEND_ID}] {self.address_string()} - {fmt % args}")


def run():
    server = HTTPServer((HOST, PORT), BackendHandler)
    print(f"Backend B running on http://{HOST}:{PORT}")
    print("Machine: Mac 4 | Member: Aditya Verma | Bound to: 0.0.0.0:3002")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Backend B...")
        server.server_close()


if __name__ == "__main__":
    run()
