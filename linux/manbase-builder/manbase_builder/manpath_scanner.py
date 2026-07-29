"""Discover manual-page files and their locale/section metadata."""

from __future__ import annotations

import logging
import os
import re
import shutil
import subprocess
from collections.abc import Iterable, Sequence
from pathlib import Path

from .config import DEFAULT_MANPATHS
from .models import ManPageSource, ScanError, ScanResult

LOGGER = logging.getLogger(__name__)
SECTION_DIR = re.compile(r"^man([1-9nl])$")
COMPRESSION_SUFFIXES = {
    ".gz": "gzip",
    ".xz": "xz",
    ".bz2": "bzip2",
    ".zst": "zstd",
}


def discover_manpaths(
    explicit_paths: Iterable[Path | str] = (),
    *,
    include_defaults: bool = True,
    manpath_executable: str | None = None,
    use_manpath_command: bool = True,
) -> tuple[Path, ...]:
    """Return ordered, de-duplicated candidate manual roots."""

    candidates = [Path(path).expanduser() for path in explicit_paths]
    executable = (
        (manpath_executable or shutil.which("manpath"))
        if use_manpath_command
        else None
    )
    if executable:
        try:
            result = subprocess.run(
                [executable],
                check=False,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=5,
                stdin=subprocess.DEVNULL,
            )
            if result.returncode == 0:
                candidates.extend(Path(item) for item in result.stdout.strip().split(":") if item)
            else:
                LOGGER.warning("manpath returned %s: %s", result.returncode, result.stderr.strip())
        except (OSError, subprocess.SubprocessError) as exc:
            LOGGER.warning("Unable to run manpath: %s", exc)
    if include_defaults:
        candidates.extend(DEFAULT_MANPATHS)

    unique: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        absolute = candidate.absolute()
        key = os.path.normcase(os.path.normpath(str(absolute)))
        if key not in seen:
            seen.add(key)
            unique.append(absolute)
    return tuple(unique)


def _locale_parts(locale_name: str | None) -> tuple[str, str | None]:
    if not locale_name:
        return "en", None
    language = re.split(r"[_.@]", locale_name, maxsplit=1)[0].lower() or "und"
    return language, locale_name


def _page_from_path(
    path: Path, section: str, man_root: Path, locale_name: str | None
) -> ManPageSource | None:
    filename = path.name
    compression = "plain"
    for suffix, name in COMPRESSION_SUFFIXES.items():
        if filename.endswith(suffix):
            compression = name
            filename = filename[: -len(suffix)]
            break
    page_suffix = f".{section}"
    if not filename.endswith(page_suffix) or filename == page_suffix:
        return None
    name = filename[: -len(page_suffix)]
    language, locale_value = _locale_parts(locale_name)
    return ManPageSource(
        path=path.absolute(),
        name=name,
        section=section,
        language=language,
        locale=locale_value,
        compression=compression,
        man_root=man_root.absolute(),
        is_symlink=path.is_symlink(),
    )


def _section_directories(root: Path, errors: list[ScanError]) -> Iterable[tuple[Path, str, str | None]]:
    try:
        entries = list(root.iterdir())
    except OSError as exc:
        errors.append(ScanError(root, "list-root", str(exc)))
        LOGGER.warning("Cannot scan manual root %s: %s", root, exc)
        return
    for entry in entries:
        match = SECTION_DIR.match(entry.name)
        if match and entry.is_dir():
            yield entry, match.group(1), None
            continue
        try:
            if not entry.is_dir():
                continue
            localized = list(entry.iterdir())
        except OSError as exc:
            errors.append(ScanError(entry, "list-locale", str(exc)))
            LOGGER.warning("Cannot scan locale directory %s: %s", entry, exc)
            continue
        for section_dir in localized:
            match = SECTION_DIR.match(section_dir.name)
            if match and section_dir.is_dir():
                yield section_dir, match.group(1), entry.name


def scan_manpaths(paths: Sequence[Path | str]) -> ScanResult:
    """Scan roots; an inaccessible or malformed entry is recorded and skipped."""

    result = ScanResult()
    seen_files: set[str] = set()
    seen_roots: set[str] = set()
    for supplied_root in paths:
        root = Path(supplied_root).expanduser().absolute()
        root_key = os.path.normcase(os.path.normpath(str(root)))
        if root_key in seen_roots:
            continue
        seen_roots.add(root_key)
        if not root.exists():
            result.errors.append(ScanError(root, "missing-root", "directory does not exist"))
            continue
        for directory, section, locale_name in _section_directories(root, result.errors):
            try:
                entries = list(directory.iterdir())
            except OSError as exc:
                result.errors.append(ScanError(directory, "list-section", str(exc)))
                LOGGER.warning("Cannot scan section directory %s: %s", directory, exc)
                continue
            for path in entries:
                try:
                    if not (path.is_file() or path.is_symlink()):
                        continue
                    file_key = os.path.normcase(os.path.normpath(str(path.absolute())))
                    if file_key in seen_files:
                        continue
                    page = _page_from_path(path, section, root, locale_name)
                    if page is not None:
                        seen_files.add(file_key)
                        result.pages.append(page)
                except OSError as exc:
                    result.errors.append(ScanError(path, "inspect-file", str(exc)))
                    LOGGER.warning("Cannot inspect manual page %s: %s", path, exc)
    result.pages.sort(key=lambda page: (page.language, page.locale or "", page.section, page.name, str(page.path)))
    return result
