"""
aio/service/04_serde_pickle — Service side (async).

PICKLE serialisation supports arbitrary Python objects including dataclasses
and Enums.  Both sides must share the same class definitions (models.py).

The async callback can await I/O (e.g. a database write) before returning.

Run first, then run 2_client.py.
"""
import asyncio
from daffi import callback
from daffi.aio import AsyncService
from models import Order, OrderStatus


@callback
async def process_order(order: Order) -> Order:
    print(f"[service] processing order {order.order_id!r} "
          f"(total: ${order.grand_total:.2f})")
    await asyncio.sleep(0)   # simulate async I/O (e.g. DB write)
    order.status = OrderStatus.PROCESSING
    return order


async def main():
    svc = AsyncService(app_name="order-service", host="0.0.0.0", port=5004)
    await svc.start()
    print("Service running on 0.0.0.0:5004 — press Ctrl+C to stop.")
    await svc.join()


if __name__ == "__main__":
    asyncio.run(main())
