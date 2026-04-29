"""
service/04_serde_pickle — Service side.

PICKLE serialisation is the default and supports arbitrary Python objects
including dataclasses, Enums, and custom classes.  Both sides must share
the same class definitions (models.py).

Run first, then run 2_client.py.
"""
from daffi import Service, callback
from models import Order, OrderStatus


@callback
def process_order(order: Order) -> Order:
    print(f"[service] processing order {order.order_id!r} "
          f"(total: ${order.grand_total:.2f})")
    order.status = OrderStatus.PROCESSING
    return order


if __name__ == "__main__":
    svc = Service(app_name="order-service", host="0.0.0.0", port=5004)
    svc.start()
    print("Service running on 0.0.0.0:5004 — press Ctrl+C to stop.")
    svc.join()
