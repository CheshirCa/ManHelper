"""Update/rebuild page sets without duplicates or stale FTS rows."""

from __future__ import annotations

import sqlite3
from collections.abc import Iterable

from .database_writer import DatabaseWriter
from .models import PageBundle, UpdateResult


class DatabaseUpdater:
    def __init__(self, connection: sqlite3.Connection) -> None:
        self.connection = connection
        self.writer = DatabaseWriter(connection)

    def apply(
        self,
        profile_id: int,
        bundles: Iterable[PageBundle],
        *,
        rebuild: bool = False,
        remove_missing: bool = True,
    ) -> UpdateResult:
        items = list(bundles)
        if any(item.page.profile_id != profile_id for item in items):
            raise ValueError("all pages must belong to profile_id")
        with self.writer.transaction():
            if rebuild:
                cursor = self.connection.execute(
                    "DELETE FROM pages WHERE profile_id=?", (profile_id,)
                )
                removed = max(cursor.rowcount, 0)
            else:
                existing = {
                    (row[0], row[1], row[2], row[3] or "")
                    for row in self.connection.execute(
                        "SELECT name, section, language, locale FROM pages WHERE profile_id=?",
                        (profile_id,),
                    )
                }
                incoming = {
                    (item.page.name, item.page.section, item.page.language,
                     item.page.locale or "")
                    for item in items
                }
                stale = existing - incoming if remove_missing else set()
                removed = 0
                for name, section, language, locale in stale:
                    cursor = self.connection.execute(
                        "DELETE FROM pages WHERE profile_id=? AND name=? AND section=? "
                        "AND language=? AND COALESCE(locale,'')=?",
                        (profile_id, name, section, language, locale),
                    )
                    removed += max(cursor.rowcount, 0)
            for item in items:
                self.writer.write_page(
                    item.page, sections=item.sections, aliases=item.aliases,
                    relations=item.relations,
                )
            checksum = self.writer.finalize()
        return UpdateResult(len(items), removed, checksum)
