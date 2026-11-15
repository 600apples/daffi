"""
The member-list cache never keeps an answer that an invalidation overtook.

Regressions:

* a cache miss read the native list outside the lock and stored it
  afterwards; an invalidation in between (a peer connecting or leaving) was
  lost, and the stale list stayed until the next event;
* a read racing the release of a connection left an entry for a handle that
  no longer existed.
"""

from __future__ import annotations

import json

import pytest

from daffi import _bindings


class _Native:
    """Stands in for ``dfcore``; ``during_read`` runs inside the native read."""

    def __init__(self):
        self.members = {7: ["a"]}
        self.reads = 0
        self.during_read = None

    def getAvailableMembers(self, conn_num):
        self.reads += 1
        names = self.members.get(conn_num)
        if self.during_read is not None:
            hook, self.during_read = self.during_read, None
            hook()
        if names is None:
            return None
        return json.dumps({"members": [{"name": n, "methods": []} for n in names]})


@pytest.fixture
def native(monkeypatch):
    fake = _Native()
    monkeypatch.setattr(_bindings, "dfcore", fake)
    _bindings.invalidate_members()
    yield fake
    _bindings.invalidate_members()


def _names(conn_num):
    return [m["name"] for m in _bindings.get_available_members(conn_num)]


def test_hits_are_served_from_the_cache(native):
    assert _names(7) == ["a"]
    assert _names(7) == ["a"]
    assert native.reads == 1


def test_an_invalidation_during_the_read_wins(native):
    def peer_joins():
        native.members[7] = ["a", "b"]
        _bindings.invalidate_members(7)

    native.during_read = peer_joins
    # This read started before the join, so it may return the old list...
    assert _names(7) == ["a"]
    # ...but must not be cached over the invalidation.
    assert _names(7) == ["a", "b"]
    assert native.reads == 2


def test_a_global_invalidation_during_the_read_wins(native):
    def everything_changes():
        native.members[7] = ["c"]
        _bindings.invalidate_members()

    native.during_read = everything_changes
    _names(7)
    assert _names(7) == ["c"]


def test_a_released_handle_keeps_nothing(native):
    def released():
        del native.members[7]
        _bindings.invalidate_members(7)

    native.during_read = released
    _names(7)
    assert _names(7) == []
    assert 7 not in _bindings._members_cache
    assert 7 not in _bindings._members_reads


def test_a_dead_handle_is_not_cached(native):
    assert _names(99) == []
    assert 99 not in _bindings._members_cache
    assert 99 not in _bindings._members_reads
