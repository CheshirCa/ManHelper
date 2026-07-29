"""SQLite schema, metadata and forward-only migrations."""

from __future__ import annotations

import hashlib
import sqlite3
from datetime import datetime, timezone

SCHEMA_VERSION = 1
DATABASE_FORMAT = "manbase-sqlite"
DATABASE_FORMAT_VERSION = "1"
MINIMUM_CLIENT_VERSION = "0.1.0"

_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS profiles (
    id INTEGER PRIMARY KEY,
    profile_name TEXT NOT NULL,
    distribution TEXT,
    distribution_version TEXT,
    distribution_codename TEXT,
    architecture TEXT,
    kernel TEXT,
    hostname TEXT,
    system_locale TEXT,
    available_locales TEXT,
    package_manager TEXT,
    created_at TEXT NOT NULL,
    builder_version TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS packages (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT,
    architecture TEXT,
    manager TEXT,
    description TEXT,
    UNIQUE(name, version, architecture, manager)
);
CREATE TABLE IF NOT EXISTS pages (
    id INTEGER PRIMARY KEY,
    profile_id INTEGER NOT NULL,
    package_id INTEGER,
    name TEXT NOT NULL,
    section TEXT NOT NULL,
    title TEXT,
    summary TEXT,
    source_path TEXT,
    executable_path TEXT,
    program_version TEXT,
    language TEXT NOT NULL,
    locale TEXT,
    source_encoding TEXT,
    decode_status TEXT NOT NULL,
    decode_error_count INTEGER NOT NULL DEFAULT 0,
    contains_replacement_chars INTEGER NOT NULL DEFAULT 0,
    roff_content TEXT,
    plain_text TEXT,
    renderer TEXT,
    imported_at TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    FOREIGN KEY(profile_id) REFERENCES profiles(id),
    FOREIGN KEY(package_id) REFERENCES packages(id),
    UNIQUE(profile_id, name, section, language, locale)
);
CREATE UNIQUE INDEX IF NOT EXISTS packages_identity_idx
ON packages(name, COALESCE(version, ''), COALESCE(architecture, ''),
            COALESCE(manager, ''));
CREATE TABLE IF NOT EXISTS sections (
    id INTEGER PRIMARY KEY,
    page_id INTEGER NOT NULL,
    section_order INTEGER NOT NULL,
    original_name TEXT,
    normalized_name TEXT NOT NULL,
    content TEXT NOT NULL,
    FOREIGN KEY(page_id) REFERENCES pages(id) ON DELETE CASCADE,
    UNIQUE(page_id, section_order)
);
CREATE UNIQUE INDEX IF NOT EXISTS pages_identity_idx
ON pages(profile_id, name, section, language, COALESCE(locale, ''));
CREATE TABLE IF NOT EXISTS aliases (
    id INTEGER PRIMARY KEY,
    page_id INTEGER NOT NULL,
    alias TEXT NOT NULL,
    alias_type TEXT NOT NULL,
    alias_section TEXT,
    alias_language TEXT,
    FOREIGN KEY(page_id) REFERENCES pages(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS relations (
    id INTEGER PRIMARY KEY,
    source_page_id INTEGER NOT NULL,
    target_name TEXT NOT NULL,
    target_section TEXT,
    relation_type TEXT NOT NULL,
    FOREIGN KEY(source_page_id) REFERENCES pages(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS command_info (
    id INTEGER PRIMARY KEY,
    page_id INTEGER NOT NULL,
    command_name TEXT NOT NULL,
    command_path TEXT,
    command_type TEXT,
    version_text TEXT,
    help_text TEXT,
    is_available INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY(page_id) REFERENCES pages(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS build_errors (
    id INTEGER PRIMARY KEY,
    source_path TEXT,
    stage TEXT NOT NULL,
    error_code TEXT,
    message TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE VIRTUAL TABLE IF NOT EXISTS page_fts USING fts5(
    page_id UNINDEXED,
    name,
    title,
    summary,
    plain_text,
    sections_content,
    tokenize='unicode61'
);
CREATE TRIGGER IF NOT EXISTS pages_fts_delete AFTER DELETE ON pages BEGIN
    DELETE FROM page_fts WHERE page_id = OLD.id;
END;
"""


class IncompatibleSchemaError(RuntimeError):
    pass


def set_meta(connection: sqlite3.Connection, key: str, value: str) -> None:
    connection.execute(
        "INSERT INTO meta(key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (key, value),
    )


def get_meta(connection: sqlite3.Connection, key: str) -> str | None:
    row = connection.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    return None if row is None else str(row[0])


def initialize_database(
    connection: sqlite3.Connection, *, builder_version: str = "0.1.0"
) -> None:
    """Create or migrate a database and enable mandatory connection settings."""

    if connection.in_transaction:
        raise RuntimeError("schema initialization requires no active transaction")
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    connection.commit()
    raw_version = get_meta(connection, "schema_version")
    try:
        existing_version = int(raw_version) if raw_version is not None else 0
    except ValueError as exc:
        raise IncompatibleSchemaError(f"invalid schema version: {raw_version}") from exc
    if existing_version > SCHEMA_VERSION:
        raise IncompatibleSchemaError(
            f"database schema {existing_version} is newer than supported {SCHEMA_VERSION}"
        )
    try:
        connection.executescript("BEGIN IMMEDIATE;\n" + _SCHEMA_SQL)
        now = datetime.now(timezone.utc).isoformat()
        defaults = {
            "database_format": DATABASE_FORMAT_VERSION,
            "schema_version": str(SCHEMA_VERSION),
            "builder_name": "ManBase Builder",
            "builder_version": builder_version,
            "created_at": now,
            "updated_at": now,
            "text_encoding": "UTF-8",
            "unicode_normalization": "NFC",
            "fts_version": "FTS5 unicode61",
            "minimum_client_version": MINIMUM_CLIENT_VERSION,
            "profile_id": "",
            "content_checksum": hashlib.sha256(b"").hexdigest(),
            "capabilities": "fts5,unicode,sections,aliases",
        }
        for key, value in defaults.items():
            connection.execute(
                "INSERT OR IGNORE INTO meta(key, value) VALUES (?, ?)", (key, value)
            )
        set_meta(connection, "schema_version", str(SCHEMA_VERSION))
        set_meta(connection, "builder_version", builder_version)
        connection.commit()
    except BaseException:
        connection.rollback()
        raise


def connect_database(path: str) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    initialize_database(connection)
    return connection


def refresh_page_fts(connection: sqlite3.Connection, page_id: int) -> None:
    connection.execute("DELETE FROM page_fts WHERE page_id = ?", (page_id,))
    connection.execute(
        """
        INSERT INTO page_fts(page_id, name, title, summary, plain_text, sections_content)
        SELECT p.id, p.name, COALESCE(p.title, ''), COALESCE(p.summary, ''),
               COALESCE(p.plain_text, ''),
               COALESCE((SELECT group_concat(s.content, char(10))
                         FROM sections s WHERE s.page_id = p.id
                         ORDER BY s.section_order), '')
        FROM pages p WHERE p.id = ?
        """,
        (page_id,),
    )
