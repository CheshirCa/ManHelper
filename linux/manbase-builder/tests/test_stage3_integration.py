from __future__ import annotations

import hashlib
import sqlite3
from datetime import datetime, timezone

from manbase_builder.database_checks import check_database
from manbase_builder.database_schema import initialize_database
from manbase_builder.database_writer import DatabaseWriter
from manbase_builder.models import PageWrite, SystemProfile
from manbase_builder.section_parser import parse_sections


def test_persistent_database_with_unicode_fts(tmp_path) -> None:
    path = tmp_path / "manbase.sqlite"
    connection = sqlite3.connect(path)
    initialize_database(connection, builder_version="test")
    writer = DatabaseWriter(connection)
    rendered = (
        "ИМЯ\n    пример — тестовая команда\n"
        "СИНТАКСИС\n    пример [файл]\n"
        "ОПИСАНИЕ\n    Проверяет переносимую базу документации.\n"
    )
    parsed = parse_sections(rendered)
    profile = SystemProfile(
        "Debian", "13", "trixie", "amd64", "6.12", "host", "ru_RU.UTF-8",
        ("ru_RU.UTF-8",), "dpkg", "test", datetime.now(timezone.utc), "Тест",
    )
    with writer.transaction():
        profile_id = writer.write_profile(profile)
        writer.write_page(
            PageWrite(
                profile_id=profile_id,
                name="пример",
                section="1",
                language="ru",
                imported_at=datetime.now(timezone.utc),
                content_hash=hashlib.sha256(rendered.encode()).hexdigest(),
                summary=parsed.summary,
                plain_text=rendered,
            ),
            sections=parsed.sections,
        )
        writer.finalize()
    assert check_database(connection).ok
    connection.close()

    reopened = sqlite3.connect(path)
    reopened.execute("PRAGMA foreign_keys=ON")
    assert reopened.execute(
        "SELECT name FROM page_fts WHERE page_fts MATCH ?", ("переносимую",)
    ).fetchone()[0] == "пример"
    assert check_database(reopened).ok
    reopened.close()
