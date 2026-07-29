"""Built-in structural, relational, checksum and FTS checks."""

from __future__ import annotations

import hashlib
import sqlite3

from .database_schema import SCHEMA_VERSION, get_meta
from .models import DatabaseCheckResult


def _checksum(connection: sqlite3.Connection) -> str:
    digest = hashlib.sha256()
    for row in connection.execute("SELECT id, content_hash FROM pages ORDER BY id"):
        digest.update(f"{row[0]}:{row[1]}\n".encode())
    return digest.hexdigest()


def check_database(connection: sqlite3.Connection) -> DatabaseCheckResult:
    errors: list[str] = []
    integrity = str(connection.execute("PRAGMA integrity_check").fetchone()[0])
    if integrity != "ok":
        errors.append(f"integrity_check: {integrity}")
    foreign_keys = tuple(
        tuple(row) for row in connection.execute("PRAGMA foreign_key_check")
    )
    if foreign_keys:
        errors.append(f"foreign_key_check: {len(foreign_keys)} error(s)")
    raw_schema = get_meta(connection, "schema_version")
    try:
        schema_version = int(raw_schema) if raw_schema is not None else None
    except ValueError:
        schema_version = None
    if schema_version != SCHEMA_VERSION:
        errors.append(f"schema_version: {raw_schema}")
    expected = get_meta(connection, "content_checksum") or ""
    checksum_valid = expected == _checksum(connection)
    if not checksum_valid:
        errors.append("content_checksum mismatch")
    try:
        connection.execute("SELECT count(*) FROM page_fts").fetchone()
        fts_available = True
    except sqlite3.DatabaseError:
        fts_available = False
        errors.append("FTS5 unavailable")
    return DatabaseCheckResult(
        ok=not errors,
        integrity=integrity,
        foreign_key_errors=foreign_keys,
        schema_version=schema_version,
        checksum_valid=checksum_valid,
        fts_available=fts_available,
        errors=tuple(errors),
    )
