"""
js/01_service_json — Python service side.

Exposes two callbacks reachable from the browser via JSON serde:
  add(a, b)     — returns a + b
  greet(name)   — returns a greeting string

Run this first, then open index.html in a browser (via an HTTP server).

NOTE: the daffi server accepts both native TCP connections AND browser
WebSocket connections on the same port — no extra gateway needed.
"""
from daffi import Service, callback


@callback
def add(a: float, b: float) -> float:
    result = a + b
    print(f"[service] add({a}, {b}) = {result}")
    return result


@callback
def greet(name: str) -> str:
    msg = f"Hello, {name}! — from daffi service"
    print(f"[service] greet({name!r})")
    return msg


if __name__ == "__main__":
    svc = Service(app_name="json-service", host="127.0.0.1", port=5010)
    svc.start()
    print("Service on ws://127.0.0.1:5010 — open index.html in a browser.")
    svc.join()
