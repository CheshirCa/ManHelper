"""End-to-end ManBase Builder orchestration."""

from __future__ import annotations

import dataclasses
import hashlib
import logging
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

from . import __version__
from .alias_resolver import resolve_aliases
from .cli import parse_args
from .command_probe import probe_command
from .database_checks import check_database
from .database_schema import get_meta, initialize_database
from .database_updater import DatabaseUpdater
from .database_writer import DatabaseWriter
from .decompressor import DecompressionError, read_page_bytes
from .encoding import StrictEncodingError, decode_bytes
from .manpath_scanner import discover_manpaths, scan_manpaths
from .logging_utils import configure_logging
from .models import AliasWrite, PageBundle, PageWrite
from .package_resolver import PackageResolver
from .roff_renderer import render_roff
from .section_parser import extract_relations, parse_sections
from .system_profile import collect_system_profile

LOGGER = logging.getLogger("manbase_builder")


def _locale_selected(page_locale: str | None, language: str, filters: list[str]) -> bool:
    if not filters:
        return True
    lowered = {item.lower() for item in filters}
    return language.lower() in lowered or (page_locale or "").lower() in lowered


def _validate(connection: sqlite3.Connection, quiet: bool) -> int:
    result = check_database(connection)
    if not quiet:
        print(
            f"integrity={result.integrity} foreign_keys={len(result.foreign_key_errors)} "
            f"schema={result.schema_version} checksum={result.checksum_valid} "
            f"fts={result.fts_available}"
        )
        for error in result.errors:
            print(f"ERROR: {error}", file=sys.stderr)
    return 0 if result.ok else 2


