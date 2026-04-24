"""
service/05_serde_json — Service side.

JSON serialisation is language-agnostic and works with plain Python types:
dicts, lists, strings, numbers, and booleans.  Custom classes are not
supported; use PICKLE for those.

Run first, then run 2_client.py.
"""
from daffi import Service, callback


@callback
def summarise(data: dict) -> dict:
    items = data.get("items", [])
    total = sum(i["price"] * i["qty"] for i in items)
    print(f"[service] summarise: {len(items)} items, total=${total:.2f}")
    return {"item_count": len(items), "total": round(total, 2)}


if __name__ == "__main__":
    svc = Service(app_name="json-service", host="127.0.0.1", port=5005)
    svc.start()
    print("Service running on 127.0.0.1:5005 — press Ctrl+C to stop.")
    svc.join()
