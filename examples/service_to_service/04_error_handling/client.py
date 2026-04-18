"""
Client process – shows that remote exceptions are re-raised locally.

RemoteCallError (or a subclass named after the original exception type)
is raised when the service callback throws.

Start service.py first, then run this script.
"""
from daffi import Client
from daffi.rpc_proxy import RemoteCallError


if __name__ == "__main__":
    client = Client(app_name="calc-client", host="127.0.0.1", port=5004)
    conn = client.connect()
    c = conn.rpc(timeout=5)

    # Successful call
    result = c.divide(10.0, 4.0)
    print(f"divide(10, 4)    = {result}")

    # Remote ZeroDivisionError comes back as RemoteCallError
    try:
        c.divide(10.0, 0.0)
    except RemoteCallError as exc:
        print(f"Caught remote ZeroDivisionError : {exc}")

    # Remote ValueError from int("abc")
    try:
        c.parse_int("abc")
    except RemoteCallError as exc:
        print(f"Caught remote ValueError        : {exc}")

    # Successful parse
    result = c.parse_int("42")
    print(f"parse_int('42')  = {result}")

    client.stop()
    print("Done.")
