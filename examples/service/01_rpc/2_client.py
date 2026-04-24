"""
service/01_rpc — Client side.

Connects to the service and makes a blocking RPC call using conn.rpc().
The call blocks until the service returns the result.

Run 1_service.py first.
"""
from daffi import Client


if __name__ == "__main__":
    client = Client(app_name="calc-client", host="127.0.0.1", port=5001)
    conn = client.connect()

    rpc = conn.rpc(timeout=5)

    result = rpc.add(3, 4)
    print(f"add(3, 4) = {result}")

    result = rpc.add(10, 20)
    print(f"add(10, 20) = {result}")

    client.stop()
    print("Done.")
