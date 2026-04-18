"""
Client – demonstrates all four call styles when connected to a single Service.

cast() and cast_nowait() work fine with one service — the result dict
simply has one key instead of raising an error.

Start service.py first, then run this script.

Quick reference
---------------
rpc()          — one worker, blocking, returns result
rpc_nowait()   — one worker, fire-and-forget
cast()         — all matching workers, blocking, returns {name: result} dict
cast_nowait()  — all matching workers, fire-and-forget
"""
from daffi import Client


if __name__ == "__main__":
    client = Client(app_name="demo-client", host="127.0.0.1", port=5006)
    conn = client.connect()

    # ------------------------------------------------------------------ #
    # rpc() — one worker, blocking, returns the remote result             #
    # ------------------------------------------------------------------ #
    result = conn.rpc(timeout=5).add(3, 4)
    print(f"rpc().add(3, 4)            = {result}")

    # ------------------------------------------------------------------ #
    # rpc_nowait() — one worker, fire-and-forget                          #
    # ------------------------------------------------------------------ #
    conn.rpc_nowait().notify("hello from rpc_nowait()")
    print("rpc_nowait().notify(…)      (no result, returns immediately)")

    # ------------------------------------------------------------------ #
    # cast() with a single service — one-key result dict                  #
    # ------------------------------------------------------------------ #
    # Auto-discover: only one service exposes add(), so the dict has one key.
    results = conn.cast(timeout=5).add(10, 20)
    print(f"cast().add(10, 20)         = {results}")
    # e.g. {"demo-service": 30}

    # ------------------------------------------------------------------ #
    # cast_nowait() — broadcast fire-and-forget (one key here)            #
    # ------------------------------------------------------------------ #
    conn.cast_nowait().notify("hello from cast_nowait()")
    print("cast_nowait().notify(…)     (no result, fire-and-forget)")

    client.stop()
    print("Done.")
