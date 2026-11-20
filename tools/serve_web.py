#!/usr/bin/env python3
"""Serve a web build locally, the way itch.io serves it.

    python3 tools/serve_web.py [build/web] [port]

then open http://localhost:8060 in Chrome, Edge or Firefox. It sends the
"cross-origin isolation" headers (COOP/COEP) that the threaded web build
needs for SharedArrayBuffer, which is what itch.io's "SharedArrayBuffer
support" option does. The no-threads build works with or without them.
"""
import functools
import http.server
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "application/javascript",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # quiet


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8060
    handler = functools.partial(Handler, directory=root)
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"Serving {root} at http://localhost:{port}  (Ctrl+C to stop)")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
