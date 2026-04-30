"""
aio/service/04_serde_pickle — Client side (async).

Sends a rich Python dataclass (Order) to the async service using PICKLE
serialisation and receives the updated Order back.

Run 1_service.py first.
"""
import asyncio
from daffi.aio import AsyncClient
from daffi import SerdeFormat
from models import Order, LineItem, OrderStatus


async def main():
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

    client = AsyncClient(app_name="order-client", host="0.0.0.0", port=5004)
    conn = await client.connect()

    rpc = conn.rpc(timeout=5, serde=SerdeFormat.PICKLE)
    updated = await rpc.process_order(order)

    print(f"Received back: status={updated.status.value}  "
          f"total=${updated.grand_total:.2f}")

    await client.stop()
    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())
