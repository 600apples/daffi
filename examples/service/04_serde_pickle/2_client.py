"""
service/04_serde_pickle — Client side.

Sends a rich Python dataclass (Order) to the service using PICKLE
serialisation (the default).  The service returns the updated object.

Run 1_service.py first.
"""
from daffi import Client
from daffi.serialization import SerdeFormat
from models import Order, LineItem, OrderStatus


if __name__ == "__main__":
    order = Order(
        order_id="ORD-001",
        customer="Alice",
        items=[
            LineItem("Widget A", 9.99, 3),
            LineItem("Widget B", 4.49, 5),
        ],
        status=OrderStatus.PENDING,
    )

    print(f"Sending order: {order.order_id}  total=${order.grand_total:.2f}  "
          f"status={order.status.value}")

    client = Client(app_name="order-client", host="127.0.0.1", port=5004)
    conn = client.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.PICKLE)
    updated = rpc.process_order(order)

    print(f"Received back: status={updated.status.value}  "
          f"total=${updated.grand_total:.2f}")

    client.stop()
    print("Done.")
