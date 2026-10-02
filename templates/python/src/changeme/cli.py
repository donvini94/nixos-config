"""CHANGEME — one line on what this tool does."""

import sys

import click
import structlog

from changeme.client import build_client, iter_principals

log = structlog.get_logger()


def configure_logging() -> None:
    """Diagnostics to stderr; pretty on a terminal, JSON when a machine reads it.

    Both halves are load-bearing. structlog's default factory writes to STDOUT, which
    would mix diagnostics into the tool's output and break `... | jq`. The isatty split
    is structlog's own documented recommendation.
    """
    renderer: object = (
        structlog.dev.ConsoleRenderer()
        if sys.stderr.isatty()
        else structlog.processors.JSONRenderer()
    )
    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            renderer,  # type: ignore[list-item]
        ],
        logger_factory=structlog.PrintLoggerFactory(file=sys.stderr),
    )


@click.command()
@click.option("--base-url", required=True, help="Root URL of the identity API.")
def main(base_url: str) -> None:
    """Count every principal the API will return."""
    configure_logging()

    with build_client() as client:
        total = sum(1 for _ in iter_principals(client, f"{base_url}/users"))

    # echo for the tool's actual output; the logger is for diagnostics.
    click.echo(total)
