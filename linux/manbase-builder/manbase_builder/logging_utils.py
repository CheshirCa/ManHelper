"""Consistent application logging configuration."""

from __future__ import annotations

import logging


def configure_logging(*, verbose: bool = False, quiet: bool = False) -> None:
    if verbose and quiet:
        raise ValueError("verbose and quiet are mutually exclusive")
    level = logging.ERROR if quiet else logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        force=True,
    )
