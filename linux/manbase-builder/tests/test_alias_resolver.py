from __future__ import annotations

from pathlib import Path

import pytest

from manbase_builder.alias_resolver import resolve_aliases
from manbase_builder.manpath_scanner import scan_manpaths


def write_page(path: Path, text: str = ".TH TARGET 1\n") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def scan(root: Path):
    result = scan_manpaths([root])
    assert not result.errors
    return result.pages


def test_symlink_alias(tmp_path: Path) -> None:
    target = write_page(tmp_path / "man1" / "target.1")
    (tmp_path / "man1" / "alias.1").symlink_to(target.name)
    result = resolve_aliases(scan(tmp_path))
    assert len(result.aliases) == 1
    alias = result.aliases[0]
    assert alias.alias == "alias"
    assert alias.alias_type == "symlink"
    assert alias.target_name == "target"
    assert alias.target_path == target.absolute()


def test_mixed_chain_resolves_to_final_page(tmp_path: Path) -> None:
    final = write_page(tmp_path / "man1" / "final.1")
    write_page(tmp_path / "man1" / "middle.1", ".so man1/final.1\n")
    (tmp_path / "man1" / "start.1").symlink_to("middle.1")
    result = resolve_aliases(scan(tmp_path))
    start = next(alias for alias in result.aliases if alias.alias == "start")
    middle = next(alias for alias in result.aliases if alias.alias == "middle")
    assert start.target_path == final.absolute()
    assert start.alias_type == "symlink"
    assert len(start.chain) == 3
    assert middle.target_path == final.absolute()
    assert middle.alias_type == "so"


def test_cycle_is_reported_without_hanging(tmp_path: Path) -> None:
    write_page(tmp_path / "man1" / "a.1", ".so man1/b.1\n")
    write_page(tmp_path / "man1" / "b.1", ".so man1/a.1\n")
    result = resolve_aliases(scan(tmp_path))
    assert result.aliases == []
    assert len(result.errors) == 2
    assert {error.error_code for error in result.errors} == {"alias_cycle"}


def test_so_existing_and_missing_targets(tmp_path: Path) -> None:
    target = write_page(tmp_path / "man3" / "function.3")
    write_page(tmp_path / "man1" / "command.1", ".so man3/function.3\n")
    write_page(tmp_path / "man1" / "missing.1", ".so man1/absent.1\n")
    result = resolve_aliases(scan(tmp_path))
    command = next(alias for alias in result.aliases if alias.alias == "command")
    assert command.target_path == target.absolute()
    assert command.target_section == "3"
    assert any(
        error.source_path.name == "missing.1"
        and error.error_code == "alias_target_missing"
        for error in result.errors
    )


def test_same_alias_in_sections_and_locales_stays_separate(tmp_path: Path) -> None:
    write_page(tmp_path / "man1" / "target.1")
    write_page(tmp_path / "man3" / "target.3")
    write_page(tmp_path / "man1" / "same.1", ".so man1/target.1\n")
    write_page(tmp_path / "man3" / "same.3", ".so man3/target.3\n")
    write_page(tmp_path / "ru" / "man1" / "target.1")
    write_page(tmp_path / "ru" / "man1" / "same.1", ".so man1/target.1\n")
    result = resolve_aliases(scan(tmp_path))
    same = [alias for alias in result.aliases if alias.alias == "same"]
    assert len(same) == 3
    assert {(alias.alias_section, alias.alias_locale) for alias in same} == {
        ("1", None),
        ("3", None),
        ("1", "ru"),
    }
    ru_alias = next(alias for alias in same if alias.alias_locale == "ru")
    assert "/ru/man1/" in str(ru_alias.target_path)


def test_compressed_target_is_found_by_logical_name(tmp_path: Path) -> None:
    import gzip

    target = tmp_path / "man1" / "target.1.gz"
    target.parent.mkdir(parents=True)
    target.write_bytes(gzip.compress(b".TH TARGET 1\n"))
    write_page(tmp_path / "man1" / "alias.1", ".so man1/target.1\n")
    result = resolve_aliases(scan(tmp_path))
    assert result.aliases[0].target_path == target.absolute()


def test_chain_limit_and_invalid_limit(tmp_path: Path) -> None:
    write_page(tmp_path / "man1" / "final.1")
    write_page(tmp_path / "man1" / "one.1", ".so man1/final.1\n")
    write_page(tmp_path / "man1" / "zero.1", ".so man1/one.1\n")
    result = resolve_aliases(scan(tmp_path), max_chain_length=1)
    assert any(error.error_code == "alias_chain_too_long" for error in result.errors)
    with pytest.raises(ValueError):
        resolve_aliases([], max_chain_length=0)
    with pytest.raises(ValueError):
        resolve_aliases([], max_page_size=0)


def test_roff_content_can_be_supplied_without_reading_source(tmp_path: Path) -> None:
    target = write_page(tmp_path / "man1" / "target.1")
    alias_path = write_page(tmp_path / "man1" / "alias.1", "not an alias on disk")
    pages = scan(tmp_path)
    result = resolve_aliases(
        pages, roff_contents={alias_path.absolute(): ".so man1/target.1\n"}
    )
    assert result.aliases[0].target_path == target.absolute()


def test_symlink_through_external_alternatives_path(tmp_path: Path) -> None:
    target = write_page(tmp_path / "man1" / "target.1")
    alternatives = tmp_path / "alternatives"
    alternatives.mkdir()
    external = alternatives / "command.1"
    external.symlink_to(target)
    alias_path = tmp_path / "man1" / "alias.1"
    alias_path.symlink_to(external)

    result = resolve_aliases(scan(tmp_path))
    alias = next(item for item in result.aliases if item.alias == "alias")
    assert alias.target_path == target.absolute()
    assert external in alias.chain
