"""
service/03_class_callbacks — Client side.

Calls the three public methods of the remote TextProcessor class.
The @local 'reset' method is NOT remotely callable and is omitted.

Run 1_service.py first.
"""
from daffi import Client


SENTENCES = [
    "the quick brown fox",
    "jumps over the lazy dog",
    "daffi makes remote calls simple",
]

if __name__ == "__main__":
    client = Client(app_name="text-client", host="127.0.0.1", port=5003)
    conn = client.connect()

    rpc = conn.rpc(timeout=5)

    for sentence in SENTENCES:
        print(f"\noriginal   : {sentence!r}")
        print(f"upper      : {rpc.upper(sentence)!r}")
        print(f"reverse    : {rpc.reverse(sentence)!r}")
        print(f"word_count : {rpc.word_count(sentence)}")

    client.stop()
    print("\nDone.")
