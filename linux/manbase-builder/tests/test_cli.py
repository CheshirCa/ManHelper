from __future__ import annotations

import sqlite3
from pathlib import Path

from manbase_builder.main import run


def write_man(path: Path, name: str, description: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f".TH {name.upper()} 1\n"
        f".SH NAME\n{name} \\- {description}\n"
        f".SH SYNOPSIS\n.B {name}\n"
        f".SH DESCRIPTION\n{description}\n",
        encoding="utf-8",
    )


def test_cli_build_validate_update_and_rebuild(tmp_path: Path) -> None:
    root = tmp_path / "man"
    write_man(root / "man1" / "alpha.1", "alpha", "first utility")
    write_man(root / "man1" / "beta.1", "beta", "second utility")
    (root / "man1" / "alias.1").write_text(
        ".so man1/alpha.1\n", encoding="ascii"
    )
    output = tmp_path / "result.sqlite"

    assert run([
        "--output", str(output), "--profile-name", "CLI Тест",
        "--manpath", str(root), "--exclude-roff", "--collect-help", "--quiet",
    ]) == 0
    connection = sqlite3.connect(output)
    assert connection.execute("SELECT count(*) FROM pages").fetchone()[0] == 2
    assert connection.execute("SELECT count(*) FROM aliases").fetchone()[0] == 1
    assert connection.execute("SELECT count(*) FROM command_info").fetchone()[0] == 2
    assert connection.execute(
        "SELECT count(*) FROM pages WHERE roff_content IS NOT NULL"
    ).fetchone()[0] == 0
    assert connection.execute(
        "SELECT count(*) FROM page_fts WHERE page_fts MATCH 'second'"
    ).fetchone()[0] == 1
    connection.close()
    assert run(["--output", str(output), "--validate", "--quiet"]) == 0

    (root / "man1" / "beta.1").unlink()
    write_man(root / "man1" / "alpha.1", "alpha", "updated utility")
    assert run([
        "--output", str(output), "--update", "--manpath", str(root), "--quiet"
    ]) == 0
    connection = sqlite3.connect(output)
    assert connection.execute("SELECT count(*) FROM pages").fetchone()[0] == 1
    assert connection.execute(
        "SELECT count(*) FROM page_fts WHERE page_fts MATCH 'updated'"
    ).fetchone()[0] == 1
    connection.close()

    write_man(root / "man1" / "gamma.1", "gamma", "clean rebuild")
    assert run([
        "--output", str(output), "--rebuild", "--manpath", str(root), "--quiet"
    ]) == 0
    connection = sqlite3.connect(output)
    names = {row[0] for row in connection.execute("SELECT name FROM pages")}
    assert names == {"alpha", "gamma"}
    connection.close()


def test_cli_missing_update_and_validate_database(tmp_path: Path) -> None:
    missing = tmp_path / "missing.sqlite"
    assert run(["--output", str(missing), "--update", "--quiet"]) == 2
    assert run(["--output", str(missing), "--validate", "--quiet"]) == 2


def test_cli_keeps_same_name_in_different_sections(tmp_path: Path) -> None:
    root = tmp_path / "man"
    write_man(root / "man1" / "printf.1", "printf", "shell command")
    write_man(root / "man3" / "printf.3", "printf", "C library function")
    output = tmp_path / "sections.sqlite"
    assert run([
        "--output", str(output), "--manpath", str(root), "--quiet"
    ]) == 0
    connection = sqlite3.connect(output)
    assert connection.execute(
        "SELECT group_concat(section, ',') FROM "
        "(SELECT section FROM pages WHERE name='printf' ORDER BY section)"
    ).fetchone()[0] == "1,3"
    connection.close()
