from __future__ import annotations

import gzip
import shutil
from pathlib import Path

import pytest

from manbase_builder.alias_resolver import resolve_aliases
from manbase_builder.decompressor import read_page_bytes
from manbase_builder.encoding import decode_bytes
from manbase_builder.manpath_scanner import scan_manpaths
from manbase_builder.roff_renderer import render_roff
from manbase_builder.section_parser import parse_sections


def test_scan_decode_render_parse_and_alias_pipeline(tmp_path: Path) -> None:
    if shutil.which("groff") is None:
        pytest.skip("integration test requires groff")
    man1 = tmp_path / "ru" / "man1"
    man1.mkdir(parents=True)
    roff = (
        ".TH ПРИВЕТ 1\n"
        ".SH ИМЯ\n"
        "privet \\- тестовая программа\n"
        ".SH СИНТАКСИС\n"
        ".B privet\n"
        ".RI [ файл ]\n"
        ".SH ОПИСАНИЕ\n"
        "Программа выводит русский текст.\n"
    )
    target = man1 / "privet.1.gz"
    target.write_bytes(gzip.compress(roff.encode("cp1251")))
    alias = man1 / "hello.1"
    alias.write_text(".so man1/privet.1\n", encoding="ascii")

    scan = scan_manpaths([tmp_path])
    assert len(scan.pages) == 2
    target_page = next(page for page in scan.pages if page.name == "privet")
    decoded = decode_bytes(
        read_page_bytes(target_page.path, 4096),
        path_locale_hint="ru_RU.CP1251",
    )
    rendered = render_roff(decoded.text, preferred="groff")
    parsed = parse_sections(rendered.plain_text or "")
    aliases = resolve_aliases(scan.pages)

    assert rendered.success
    assert rendered.renderer == "groff"
    assert "русский текст" in (rendered.plain_text or "")
    assert parsed.summary == "тестовая программа"
    assert parsed.synopsis and "privet" in parsed.synopsis
    assert {"NAME", "SYNOPSIS", "DESCRIPTION"}.issubset(
        {section.normalized_name for section in parsed.sections}
    )
    resolved = next(item for item in aliases.aliases if item.alias == "hello")
    assert resolved.alias_locale == "ru"
    assert resolved.target_path == target.absolute()
    assert not aliases.errors