def run(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    configure_logging(verbose=args.verbose, quiet=args.quiet)
    output: Path = args.output.expanduser().absolute()

    if args.validate and not (args.update or args.rebuild or args.manpath):
        if not output.exists():
            LOGGER.error("database does not exist: %s", output)
            return 2
        connection = sqlite3.connect(output)
        try:
            return _validate(connection, args.quiet)
        finally:
            connection.close()
    if args.update and not output.exists():
        LOGGER.error("--update requires an existing database: %s", output)
        return 2

    if args.rebuild and output.exists():
        output.unlink()
    output.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(output)
    try:
        initialize_database(connection, builder_version=__version__)
        writer = DatabaseWriter(connection)
        existing_profile = get_meta(connection, "profile_id")
        if args.update and existing_profile:
            profile_id = int(existing_profile)
            row = connection.execute(
                "SELECT system_locale FROM profiles WHERE id=?", (profile_id,)
            ).fetchone()
            system_locale = row[0] if row else None
        else:
            profile = collect_system_profile(
                args.profile_name, builder_version=__version__
            )
            system_locale = profile.system_locale
            with writer.transaction():
                profile_id = writer.write_profile(profile)

        roots = discover_manpaths(
            args.manpath,
            include_defaults=not bool(args.manpath),
            use_manpath_command=not bool(args.manpath),
        )
        scan = scan_manpaths(roots)
        pages = [
            page for page in scan.pages
            if _locale_selected(page.locale, page.language, args.locale)
        ]
        aliases = resolve_aliases(pages, max_page_size=args.max_page_size)
        alias_sources = {item.source_path for item in aliases.aliases}
        alias_sources.update(error.source_path for error in aliases.errors)
        aliases_by_target: dict[Path, list[AliasWrite]] = {}
        for item in aliases.aliases:
            aliases_by_target.setdefault(item.target_path, []).append(
                AliasWrite(
                    item.alias, item.alias_type, item.alias_section,
                    item.alias_language,
                )
            )

        resolver = PackageResolver()
        pending: list[tuple[PageBundle, object | None]] = []
        build_errors: list[tuple[str | None, str, str | None, str]] = [
            (str(error.path), "scan", error.operation, error.message)
            for error in scan.errors
        ]
        build_errors.extend(
            (str(error.source_path), "alias", error.error_code, error.message)
            for error in aliases.errors
        )
        for index, source in enumerate(pages, 1):
            if source.path in alias_sources:
                continue
            try:
                raw = read_page_bytes(source.path, args.max_page_size)
                decoded = decode_bytes(
                    raw, path_locale_hint=source.locale,
                    locale_hint=system_locale, strict=args.strict_encoding,
                )
                rendered = render_roff(
                    decoded.text, preferred=args.renderer,
                    max_output=args.max_page_size,
                )
                parsed = parse_sections(rendered.plain_text or "")
                package = resolver.resolve(source.path)
                relations = tuple(
                    relation
                    for relation in extract_relations(parsed.sections)
                    if not (
                        relation.target_name.casefold() == source.name.casefold()
                        and relation.target_section == source.section
                    )
                )
                bundle = PageBundle(
                    PageWrite(
                        profile_id=profile_id, name=source.name,
                        section=source.section, language=source.language,
                        locale=source.locale, title=source.name,
                        summary=parsed.summary, source_path=str(source.path),
                        source_encoding=decoded.source_encoding,
                        decode_status=str(decoded.decode_status),
                        decode_error_count=decoded.decode_error_count,
                        contains_replacement_chars=decoded.contains_replacement_chars,
                        roff_content=decoded.text if args.include_roff else None,
                        plain_text=rendered.plain_text,
                        renderer=rendered.renderer,
                        imported_at=datetime.now(timezone.utc),
                        content_hash=hashlib.sha256(raw).hexdigest(),
                    ),
                    parsed.sections,
                    tuple(aliases_by_target.get(source.path, ())),
                    relations,
                )
                pending.append((bundle, package if package.found else None))
                if not rendered.success:
                    build_errors.append((
                        str(source.path), "render", rendered.error_code,
                        rendered.error_message or "render failed",
                    ))
            except (DecompressionError, StrictEncodingError, OSError) as exc:
                build_errors.append((
                    str(source.path), "import", type(exc).__name__, str(exc)
                ))
            if not args.quiet and index % 500 == 0:
                LOGGER.info("processed %d/%d pages", index, len(pages))

        package_ids: dict[tuple[object, ...], int] = {}
        with writer.transaction():
            for _, package in pending:
                if package is None:
                    continue
                key = (
                    package.name, package.version, package.architecture,
                    package.manager,
                )
                if key not in package_ids:
                    package_ids[key] = writer.write_package(
                        package.name, package.version, package.architecture,
                        package.manager, package.description,
                    )
        bundles: list[PageBundle] = []
        for bundle, package in pending:
            if package is not None:
                key = (
                    package.name, package.version, package.architecture,
                    package.manager,
                )
                bundle = dataclasses.replace(
                    bundle,
                    page=dataclasses.replace(
                        bundle.page, package_id=package_ids[key]
                    ),
                )
            bundles.append(bundle)
        update = DatabaseUpdater(connection).apply(
            profile_id, bundles, rebuild=False, remove_missing=True
        )
        with writer.transaction():
            for source_path, stage, code, message in build_errors:
                writer.write_error(
                    stage, message, source_path=source_path, error_code=code
                )
            if args.collect_help:
                for bundle in bundles:
                    if bundle.page.section != "1":
                        continue
                    row = connection.execute(
                        "SELECT id FROM pages WHERE profile_id=? AND name=? AND section=? "
                        "AND language=? AND COALESCE(locale,'')=?",
                        (profile_id, bundle.page.name, bundle.page.section,
                         bundle.page.language, bundle.page.locale or ""),
                    ).fetchone()
                    if row:
                        probe = probe_command(
                            bundle.page.name, collect_help=True
                        )
                        writer.write_command_info(
                            int(row[0]), probe.command_name,
                            command_path=probe.command_path,
                            command_type=probe.command_type,
                            version_text=probe.version_text,
                            help_text=probe.help_text,
                            is_available=probe.is_available,
                        )
            writer.finalize()
        if not args.quiet:
            print(
                f"pages={update.written} removed={update.removed} "
                f"errors={len(build_errors)} output={output}"
            )
        return _validate(connection, args.quiet) if args.validate else 0
    except (sqlite3.DatabaseError, ValueError, RuntimeError) as exc:
        LOGGER.error("%s", exc)
        return 2
    finally:
        connection.close()


def main() -> None:
    raise SystemExit(run())
