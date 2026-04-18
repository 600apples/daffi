"""
Caller – connects to the router and calls functions on both workers.

The caller targets each worker explicitly via receiver=; the router
dispatches to the right node automatically.

Start router.py, math_worker.py, and text_worker.py first, then run
this script.
"""
from daffi import Client
from daffi.rpc_proxy import RemoteCallError


if __name__ == "__main__":
    client = Client(app_name="caller", host="127.0.0.1", port=6001)
    conn = client.connect()

    math = conn.rpc(timeout=5, receiver="math-worker")
    text = conn.rpc(timeout=5, receiver="text-worker")

    print("── Math worker ──────────────────────────")
    print(f"add(10, 3)       = {math.add(10, 3)}")
    print(f"subtract(10, 3)  = {math.subtract(10, 3)}")
    print(f"multiply(10, 3)  = {math.multiply(10, 3)}")
    print(f"divide(10, 3)    = {math.divide(10, 3):.4f}")

    try:
        math.divide(1, 0)
    except RemoteCallError as exc:
        print(f"divide(1, 0)     → RemoteCallError: {exc}")

    print("\n── Text worker ──────────────────────────")
    sentence = "The Quick Brown Fox"
    print(f"upper({sentence!r})      = {text.upper(sentence)!r}")
    print(f"lower({sentence!r})      = {text.lower(sentence)!r}")
    print(f"reverse({sentence!r})    = {text.reverse(sentence)!r}")
    print(f"word_count({sentence!r}) = {text.word_count(sentence)}")

    client.stop()
    print("\nDone.")
