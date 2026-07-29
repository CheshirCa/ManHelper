"""Transactional, parameterized writes to a ManBase database."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from datetime import datetime, timezone

from .database_schema import refresh_page_fts, set_meta
from .models import (
    AliasWrite,
    PageWrite,
    ParsedSection,
    RelationWrite,
    SystemProfile,
)


def _timestamp(value: datetime) -> str:
    return value.isoformat()


class DatabaseWriter:
    def __init__(self, connection: sqlite3.Connection) -> None:
        self.connection = connection
        self.connection.execute("PRAGMA foreign_keys = ON")

    @contextmanager
    def transaction(self) -> Iterator["DatabaseWriter"]:
        if self.connection.in_transaction:
            raise RuntimeError("nested transactions are not supported")
        self.connection.execute("BEGIN IMMEDIATE")
        try:
            yield self
        except BaseException:
            self.connection.rollback()
            raise
        else:
            self.connection.commit()

    def write_profile(self, profile: SystemProfile) -> int:
        cursor = self.connection.execute(
            """
            INSERT INTO profiles(
                profile_name, distribution, distribution_version,
                distribution_codename, architecture, kernel, hostname,
                system_locale, available_locales, package_manager, created_at,
                builder_version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                profile.profile_name or profile.distribution,
                profile.distribution, profile.version, profile.codename,
                profile.architecture, profile.kernel, profile.hostname,
                profile.system_locale,
                json.dumps(profile.available_locales, ensure_ascii=False),
                profile.package_manager, _timestamp(profile.created_at),
                profile.builder_version,
            ),
        )
        profile_id = int(cursor.lastrowid)
        set_meta(self.connection, "profile_id", str(profile_id))
        return profile_id

    def write_package(
        self,
        name: str,
        version: str | None,
        architecture: str | None,
        manager: str | None,
        description: str | None = None,
    ) -> int:
        self.connection.execute(
            "INSERT OR IGNORE INTO packages(name, version, architecture, manager, description) "
            "VALUES (?, ?, ?, ?, ?)",
            (name, version, architecture, manager, description),
        )
        row = self.connection.execute(
            "SELECT id FROM packages WHERE name=? AND version IS ? "
            "AND architecture IS ? AND manager IS ?",
            (name, version, architecture, manager),
        ).fetchone()
        assert row is not None
        return int(row[0])

    def write_page(
        self,
        page: PageWrite,
        *,
        sections: Iterable[ParsedSection] = (),
        aliases: Iterable[AliasWrite] = (),
        relations: Iterable[RelationWrite] = (),
    ) -> int:
        values = (
            page.profile_id, page.package_id, page.name, page.section, page.title,
            page.summary, page.source_path, page.executable_path,
            page.program_version, page.language, page.locale,
            page.source_encoding, page.decode_status, page.decode_error_count,
            int(page.contains_replacement_chars), page.roff_content,
            page.plain_text, page.renderer, _timestamp(page.imported_at),
            page.content_hash,
        )
        cursor = self.connection.execute(
            """
            INSERT INTO pages(
                profile_id, package_id, name, section, title, summary,
                source_path, executable_path, program_version, language, locale,
                source_encoding, decode_status, decode_error_count,
                contains_replacement_chars, roff_content, plain_text, renderer,
                imported_at, content_hash
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT DO UPDATE SET
                package_id=excluded.package_id, title=excluded.title,
                summary=excluded.summary, source_path=excluded.source_path,
                executable_path=excluded.executable_path,
                program_version=excluded.program_version,
                source_encoding=excluded.source_encoding,
                decode_status=excluded.decode_status,
                decode_error_count=excluded.decode_error_count,
                contains_replacement_chars=excluded.contains_replacement_chars,
                roff_content=excluded.roff_content, plain_text=excluded.plain_text,
                renderer=excluded.renderer, imported_at=excluded.imported_at,
                content_hash=excluded.content_hash
            RETURNING id
            """,
            values,
        )
        page_id = int(cursor.fetchone()[0])
        self.connection.execute("DELETE FROM sections WHERE page_id=?", (page_id,))
        self.connection.execute("DELETE FROM aliases WHERE page_id=?", (page_id,))
        self.connection.execute("DELETE FROM relations WHERE source_page_id=?", (page_id,))
        self.connection.executemany(
            "INSERT INTO sections(page_id, section_order, original_name, normalized_name, content) "
            "VALUES (?, ?, ?, ?, ?)",
            (
                (page_id, item.section_order, item.original_name,
                 item.normalized_name, item.content)
                for item in sections
            ),
        )
        self.connection.executemany(
            "INSERT INTO aliases(page_id, alias, alias_type, alias_section, alias_language) "
            "VALUES (?, ?, ?, ?, ?)",
            (
                (page_id, item.alias, item.alias_type,
                 item.alias_section, item.alias_language)
                for item in aliases
            ),
        )
        self.connection.executemany(
            "INSERT INTO relations(source_page_id, target_name, target_section, relation_type) "
            "VALUES (?, ?, ?, ?)",
            (
                (page_id, item.target_name, item.target_section, item.relation_type)
                for item in relations
            ),
        )
        refresh_page_fts(self.connection, page_id)
        return page_id

    def write_error(
        self, stage: str, message: str, *, source_path: str | None = None,
        error_code: str | None = None
    ) -> int:
        cursor = self.connection.execute(
            "INSERT INTO build_errors(source_path, stage, error_code, message, created_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (source_path, stage, error_code, message,
             datetime.now(timezone.utc).isoformat()),
        )
        return int(cursor.lastrowid)

    def write_command_info(
        self,
        page_id: int,
        command_name: str,
        *,
        command_path: str | None,
        command_type: str | None,
        version_text: str | None,
        help_text: str | None,
        is_available: bool,
    ) -> int:
        self.connection.execute("DELETE FROM command_info WHERE page_id=?", (page_id,))
        cursor = self.connection.execute(
            "INSERT INTO command_info(page_id, command_name, command_path, command_type, "
            "version_text, help_text, is_available) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (page_id, command_name, command_path, command_type, version_text,
             help_text, int(is_available)),
        )
        return int(cursor.lastrowid)

    def finalize(self) -> str:
        digest = hashlib.sha256()
        for row in self.connection.execute(
            "SELECT id, content_hash FROM pages ORDER BY id"
        ):
            digest.update(f"{row[0]}:{row[1]}\n".encode())
        checksum = digest.hexdigest()
        set_meta(self.connection, "content_checksum", checksum)
        set_meta(self.connection, "updated_at", datetime.now(timezone.utc).isoformat())
        return checksum
