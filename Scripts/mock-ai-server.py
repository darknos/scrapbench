#!/usr/bin/env python3
"""A stand-in for both AI providers, for checking prompt transformers by hand.

Speaks the Anthropic Messages API (POST /v1/messages) and the Chat Completions
API (POST /v1/chat/completions). What happens is picked by the request's
"model" field:

  echo    the user text upper-cased, with a trailing newline (the normal case)
  slow    sleeps 8 s, then echoes
  refuse  stop_reason "refusal" / finish_reason "content_filter"
  empty   an answer of just "\n"
  long    stop_reason "max_tokens" / finish_reason "length"
  rate    HTTP 429 with an error body
  html    HTTP 200 with a text/html body

A key of "bad" (x-api-key or Bearer) gets a 401.

    python3 -I Scripts/mock-ai-server.py [--port 8089]
    defaults write org.nosenko.Scrapbench aiAnthropicBaseURL http://localhost:8089
    # or Settings → AI → Other server, base URL http://localhost:8089/v1
"""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("%s %s" % (self.command, self.path), *args)

    def do_POST(self):
        length = int(self.headers.get("content-length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        model = body.get("model", "")
        anthropic = self.path.endswith("/v1/messages")
        key = self.headers.get("x-api-key") or self.headers.get("authorization", "").removeprefix("Bearer ")
        if key == "bad":
            return self.send_json(401, {"error": {"type": "authentication_error", "message": "invalid x-api-key"}})
        if model == "rate":
            return self.send_json(429, {"error": {"type": "rate_limit_error", "message": "slow down"}})
        if model == "html":
            return self.send_raw(200, "text/html", b"<html><body>captive portal</body></html>")
        if model == "slow":
            time.sleep(8)
        if anthropic:
            user = body["messages"][-1]["content"]
        else:
            user = [m for m in body["messages"] if m["role"] == "user"][-1]["content"]
        text = "\n" if model == "empty" else user.upper() + "\n"
        stop = {"refuse": "refusal", "long": "max_tokens"}.get(model, "end_turn")
        finish = {"refuse": "content_filter", "long": "length"}.get(model, "stop")
        if anthropic:
            return self.send_json(200, {
                "id": "msg_mock", "type": "message", "role": "assistant", "model": model,
                "stop_reason": stop, "stop_details": None,
                "content": [{"type": "thinking", "thinking": ""}, {"type": "text", "text": text}],
                "usage": {"input_tokens": 1, "output_tokens": 1},
            })
        return self.send_json(200, {
            "id": "chatcmpl-mock", "object": "chat.completion", "model": model,
            "choices": [{"index": 0, "finish_reason": finish, "message": {"role": "assistant", "content": text}}],
        })

    def send_json(self, status, payload):
        self.send_raw(status, "application/json", json.dumps(payload).encode())

    def send_raw(self, status, content_type, data):
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8089)
    args = parser.parse_args()
    print("mock AI server on http://localhost:%d" % args.port)
    HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
