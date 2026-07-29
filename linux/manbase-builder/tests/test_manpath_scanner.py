from __future__ import annotations

from pathlib import Path

from manbase_builder.manpath_scanner import discover_manpaths, scan_manpaths


def touch(path: Path, content: bytes = b".TH TEST 1\n") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return path


def test_single_path_plain_and_compressed_pages(tmp_path: Path) -> None:
    touch(tmp_path / "man1" / "ls.1")
    touch(tmp_path / "man5" / "fstab.5.gz")
    result = scan_manpaths([tmp_path])
    assert [(page.name, page.section, page.compression) for page in result.pages] == [
        ("ls", "1", "plain"),
        ("fstab", "5", "gzip"),
    ]


def test_duplicate_roots_do_not_duplicate_pages(tmp_path: Path) -> None:
    touch(tmp_path / "man1" / "grep.1.xz")
    result = scan_manpaths([tmp_path, tmp_path, str(tmp_path)])
    assert len(result.pages) == 1


def test_locales_remain_separate(tmp_path: Path) -> None:
    touch(tmp_path / "ru" / "man1" / "echo.1")
    touch(tmp_path / "ru.UTF-8" / "man1" / "echo.1.gz")
    touch(tmp_path / "en" / "man1" / "echo.1.bz2")
    result = scan_manpaths([tmp_path])
    assert {(p.language, p.locale) for p in result.pages} == {
        ("ru", "ru"),
        ("ru", "ru.UTF-8"),
        ("en", "en"),
    }


def test_name_with_dots_and_nonstandard_sections(tmp_path: Path) -> None:
    touch(tmp_path / "man1" / "foo.bar.1.zst")
    touch(tmp_path / "mann" / "tcl.command.n")
    touch(tmp_path / "manl" / "local.tool.l")
    pages = scan_manpaths([tmp_path]).pages
    assert {(p.name, p.section) for p in pages} == {
        ("foo.bar", "1"),
        ("tcl.command", "n"),
        ("local.tool", "l"),
    }


def test_symlink_is_preserved(tmp_path: Path) -> None:
    target = touch(tmp_path / "man1" / "target.1")
    alias = tmp_path / "man1" / "alias.1"
    alias.symlink_to(target.name)
    pages = scan_manpaths([tmp_path]).pages
    alias_page = next(page for page in pages if page.name == "alias")
    assert alias_page.is_symlink
    assert alias_page.path == alias.absolute()


def test_missing_directory_is_nonfatal(tmp_path: Path) -> None:
    result = scan_manpaths([tmp_path / "missing"])
    assert result.pages == []
    assert result.errors[0].operation == "missing-root"


def test_permission_error_is_nonfatal(tmp_path: Path, monkeypatch) -> None:
    original_iterdir = Path.iterdir

    def denied(path: Path):
        if path == tmp_path:
            raise PermissionError("denied by fixture")
        return original_iterdir(path)

    monkeypatch.setattr(Path, "iterdir", denied)
    result = scan_manpaths([tmp_path])
    assert result.pages == []
    assert result.errors[0].operation == "list-root"
    assert "denied" in result.errors[0].message


def test_discover_paths_deduplicates_explicit_paths(tmp_path: Path) -> None:
    paths = discover_manpaths(
        [tmp_path, str(tmp_path)], include_defaults=False, manpath_executable="/missing"
    )
    assert paths == (tmp_path.absolute(),)
