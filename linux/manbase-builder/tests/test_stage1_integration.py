from __future__ import annotations

import gzip
from pathlib import Path

from manbase_builder.decompressor import DecompressionError, read_page_bytes
from manbase_builder.encoding import decode_bytes
from manbase_builder.manpath_scanner import scan_manpaths


def test_scan_decompress_decode_continues_after_bad_page(tmp_path: Path) -> None:
    man1 = tmp_path / "ru" / "man1"
    man1.mkdir(parents=True)
    good_text = ".TH ТЕСТ 1\n.SH ОПИСАНИЕ\nРусская программа"
    (man1 / "good.1.gz").write_bytes(gzip.compress(good_text.encode("koi8-r")))
    (man1 / "broken.1.gz").write_bytes(b"broken")

    scan = scan_manpaths([tmp_path])
    decoded = {}
    failures = []
    for page in scan.pages:
        try:
            raw = read_page_bytes(page.path, 4096)
            decoded[page.name] = decode_bytes(raw, path_locale_hint=page.locale)
        except DecompressionError as exc:
            failures.append((page.name, str(exc)))

    assert decoded["good"].text == good_text
    assert decoded["good"].source_encoding == "koi8-r"
    assert failures and failures[0][0] == "broken"
