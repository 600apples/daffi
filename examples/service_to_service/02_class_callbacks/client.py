"""
Client process – calls methods of the remote TextProcessor class.

The method names on the RPC proxy match the class method names directly.

Start service.py first, then run this script.
"""
from daffi import Client


SENTENCES = [
    "the quick brown fox",
    "jumps over the lazy dog",
    "daffi makes remote calls simple",
]

if __name__ == "__main__":
    client = Client(app_name="text-client", host="127.0.0.1", port=5002)
    conn = client.connect()
    c = conn.rpc(timeout=5)

    for sentence in SENTENCES:
        print(f"\noriginal   : {sentence!r}")
        print(f"upper      : {c.upper(sentence)!r}")
        print(f"reverse    : {c.reverse(sentence)!r}")
        print(f"word_count : {c.word_count(sentence)}")

    client.stop()
    print("\nDone.")
