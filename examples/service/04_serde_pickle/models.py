"""
Shared data models for the PICKLE serialisation example.

Both 1_service.py and 2_client.py import from this module so that the
same class definitions are available in both processes (required for pickle).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import List


class OrderStatus(Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    DELIVERED = "delivered"


@dataclass
class LineItem:
    name: str
    unit_price: float
    quantity: int

    @property
    def total(self) -> float:
        return round(self.unit_price * self.quantity, 2)


@dataclass
class Order:
    order_id: str
    customer: str
    items: List[LineItem] = field(default_factory=list)
    status: OrderStatus = OrderStatus.PENDING

    @property
    def grand_total(self) -> float:
        return round(sum(item.total for item in self.items), 2)
