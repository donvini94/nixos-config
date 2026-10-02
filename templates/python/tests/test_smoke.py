"""The test floor: the tool is exercised the way a user runs it, and the one invariant
that a plausible edit would break is defended by its own case."""

import httpx
import pytest
from click.testing import CliRunner

from changeme import cli, client

PAGE_ONE = {"items": [{"id": "a", "display_name": "Ada"}], "next_cursor": "c2"}
PAGE_TWO = {"items": [{"id": "b", "display_name": "Bob"}], "next_cursor": None}


def _two_page_client() -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        body = PAGE_TWO if request.url.params.get("cursor") == "c2" else PAGE_ONE
        return httpx.Response(200, json=body)

    return httpx.Client(transport=httpx.MockTransport(handler), timeout=client.DEFAULT_TIMEOUT)


def test_cli_reports_the_total_across_every_page(monkeypatch: pytest.MonkeyPatch) -> None:
    """Proves the tool runs end to end and counts BOTH pages.

    Reading only page one returns 1 and looks like success, which is the failure this
    guards: a collection endpoint gives no signal that more exists.
    """
    monkeypatch.setattr(cli, "build_client", _two_page_client)
    result = CliRunner().invoke(cli.main, ["--base-url", "https://idp.test"])

    assert result.exit_code == 0, result.output
    # stdout only: structlog diagnostics go to stderr, which is the split we want.
    assert result.stdout.strip() == "2"


def test_iter_principals_stops_when_the_cursor_is_exhausted() -> None:
    """Proves termination. A cursor loop that never checks for None hangs forever."""
    with _two_page_client() as c:
        got = list(client.iter_principals(c, "https://idp.test/users"))

    assert [p.id for p in got] == ["a", "b"]
