"""
service/03_class_callbacks — Service side.

Applying @callback to a class automatically registers every public method
as a remote callback.  Methods decorated with @local are excluded and
remain purely local.

Run first, then run 2_client.py.
"""
from daffi import Service, callback
from daffi.registry import local


@callback
class TextProcessor:
    """All public methods become remote callbacks; @local ones do not."""

    def __init__(self):
        self._call_count = 0

    def upper(self, text: str) -> str:
        self._call_count += 1
        print(f"[service] upper({text!r})  [call #{self._call_count}]")
        return text.upper()

    def reverse(self, text: str) -> str:
        self._call_count += 1
        print(f"[service] reverse({text!r})  [call #{self._call_count}]")
        return text[::-1]

    def word_count(self, text: str) -> int:
        self._call_count += 1
        print(f"[service] word_count({text!r})  [call #{self._call_count}]")
        return len(text.split())

    @local
    def reset(self):
        """@local — not exported; only callable within this process."""
        self._call_count = 0


if __name__ == "__main__":
    svc = Service(app_name="text-service", host="0.0.0.0", port=5003)
    svc.start()
    print("Service running on 0.0.0.0:5003 — press Ctrl+C to stop.")
    svc.join()
