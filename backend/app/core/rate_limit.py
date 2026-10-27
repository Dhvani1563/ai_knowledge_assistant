"""Small in-memory rate limiter.

Why it exists: without it, anyone can hammer /auth/login guessing passwords,
or spam the chat endpoint and run up your AI bill. Each "bucket" (for example
"auth" or "chat") keeps timestamps of recent hits per key (an IP address or a
user id) and rejects requests over the limit with HTTP 429.

Limitation: the counters live in this process's memory. That is fine for a
single server. If you later run several server copies, move the counters to
Redis so all copies share them.
"""
import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

from .config import settings

_MAX_KEYS = 10_000
_STALE_AFTER = 3600  # seconds; counters idle this long are forgotten


class RateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque] = defaultdict(deque)
        self._lock = threading.Lock()

    @staticmethod
    def _prune(q: deque, now: float, window: float) -> None:
        while q and now - q[0] > window:
            q.popleft()

    def _collect_garbage(self, now: float) -> None:
        if len(self._hits) <= _MAX_KEYS:
            return
        stale = [k for k, q in self._hits.items() if not q or now - q[-1] > _STALE_AFTER]
        for k in stale:
            del self._hits[k]

    def check(self, key: str, limit: int, window: float = 60) -> None:
        """Counts this request and raises 429 if the key is over its limit."""
        now = time.monotonic()
        with self._lock:
            q = self._hits[key]
            self._prune(q, now, window)
            if len(q) >= limit:
                retry = max(1, int(window - (now - q[0])) + 1)
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many requests. Please slow down and try again shortly.",
                    headers={"Retry-After": str(retry)},
                )
            q.append(now)
            self._collect_garbage(now)

    def is_blocked(self, key: str, limit: int, window: float) -> bool:
        """Read-only check: has this key already used up its allowance?"""
        now = time.monotonic()
        with self._lock:
            q = self._hits.get(key)
            if not q:
                return False
            self._prune(q, now, window)
            return len(q) >= limit

    def record(self, key: str, window: float) -> None:
        """Adds one hit without checking (used to count failed logins)."""
        now = time.monotonic()
        with self._lock:
            q = self._hits[key]
            self._prune(q, now, window)
            q.append(now)

    def clear(self, key: str) -> None:
        with self._lock:
            self._hits.pop(key, None)


rate_limiter = RateLimiter()


def client_ip(request: Request) -> str:
    """The caller's IP address.

    Behind a trusted proxy the real client is the LAST entry of
    X-Forwarded-For (the one your own proxy appended). Earlier entries can be
    forged by the client, so they are ignored.
    """
    if settings.trust_proxy_headers:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[-1].strip()
    return request.client.host if request.client else "unknown"


def limit_by_ip(bucket: str, per_minute: int):
    """FastAPI dependency: `dependencies=[Depends(limit_by_ip("auth", 10))]`."""

    def _dependency(request: Request) -> None:
        rate_limiter.check(f"{bucket}:ip:{client_ip(request)}", per_minute)

    return _dependency
