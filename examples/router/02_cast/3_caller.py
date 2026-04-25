"""
router/02_cast — Caller.

Broadcasts to ALL connected workers and collects every response.

  cast()        — fan-out to all workers, wait for all responses → {name: result}
  cast_nowait() — fire-and-forget, no results collected

Start 1_router.py and 2_worker.py (×3) first.
"""
from daffi import Client
from daffi._rpc_proxy import get_available_members


if __name__ == "__main__":
    caller = Client(app_name="cast-caller", host="127.0.0.1", port=6002)
    conn = caller.connect()

    workers = [
        m["name"]
        for m in get_available_members(caller._conn_num)
        if m["name"] != caller.app_name
    ]
    print(f"Connected workers: {workers}\n")

    results = conn.cast(timeout=5).process("task-A")
    for name, reply in results.items():
        print(f"  {name}: {reply}")

    conn.cast_nowait().process("task-B")
    print("  Sent (no reply collected)")

    caller.stop()
    print("\nDone.")
