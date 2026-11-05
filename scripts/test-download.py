#!/usr/bin/env python3
"""Bounded update download checks against a local HTTP server.

Uses the DEBUG-only `Parakey --test-download <url> <dest> <limit>` hook.
No network access, no application launch, no user data is touched.
"""
import http.server
import os
import pathlib
import subprocess
import sys
import tempfile
import threading

ROOT = pathlib.Path(__file__).resolve().parent.parent
BINARY = ROOT / "swift/.build/debug/Parakey"
LIMIT = 1024
PAYLOAD_OK = b"v" * 512
PAYLOAD_BIG = b"x" * (LIMIT * 64)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"  # close-delimited bodies when no Content-Length

    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path == "/ok":
            self._send(200, PAYLOAD_OK, length=True)
        elif self.path == "/big-length":
            self._send(200, PAYLOAD_BIG, length=True)
        elif self.path == "/big-stream":
            self._send(200, PAYLOAD_BIG, length=False)
        elif self.path == "/exact":
            self._send(200, b"e" * LIMIT, length=False)
        else:
            self._send(404, b"missing", length=True)

    def _send(self, status, body, length):
        self.send_response(status)
        self.send_header("Content-Type", "application/octet-stream")
        if length:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            for start in range(0, len(body), 4096):
                self.wfile.write(body[start:start + 4096])
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass  # client rejected the oversized body mid-transfer


def run(url, dest):
    return subprocess.run([str(BINARY), "--test-download", url, str(dest), str(LIMIT)],
                          capture_output=True, text=True, timeout=60)


def main():
    if not BINARY.exists():
        subprocess.run(["swift", "build", "-c", "debug", "--package-path", str(ROOT / "swift")], check=True)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_address[1]}"
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        cases = [
            ("/ok", True, PAYLOAD_OK),
            ("/exact", True, b"e" * LIMIT),
            ("/big-length", False, None),
            ("/big-stream", False, None),
            ("/missing", False, None),
        ]
        for path, should_pass, expected in cases:
            dest = pathlib.Path(tmp) / path.strip("/")
            result = run(base + path, dest)
            passed = result.returncode == 0
            if passed != should_pass:
                failures.append(f"{path}: expected {'pass' if should_pass else 'reject'}, got {result.stdout.strip()} {result.stderr.strip()}")
            elif should_pass and dest.read_bytes() != expected:
                failures.append(f"{path}: downloaded content differs")
            elif not should_pass and dest.exists():
                failures.append(f"{path}: partial file was not removed")
    server.shutdown()
    if failures:
        print("FAIL bounded download:\n  " + "\n  ".join(failures), file=sys.stderr)
        return 1
    print("PASS bounded download: limit with and without Content-Length, exact size, HTTP error, partial cleanup")
    return 0


if __name__ == "__main__":
    sys.exit(main())
