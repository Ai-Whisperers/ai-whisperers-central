#!/usr/bin/env python3
"""Hermes TUI - Terminal chat interface for the AI Whisperers code agent."""

import sys
import json
import urllib.request
import uuid
import readline
import ssl

HERMES_URLS = [
    "http://127.0.0.1:8080/api/chat",
    "https://code-agent.sunstein.cloud/api/chat",
]


def _make_request(url, payload):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    return urllib.request.urlopen(req, timeout=120, context=ctx)


def chat_stream(message, conversation_id=None):
    payload = {"message": message}
    if conversation_id:
        payload["conversationId"] = conversation_id

    resp = None
    for url in HERMES_URLS:
        try:
            resp = _make_request(url, payload)
            break
        except Exception:
            continue
    if resp is None:
        raise ConnectionError("Could not connect to Hermes on any endpoint")

    full_text = ""
    conv_id = conversation_id

    buffer = ""
    for chunk in iter(lambda: resp.read(1).decode("utf-8", errors="replace"), ""):
        buffer += chunk
        while "\n\n" in buffer:
            event_str, buffer = buffer.split("\n\n", 1)
            for line in event_str.split("\n"):
                if line.startswith("data:"):
                    data_str = line[5:].strip()
                    try:
                        data = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue

                    if data.get("type") == "text":
                        text = data.get("text", "")
                        print(text, end="", flush=True)
                        full_text += text
                    elif data.get("type") == "error":
                        print(f"\n[ERROR] {data.get('message', 'Unknown error')}")
                    elif data.get("type") == "done":
                        conv_id = data.get("conversationId", conv_id)

    print()
    return full_text, conv_id


def main():
    conversation_id = None

    print("=" * 60)
    print("  HERMES - AI Whisperers Code Agent")
    print("  Terminal Chat Interface")
    print("=" * 60)
    print()
    print("Commands: /clear (new chat), /quit (exit), /id (show conv ID)")
    print()

    while True:
        try:
            message = input("\n\033[1;36mYou>\033[0m ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nBye!")
            break

        if not message:
            continue

        if message == "/quit":
            print("Bye!")
            break
        elif message == "/clear":
            conversation_id = None
            print("[New conversation started]")
            continue
        elif message == "/id":
            print(f"Conversation ID: {conversation_id or 'new'}")
            continue

        print("\n\033[1;33mHermes>\033[0m ", end="", flush=True)
        try:
            _, conversation_id = chat_stream(message, conversation_id)
        except Exception as e:
            print(f"[Connection error: {e}]")


if __name__ == "__main__":
    main()
