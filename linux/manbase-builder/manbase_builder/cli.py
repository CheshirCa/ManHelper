"""Command-line parsing for ManBase Builder."""

from __future__ import annotations

import argparse
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="manbase-builder",
        description="Build a portable Unicode SQLite database of Linux man pages.",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile-name")
    parser.add_argument("--manpath", action="append", default=[])
    parser.add_argument("--locale", action="append", default=[])
    roff = parser.add_mutually_exclusive_group()
    roff.add_argument("--include-roff", dest="include_roff", action="store_true")
    roff.add_argument("--exclude-roff", dest="include_roff", action="store_false")
    parser.set_defaults(include_roff=True)
    help_group = parser.add_mutually_exclusive_group()
    help_group.add_argument("--collect-help", dest="collect_help", action="store_true")
    help_group.add_argument("--no-collect-help", dest="collect_help", action="store_false")
    parser.set_defaults(collect_help=False)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--update", action="store_true")
    mode.add_argument("--rebuild", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--strict-encoding", action="store_true")
    parser.add_argument("--max-page-size", type=int, default=16 * 1024 * 1024)
    parser.add_argument("--renderer", choices=("mandoc", "groff", "man"))
    verbosity = parser.add_mutually_exclusive_group()
    verbosity.add_argument("--verbose", action="store_true")
    verbosity.add_argument("--quiet", action="store_true")
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    args = build_parser().parse_args(argv)
    if args.max_page_size <= 0:
        build_parser().error("--max-page-size must be positive")
    return args
