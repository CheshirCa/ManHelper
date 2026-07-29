"""Bounded decompression of manual-page sources."""

from __future__ import annotations

import bz2
import gzip
import lzma
import shutil
from pathlib import Path
from typing import BinaryIO

from .subprocess_utils import BoundedProcessError, run_bounded

class DecompressionError(Exception):
    """Base error for one page that could not be decompressed."""


class PageTooLargeError(DecompressionError):
    """The decompressed page exceeds the configured safety limit."""


class UnsupportedCompressionError(DecompressionError):
    """The filename has an unsupported compression suffix."""


def compression_for_path(path: Path) -> str:
    suffix = path.suffix.lower()
    return {
        ".gz": "gzip",
        ".xz": "xz",
        ".bz2": "bzip2",
        ".zst": "zstd",
    }.get(suffix, "plain" if suffix not in {".zip", ".lz", ".lz4", ".7z"} else "unknown")


def _bounded_read(stream: BinaryIO, max_size: int) -> bytes:
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = stream.read(min(64 * 1024, max_size - total + 1))
        if not chunk:
            return b"".join(chunks)
        total += len(chunk)
        if total > max_size:
            raise PageTooLargeError(f"decompressed content exceeds {max_size} bytes")
        chunks.append(chunk)


def _read_zstd(path: Path, max_size: int) -> bytes:
    try:
        import zstandard  # type: ignore[import-not-found]
    except ImportError:
        zstandard = None
    if zstandard is not None:
        with path.open("rb") as source:
            with zstandard.ZstdDecompressor().stream_reader(source) as stream:
                return _bounded_read(stream, max_size)

    executable = shutil.which("zstd")
    if not executable:
        raise UnsupportedCompressionError(
            "zstd support requires the zstandard package or system zstd"
        )
    try:
        result = run_bounded(
            [executable, "--decompress", "--stdout", "--quiet", str(path)],
            timeout=10,
            max_output=max_size,
        )
    except BoundedProcessError as exc:
        if exc.code == "output_limit":
            raise PageTooLargeError(
                f"decompressed content exceeds {max_size} bytes"
            ) from exc
        raise DecompressionError(f"zstd {exc.code} while reading {path}") from exc
    if result.returncode != 0:
        raise DecompressionError(
            f"zstd failed with exit code {result.returncode}: "
            f"{result.stderr[:4096].decode('utf-8', 'replace').strip()}"
        )
    return result.stdout


def read_page_bytes(path: Path | str, max_size: int) -> bytes:
    """Return original uncompressed bytes, never more than *max_size*."""

    source = Path(path)
    if max_size <= 0:
        raise ValueError("max_size must be positive")
    compression = compression_for_path(source)
    try:
        if compression == "plain":
            with source.open("rb") as stream:
                return _bounded_read(stream, max_size)
        if compression == "gzip":
            with gzip.open(source, "rb") as stream:
                return _bounded_read(stream, max_size)
        if compression == "xz":
            with lzma.open(source, "rb") as stream:
                return _bounded_read(stream, max_size)
        if compression == "bzip2":
            with bz2.open(source, "rb") as stream:
                return _bounded_read(stream, max_size)
        if compression == "zstd":
            return _read_zstd(source, max_size)
        raise UnsupportedCompressionError(f"unsupported compression suffix: {source.suffix}")
    except (DecompressionError, OSError) as exc:
        if isinstance(exc, DecompressionError):
            raise
        raise DecompressionError(f"cannot read {source}: {exc}") from exc
    except (gzip.BadGzipFile, lzma.LZMAError, EOFError) as exc:
        raise DecompressionError(f"corrupt compressed file {source}: {exc}") from exc
