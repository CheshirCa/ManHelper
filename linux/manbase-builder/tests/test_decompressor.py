from __future__ import annotations

import bz2
import gzip
import lzma
import shutil
import subprocess
from pathlib import Path

import pytest

from manbase_builder.decompressor import (
    DecompressionError,
    PageTooLargeError,
    UnsupportedCompressionError,
    read_page_bytes,
)


@pytest.mark.parametrize(
    ("suffix", "compress"),
    [
        ("", lambda value: value),
        (".gz", gzip.compress),
        (".xz", lzma.compress),
        (".bz2", bz2.compress),
    ],
)
def test_supported_formats(tmp_path: Path, suffix, compress) -> None:
    data = "Русская man page\n".encode()
    path = tmp_path / f"page.1{suffix}"
    path.write_bytes(compress(data))
    assert read_page_bytes(path, 1024) == data


def test_zstd(tmp_path: Path) -> None:
    executable = shutil.which("zstd")
    if executable is None:
        pytest.skip("system zstd is unavailable")
    source = tmp_path / "source"
    source.write_bytes(b"zstd page")
    target = tmp_path / "page.1.zst"
    subprocess.run(
        [executable, "-q", "-f", str(source), "-o", str(target)],
        check=True,
        stdin=subprocess.DEVNULL,
    )
    assert read_page_bytes(target, 100) == b"zstd page"


def test_zstd_decompressed_size_limit(tmp_path: Path) -> None:
    executable = shutil.which("zstd")
    if executable is None:
        pytest.skip("system zstd is unavailable")
    source = tmp_path / "source"
    source.write_bytes(b"x" * 1000)
    target = tmp_path / "large.1.zst"
    subprocess.run(
        [executable, "-q", "-f", str(source), "-o", str(target)],
        check=True,
        stdin=subprocess.DEVNULL,
    )
    with pytest.raises(PageTooLargeError):
        read_page_bytes(target, 10)


def test_corrupt_archives_do_not_escape_as_library_errors(tmp_path: Path) -> None:
    path = tmp_path / "broken.1.gz"
    path.write_bytes(b"not gzip")
    with pytest.raises(DecompressionError):
        read_page_bytes(path, 1024)


def test_empty_file(tmp_path: Path) -> None:
    path = tmp_path / "empty.1"
    path.write_bytes(b"")
    assert read_page_bytes(path, 1) == b""


def test_size_limit_plain_and_compressed(tmp_path: Path) -> None:
    plain = tmp_path / "large.1"
    plain.write_bytes(b"x" * 11)
    packed = tmp_path / "large.1.gz"
    packed.write_bytes(gzip.compress(b"x" * 11))
    with pytest.raises(PageTooLargeError):
        read_page_bytes(plain, 10)
    with pytest.raises(PageTooLargeError):
        read_page_bytes(packed, 10)


def test_unknown_compressed_extension(tmp_path: Path) -> None:
    path = tmp_path / "page.1.zip"
    path.write_bytes(b"PK")
    with pytest.raises(UnsupportedCompressionError):
        read_page_bytes(path, 100)
