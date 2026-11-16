#!/usr/bin/env python3
"""Exercise the plugin with Lua 5.1 and an installed, real uploader.

The local HTTP fixture implements the API contracts; it never contacts a real
account. Optional --ultra-input adds actual codec exports of a profiled TIFF.
"""
import argparse
import base64
import http.server
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import threading

parser = argparse.ArgumentParser()
parser.add_argument("--lua", default="lua")
parser.add_argument("--uploader", required=True)
parser.add_argument("--ultra-input", type=Path)
parser.add_argument("--keep-output", type=Path, help="Directory for received Ultra files")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
received = []
created = []


class Api(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status, value):
        data = json.dumps(value, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        if self.headers.get("x-api-key") != "fixture-'key-$&%":
            self.reply(401, {"message": "Invalid fixture credential"})
            return False
        return True

    def read_body(self):
        if self.headers.get("Transfer-Encoding", "").lower() != "chunked":
            return self.rfile.read(int(self.headers["Content-Length"]))
        chunks = []
        while True:
            size = int(self.rfile.readline().split(b";", 1)[0], 16)
            if not size:
                self.rfile.readline()
                return b"".join(chunks)
            chunks.append(self.rfile.read(size))
            assert self.rfile.read(2) == b"\r\n"

    def do_GET(self):
        if not self.authorized():
            return
        if self.path == "/accounts/fixture-account":
            self.reply(200, {"accountId": "fixture-account", "uniqueName": "Fixture studio"})
        elif self.path == "/accounts/fixture-account/containers":
            self.reply(200, [{"id": "fixture-album", "name": "Sélection 📷", "access": 0}])
        else:
            self.reply(404, {})

    def do_POST(self):
        if not self.authorized():
            return
        data = json.loads(self.read_body())
        if self.path == "/accounts/fixture-account/containers":
            assert data["access"] == 0, data
            created.append(data["name"])
            self.reply(200, {"id": "created-album", **data})
        elif self.path in (
            "/accounts/fixture-account/containers/fixture-album/ingests",
            "/accounts/fixture-account/containers/created-album/ingests",
        ):
            name = data["files"][0]
            if name == "reject.jpg":
                self.reply(400, {"message": "Deliberately rejected fixture"})
                return
            assert len(data["files"]) == 1
            self.server.next_file = name
            self.reply(200, [{
                "clientFileId": 0, "fileName": name, "ingestId": "fixture-ingest",
                "uploadUrl": f"http://127.0.0.1:{self.server.server_port}/upload",
            }])
        else:
            self.reply(404, {})

    def do_PUT(self):
        # Presigned storage requests must never carry the account API key.
        assert self.headers.get("x-api-key") is None
        data = self.read_body()
        assert self.path == "/upload" and data
        name = self.server.next_file
        received.append(name)
        if args.keep_output and Path(name).suffix in (".avif", ".jxl"):
            args.keep_output.mkdir(parents=True, exist_ok=True)
            (args.keep_output / name).write_bytes(data)
        self.reply(200, {})


with tempfile.TemporaryDirectory(prefix="lumicodex-lightroom-") as tmp:
    temp = Path(tmp)
    (temp / "lumicodex-ultra").mkdir()
    for name in ("one's $&% 📷.jpg", "reject.jpg", "three.jpg"):
        (temp / name).write_bytes(b"fixture-photo-bytes")
    env = {**os.environ,
           "LUMICODEX_TEST_TEMP": tmp,
           "LUMICODEX_TEST_UPLOADER": str(Path(args.uploader).resolve()),
           "LUMICODEX_TEST_TIFF": str(args.ultra_input.resolve()) if args.ultra_input else ""}
    server = http.server.HTTPServer(("127.0.0.1", 0), Api)
    env["LUMICODEX_TEST_API_URL"] = f"http://127.0.0.1:{server.server_port}/"
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        for test in ("gallery-conflict", "uploader-contract", "windows-command"):
            subprocess.run([args.lua, f"tests/{test}.lua"], cwd=root, env=env, check=True)
        command = (temp / "windows-command.txt").read_text()
        script = base64.b64decode(command.split()[-1], validate=True).decode("utf-16-le")
        values = [base64.b64decode(value).decode() for value in
                  re.findall(r"FromBase64String\('([A-Za-z0-9+/=]*)'\)", script)]
        assert values[:2] == ["fixture-'key-$&%", "C:\\Users\\L'été\\lumicodex-upload.exe"], values
        assert 'Sélection "quoted" %PATH% $& 📷' in values
        assert "Out-File:Encoding" in script and "exit $LASTEXITCODE" in script
        assert received[:3] == ["one's $&% 📷.jpg", "three.jpg", "three.jpg"], received
        assert created == ["L'été $&% \"selects\" 📷", "Export-created album"], created
        if args.ultra_input:
            assert received[-2:] == ["render.avif", "render.jxl"], received
        print(f"PASS: {len(received)} uploads through the real uploader; no real account used")
    finally:
        server.shutdown()
        server.server_close()
