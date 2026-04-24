"""
js/02_service_msgpack — Python service side.

Exposes callbacks that accept and return data via MSGPACK serialisation.
MSGPACK is more compact than JSON for binary-heavy payloads.

The browser client encodes arguments as msgpack bytes and the service
returns msgpack-encoded responses — end-to-end binary serialisation.

Requires: pip install 'daffi[msgpack]'

Run this first, then open index.html in a browser (via an HTTP server).
"""
from daffi import Service, callback
from daffi import SerdeFormat


@callback
def compute(data: dict) -> dict:
    values = data.get("values", [])
    total  = sum(values)
    result = {
        "count": len(values),
        "sum":   total,
        "avg":   round(total / len(values), 4) if values else 0,
    }
    print(f"[service] compute(values={values}) → {result}")
    return result


@callback
def echo(payload) -> object:
    print(f"[service] echo({payload!r})")
    return payload


if __name__ == "__main__":
    svc = Service(app_name="msgpack-service", host="127.0.0.1", port=5011)
    svc.start()
    print("Service on ws://127.0.0.1:5011 — open index.html in a browser.")
    svc.join()
