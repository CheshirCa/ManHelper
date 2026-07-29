from __future__ import annotations

import gzip
import sqlite3
from pathlib import Path

from manbase_builder.main import run


def roff(name: str, heading: str, description: str) -> str:
    return (
        f".TH {name.upper()} 1\n"
        f".SH {heading}\n{name} \\- {description}\n"
        f".SH {'СИНТАКСИС' if heading == 'ИМЯ' else 'SYNOPSIS'}\n.B {name}\n"
        f".SH {'ОПИСАНИЕ' if heading == 'ИМЯ' else 'DESCRIPTION'}\n{description}\n"
        f".SH {'СМОТРИ ТАКЖЕ' if heading == 'ИМЯ' else 'SEE ALSO'}\nprintf(1), printf(3)\n"
    )


def test_complete_problem_fixture_set_in_one_cli_build(tmp_path: Path) -> None:
    root = tmp_path / "man"
    english = root / "man1"
    cp1251 = root / "ru.CP1251" / "man1"
    koi8 = root / "ru.KOI8-R" / "man1"
    english.mkdir(parents=True)
    cp1251.mkdir(parents=True)
    koi8.mkdir(parents=True)

    (english / "english.1").write_text(
        roff("english", "NAME", "English utility"), encoding="utf-8"
    )
    (english / "local.1").write_text(
        roff("local", "NAME", "file without package"), encoding="utf-8"
    )
    (english / "alias.1").write_text(".so man1/english.1\n", encoding="ascii")
    (english / "broken.1.gz").write_bytes(b"not a gzip stream")
    cp_text = roff("cptext", "ИМЯ", "Программа в кодировке CP1251")
    (cp1251 / "cptext.1.gz").write_bytes(gzip.compress(cp_text.encode("cp1251")))
    koi_text = roff("koitext", "ИМЯ", "Программа в кодировке KOI8-R")
    (koi8 / "koitext.1").write_bytes(koi_text.encode("koi8-r"))

    output = tmp_path / "acceptance.sqlite"
    assert run([
        "--output", str(output), "--manpath", str(root), "--quiet"
    ]) == 0
    connection = sqlite3.connect(output)
    assert connection.execute("SELECT count(*) FROM pages").fetchone()[0] == 4
    assert connection.execute("SELECT count(*) FROM aliases").fetchone()[0] == 1
    assert connection.execute(
        "SELECT count(*) FROM build_errors WHERE source_path LIKE '%broken.1.gz'"
    ).fetchone()[0] >= 1
    assert dict(connection.execute(
        "SELECT name, source_encoding FROM pages WHERE name IN ('cptext','koitext')"
    )) == {"cptext": "cp1251", "koitext": "koi8-r"}
    assert connection.execute(
        "SELECT count(*) FROM page_fts WHERE page_fts MATCH 'Программа'"
    ).fetchone()[0] == 2
    assert connection.execute(
        "SELECT count(*) FROM relations WHERE relation_type='see_also'"
    ).fetchone()[0] == 8
    assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert not connection.execute("PRAGMA foreign_key_check").fetchall()
    connection.close()
