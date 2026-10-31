"""
service/11_multitransport — TCP client.

Run 1_service.py first.
"""

from daffi import Client, TCPTransport

PORT = 5011


if __name__ == "__main__":
    client = Client(app_name="tcp-client", transport=TCPTransport("127.0.0.1", PORT))
    conn = client.connect()

    result = conn.rpc(timeout=5).add(3, 4)
    print(f"add(3, 4) over tcp = {result}")

    client.stop()
    print("Done.")
