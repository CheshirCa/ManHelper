from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import pytest

from manbase_builder.database_checks import check_database
from manbase_builder.database_schema import (
    IncompatibleSchemaError,
    initialize_database,
)
from manbase_builder.database_writer import DatabaseWriter
from manbase_builder.models import (
    AliasWrite, PageWrite, ParsedSection, RelationWrite, SystemProfile,
)


def profile() -> SystemProfile:
    return SystemProfile(
        distribution="Debian GNU/Linux",
        version="13",
        codename="trixie",
        architecture="amd64",
        kernel="6.12",
        hostname="тест",
        system_locale="ru_RU.UTF-8",
        available_locales=("C.UTF-8", "ru_RU.UTF-8"),
        package_manager="dpkg",
        builder_version="0.1.0",
        created_at=datetime.now(timezone.utc),
        profile_name="Debian Тест",
    )


def page(profile_id: int, *, text: str = "Русское описание") -> PageWrite:
    return PageWrite(
        profile_id=profile_id,
        name="пример",
        section="1",
        language="ru",
        imported_at=datetime.now(timezone.utc),
        content_hash="abc123",
        title="Пример",
        summary="тестовая команда",
        plain_text=text,
        source_encoding="utf-8",
        renderer="groff",
    )


@pytest.fixture
def database():
    connection = sqlite3.connect(":memory:")
    initialize_database(connection)
    yield connection
    connection.close()


def test_creation_repeat_and_required_meta(database) -> None:
    initialize_database(database)
    initialize_database(database)
    tables = {
        row[0]
        for row in database.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
        )
    }
    assert {"meta", "profiles", "pages", "sections", "aliases", "page_fts"} <= tables
    meta = dict(database.execute("SELECT key, value FROM meta"))
    assert meta["schema_version"] == "1"
    assert meta["text_encoding"] == "UTF-8"
    assert meta["unicode_normalization"] == "NFC"
    assert check_database(database).ok


def test_migration_from_unversioned_meta() -> None:
    connection = sqlite3.connect(":memory:")
    connection.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    connection.execute("INSERT INTO meta VALUES('schema_version', '0')")
    connection.commit()
    initialize_database(connection)
    assert connection.execute(
        "SELECT value FROM meta WHERE key='schema_version'"
    ).fetchone()[0] == "1"
    connection.close()


def test_incompatible_newer_schema() -> None:
    connection = sqlite3.connect(":memory:")
    connection.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    connection.execute("INSERT INTO meta VALUES('schema_version', '999')")
    connection.commit()
    with pytest.raises(IncompatibleSchemaError):
        initialize_database(connection)


def test_schema_rejects_active_transaction() -> None:
    connection = sqlite3.connect(":memory:")
    connection.execute("CREATE TABLE existing(value TEXT)")
    connection.execute("INSERT INTO existing VALUES ('uncommitted')")
    with pytest.raises(RuntimeError, match="active transaction"):
        initialize_database(connection)
    connection.rollback()
    connection.close()


def test_transactional_write_fts_unicode_and_repeat_update(database) -> None:
    writer = DatabaseWriter(database)
    with writer.transaction():
        profile_id = writer.write_profile(profile())
        package_id = writer.write_package("demo", "1.0", "amd64", "dpkg")
        item = page(profile_id)
        item = PageWrite(**{**item.__dict__, "package_id": package_id}) if hasattr(item, "__dict__") else PageWrite(
            profile_id=profile_id, package_id=package_id, name=item.name,
            section=item.section, language=item.language, imported_at=item.imported_at,
            content_hash=item.content_hash, title=item.title, summary=item.summary,
            plain_text=item.plain_text, source_encoding=item.source_encoding,
            renderer=item.renderer,
        )
        page_id = writer.write_page(
            item,
            sections=(
                ParsedSection(0, "ИМЯ", "NAME", "пример — команда"),
                ParsedSection(1, "ОПИСАНИЕ", "DESCRIPTION", "Поиск кириллицы"),
            ),
            aliases=(AliasWrite("example", "so", "1", "en"),),
            relations=(RelationWrite("printf", "3", "see_also"),),
        )
        writer.write_page(
            page(profile_id, text="Обновлённый русский текст"),
            sections=(ParsedSection(0, "ОПИСАНИЕ", "DESCRIPTION", "Новая секция"),),
        )
        writer.finalize()

    assert database.execute("SELECT count(*) FROM pages").fetchone()[0] == 1
    assert database.execute("SELECT count(*) FROM sections").fetchone()[0] == 1
    assert database.execute("SELECT count(*) FROM relations").fetchone()[0] == 0
    assert database.execute(
        "SELECT count(*) FROM page_fts WHERE page_fts MATCH ?", ("русский",)
    ).fetchone()[0] == 1
    assert database.execute(
        "SELECT count(*) FROM page_fts WHERE page_fts MATCH ?", ("Новая",)
    ).fetchone()[0] == 1
    assert page_id > 0
    assert check_database(database).ok


def test_package_identity_with_null_fields_is_unique(database) -> None:
    writer = DatabaseWriter(database)
    with writer.transaction():
        first = writer.write_package("local", None, None, None)
        second = writer.write_package("local", None, None, None)
    assert first == second
    assert database.execute("SELECT count(*) FROM packages").fetchone()[0] == 1


def test_rollback_on_error(database) -> None:
    writer = DatabaseWriter(database)
    with pytest.raises(RuntimeError):
        with writer.transaction():
            writer.write_profile(profile())
            raise RuntimeError("fixture")
    assert database.execute("SELECT count(*) FROM profiles").fetchone()[0] == 0


def test_foreign_keys_and_checksum_failures_are_detected(database) -> None:
    writer = DatabaseWriter(database)
    with writer.transaction():
        profile_id = writer.write_profile(profile())
        writer.write_page(page(profile_id))
        writer.finalize()
    database.execute("UPDATE pages SET content_hash='changed'")
    result = check_database(database)
    assert not result.ok
    assert not result.checksum_valid

    database.commit()
    database.execute("PRAGMA foreign_keys=OFF")
    database.execute("UPDATE pages SET profile_id=999")
    database.commit()
    result = check_database(database)
    assert result.foreign_key_errors


def test_page_delete_removes_fts(database) -> None:
    writer = DatabaseWriter(database)
    with writer.transaction():
        profile_id = writer.write_profile(profile())
        page_id = writer.write_page(page(profile_id))
    database.execute("DELETE FROM pages WHERE id=?", (page_id,))
    assert database.execute("SELECT count(*) FROM page_fts").fetchone()[0] == 0


def test_writer_rolls_back_fk_error(database) -> None:
    writer = DatabaseWriter(database)
    with pytest.raises(sqlite3.IntegrityError):
        with writer.transaction():
            writer.write_page(page(999))
    assert database.execute("SELECT count(*) FROM pages").fetchone()[0] == 0
