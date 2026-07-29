from __future__ import annotations

import sqlite3
from datetime import datetime, timezone

import pytest

from manbase_builder.database_schema import initialize_database
from manbase_builder.database_updater import DatabaseUpdater
from manbase_builder.database_writer import DatabaseWriter
from manbase_builder.models import PageBundle, PageWrite, SystemProfile


def make_page(profile_id: int, name: str, content_hash: str) -> PageWrite:
    return PageWrite(
        profile_id=profile_id, name=name, section="1", language="en",
        imported_at=datetime.now(timezone.utc), content_hash=content_hash,
        plain_text=f"{name} documentation",
    )


@pytest.fixture
def setup_db():
    connection = sqlite3.connect(":memory:")
    initialize_database(connection)
    writer = DatabaseWriter(connection)
    with writer.transaction():
        profile_id = writer.write_profile(SystemProfile(
            "Debian", "13", None, "amd64", "kernel", "host", "C.UTF-8", (),
            "dpkg", "test", datetime.now(timezone.utc), "test",
        ))
    yield connection, profile_id
    connection.close()


def test_update_changes_adds_and_removes_pages(setup_db) -> None:
    connection, profile_id = setup_db
    updater = DatabaseUpdater(connection)
    updater.apply(profile_id, [
        PageBundle(make_page(profile_id, "old", "1")),
        PageBundle(make_page(profile_id, "keep", "1")),
    ])
    result = updater.apply(profile_id, [
        PageBundle(make_page(profile_id, "keep", "2")),
        PageBundle(make_page(profile_id, "new", "1")),
    ])
    assert result.written == 2
    assert result.removed == 1
    assert set(row[0] for row in connection.execute("SELECT name FROM pages")) == {
        "keep", "new"
    }
    assert connection.execute(
        "SELECT content_hash FROM pages WHERE name='keep'"
    ).fetchone()[0] == "2"
    assert connection.execute("SELECT count(*) FROM page_fts").fetchone()[0] == 2


def test_rebuild_and_keep_missing_modes(setup_db) -> None:
    connection, profile_id = setup_db
    updater = DatabaseUpdater(connection)
    updater.apply(profile_id, [PageBundle(make_page(profile_id, "a", "1"))])
    updater.apply(
        profile_id, [PageBundle(make_page(profile_id, "b", "1"))],
        remove_missing=False,
    )
    assert connection.execute("SELECT count(*) FROM pages").fetchone()[0] == 2
    result = updater.apply(
        profile_id, [PageBundle(make_page(profile_id, "clean", "1"))],
        rebuild=True,
    )
    assert result.removed == 2
    assert connection.execute("SELECT name FROM pages").fetchone()[0] == "clean"


def test_wrong_profile_rejected(setup_db) -> None:
    connection, profile_id = setup_db
    with pytest.raises(ValueError):
        DatabaseUpdater(connection).apply(
            profile_id, [PageBundle(make_page(profile_id + 1, "bad", "1"))]
        )
