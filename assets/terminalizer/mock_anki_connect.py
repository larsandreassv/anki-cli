#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get('ANKI_DEMO_PORT', '8766'))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"Anki-Connect"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8"))
        action = payload.get("action")
        params = payload.get("params", {})
        if action == "version":
            result = 6
        elif action == "deckNames":
            result = ["Japanese::RTK", "Japanese::WordWrite"]
        elif action == "modelNames":
            result = ["RTK", "WordWrite"]
        elif action == "modelFieldNames":
            model = params.get("modelName")
            if model == "RTK":
                result = ["Keyword", "Kanji"]
            elif model == "WordWrite":
                result = ["Reading", "Definition", "Kanji"]
            else:
                self.respond({"result": None, "error": f"unknown model: {model}"})
                return
        elif action == "canAddNotes":
            result = [True]
        elif action == "addNote":
            result = 123456789
        elif action == "findNotes":
            result = [123456789]
        else:
            self.respond({"result": None, "error": f"unsupported action: {action}"})
            return
        self.respond({"result": result, "error": None})

    def respond(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return

HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
