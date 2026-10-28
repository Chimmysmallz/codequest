"""Per-user in-memory rate limiting for the CodeQuest backend.

This limiter is **per-process and in-memory**. Each Uvicorn worker / container
instance keeps its OWN sliding-window counters, so with multiple workers or
multiple replicas a single user's effective limit is multiplied by the number
of processes (each one counts independently). That is fine for the current
single-instance dev/small deployments here.

TODO(multi-instance): for a real horizontally-scaled deployment, back this with
a shared store (e.g. Redis) so the window is counted across all workers /
instances — e.g. a Redis sorted-set per key (ZADD/ZREMRANGEBYSCORE) or an
atomic INCR+EXPIRE fixed-window Lua script. The `RateLimiter.hit` contract
below (return ``(allowed, retry_after)``) is designed so only its body needs to
change; the ``rate_limited`` dependency factory can stay the same.
"""

import collections
import threading
import time

from fastapi import Depends, HTTPException

from firebase_auth import get_current_identity


class RateLimiter:
    """Thread-safe in-memory sliding-window rate limiter.

    Keeps, per key, a deque of ``time.monotonic()`` timestamps for the hits
    that fall inside the current window. All access is guarded by a single
    ``threading.Lock`` so it is safe to share one instance across threads
    (FastAPI runs sync path operations in a thread pool).
    """

    def __init__(self) -> None:
        self._hits: dict[str, "collections.deque[float]"] = {}
        self._lock = threading.Lock()

    def hit(self, key: str, max_hits: int, window_s: float) -> tuple[bool, float]:
        """Register an attempt for ``key`` under a sliding window.

        Prunes timestamps older than ``window_s``. If the number of remaining
        in-window hits is already at/over ``max_hits``, the attempt is REJECTED
        and no timestamp is recorded; otherwise ``now`` is appended and the
        attempt is allowed.

        Returns ``(allowed, retry_after)``:
          * allowed       -> True if under the limit, False if throttled.
          * retry_after   -> seconds until the oldest in-window hit expires
                             (0.0 when allowed). This is how long the caller
                             should wait before the next attempt can succeed.
        """
        now = time.monotonic()
        cutoff = now - window_s
        with self._lock:
            bucket = self._hits.get(key)
            if bucket is None:
                bucket = collections.deque()
                self._hits[key] = bucket

            # Drop timestamps that have aged out of the window.
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()

            if len(bucket) >= max_hits:
                # Throttled: the window frees up when the oldest hit expires.
                oldest = bucket[0]
                retry_after = (oldest + window_s) - now
                if retry_after < 0.0:
                    retry_after = 0.0
                return (False, retry_after)

            bucket.append(now)
            return (True, 0.0)


# Module-level singleton — share ONE limiter across the whole process so every
# request counts against the same per-key windows.
limiter = RateLimiter()


def rate_limited(bucket: str, max_hits: int, window_s: int):
    """Build a FastAPI dependency that rate-limits per Firebase uid.

    ``bucket`` namespaces the counter (e.g. "run" vs "submit") so the two
    endpoints have independent limits. The returned dependency itself depends
    on :func:`get_current_identity`, so it STILL enforces Firebase auth (a bad
    token yields 401 before any limiting happens) and returns the same identity
    dict the endpoints expect.
    """

    def _dep(identity=Depends(get_current_identity)):
        allowed, retry = limiter.hit(f"{bucket}:{identity['uid']}", max_hits, window_s)
        if not allowed:
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please slow down.",
                headers={"Retry-After": str(int(retry) + 1)},
            )
        return identity

    return _dep
