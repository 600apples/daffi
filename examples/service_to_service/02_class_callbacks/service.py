"""
Service process – registers callbacks via a class.

All public methods of a @callback-decorated class are automatically
exposed as remote functions.  Methods whose names start with '_' or that
carry the @local decorator are never exposed.

Start this process first, then run client.py.
"""
from daffi import Service, callback
from daffi.registry import local


@callback
class TextProcessor:
    """All public methods of this class become remote callbacks."""

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
    def _reset(self):
        """Decorated with @local – not accessible remotely."""
        self._call_count = 0


if __name__ == "__main__":
    svc = Service(app_name="text-service", host="127.0.0.1", port=5002)
    svc.start()
    print("Text service running on 127.0.0.1:5002 – press Ctrl+C to stop.")
    svc.join()
