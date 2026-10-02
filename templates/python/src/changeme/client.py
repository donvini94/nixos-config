"""API client showing the shapes the rules require, so they are copied rather than reinvented."""

from collections.abc import Iterator

import httpx
import structlog
from pydantic import BaseModel

log = structlog.get_logger()

# Explicit even though httpx has defaults: the default is a floor, not a decision.
DEFAULT_TIMEOUT = httpx.Timeout(connect=5.0, read=30.0, write=10.0, pool=5.0)


class Principal(BaseModel):
    """One identity, as the upstream API returns it."""

    id: str
    display_name: str


class Page(BaseModel):
    """One page of principals plus the server's own cursor."""

    items: list[Principal]
    next_cursor: str | None = None


def build_client() -> httpx.Client:
    """Construct the HTTP client. Separate so tests can substitute a transport."""
    return httpx.Client(timeout=DEFAULT_TIMEOUT)


def iter_principals(client: httpx.Client, url: str) -> Iterator[Principal]:
    """Yield every principal, following the server's cursor to exhaustion.

    Stopping after the first page is the silent bug this exists to prevent: a collection
    endpoint returns page one with no error and no indication that more exists, so a
    deprovisioning script reports "no orphaned accounts" because it never looked.
    """
    cursor: str | None = None
    while True:
        params = {"cursor": cursor} if cursor is not None else {}
        response = client.get(url, params=params, timeout=DEFAULT_TIMEOUT)
        response.raise_for_status()
        page = Page.model_validate(response.json())

        # Log the shape, never the payload — a response body can carry a bearer token.
        log.info("fetched_page", count=len(page.items), has_more=page.next_cursor is not None)

        yield from page.items
        if page.next_cursor is None:
            return
        cursor = page.next_cursor
