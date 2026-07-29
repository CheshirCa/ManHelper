"""Resolve symlink and roff ``.so`` aliases without following cycles."""

from __future__ import annotations

import logging
import os
import re
from collections.abc import Iterable, Mapping
from pathlib import Path

from .decompressor import DecompressionError, read_page_bytes
from .models import (
    AliasError,
    AliasResolutionResult,
    ManPageSource,
    ResolvedAlias,
)

LOGGER = logging.getLogger(__name__)
_SO_DIRECTIVE = re.compile(r"^\s*\.so\s+(\S+)\s*$")
_COMPRESSION_SUFFIXES = {".gz", ".xz", ".bz2", ".zst"}


def _absolute_without_resolving(path: Path) -> Path:
    return Path(os.path.abspath(path))


def _path_key(path: Path) -> str:
    return os.path.normcase(os.path.normpath(str(_absolute_without_resolving(path))))


def _logical_path(path: Path) -> Path:
    return path.with_suffix("") if path.suffix.lower() in _COMPRESSION_SUFFIXES else path


def _read_roff(
    page: ManPageSource,
    roff_contents: Mapping[Path, str] | None,
    max_page_size: int,
) -> str:
    if roff_contents is not None:
        for candidate in (page.path, page.path.absolute()):
            if candidate in roff_contents:
                return roff_contents[candidate]
    raw = read_page_bytes(page.path, max_page_size)
    return raw.decode("utf-8", "replace")


def _so_target(text: str) -> str | None:
    for line in text.splitlines():
        if not line.strip():
            continue
        match = _SO_DIRECTIVE.match(line)
        return match.group(1) if match else None
    return None


def _reference_for_page(
    page: ManPageSource,
    roff_contents: Mapping[Path, str] | None,
    max_page_size: int,
) -> tuple[str, Path] | None:
    if page.is_symlink:
        target = Path(os.readlink(page.path))
        if not target.is_absolute():
            target = page.path.parent / target
        return "symlink", _absolute_without_resolving(target)

    target_text = _so_target(_read_roff(page, roff_contents, max_page_size))
    if target_text is None:
        return None
    target = Path(target_text)
    if not target.is_absolute():
        if len(target.parts) > 1 and re.fullmatch(r"man[1-9nl]", target.parts[0]):
            target = page.path.parent.parent / target
        else:
            target = page.path.parent / target
    return "so", _absolute_without_resolving(target)


def resolve_aliases(
    pages: Iterable[ManPageSource],
    *,
    roff_contents: Mapping[Path, str] | None = None,
    max_chain_length: int = 64,
    max_page_size: int = 16 * 1024 * 1024,
) -> AliasResolutionResult:
    """Resolve all alias pages to final non-alias targets."""

    if max_chain_length <= 0:
        raise ValueError("max_chain_length must be positive")
    if max_page_size <= 0:
        raise ValueError("max_page_size must be positive")
    page_list = list(pages)
    result = AliasResolutionResult()
    by_path: dict[str, ManPageSource] = {}
    for page in page_list:
        by_path[_path_key(page.path)] = page
        by_path.setdefault(_path_key(_logical_path(page.path)), page)

    references: dict[str, tuple[str, Path] | None] = {}
    for page in page_list:
        try:
            references[_path_key(page.path)] = _reference_for_page(
                page, roff_contents, max_page_size
            )
        except (OSError, DecompressionError) as exc:
            LOGGER.warning("Cannot inspect alias candidate %s: %s", page.path, exc)
            references[_path_key(page.path)] = None
            result.errors.append(
                AliasError(page.path, "alias_read_error", str(exc))
            )

    for source in page_list:
        source_key = _path_key(source.path)
        reference = references[source_key]
        if reference is None:
            continue
        alias_type, target_path = reference
        visited = {source_key}
        chain = [source.path]
        final_page: ManPageSource | None = None
        error: AliasError | None = None

        for _ in range(max_chain_length):
            target_key = _path_key(target_path)
            target_page = by_path.get(target_key)
            if target_page is None:
                target_page = by_path.get(_path_key(_logical_path(target_path)))
            if target_page is None:
                if target_path.is_symlink():
                    chain.append(target_path)
                    if target_key in visited:
                        error = AliasError(
                            source.path,
                            "alias_cycle",
                            "alias cycle: "
                            + " -> ".join(str(path) for path in chain),
                        )
                        break
                    visited.add(target_key)
                    external_target = Path(os.readlink(target_path))
                    if not external_target.is_absolute():
                        external_target = target_path.parent / external_target
                    target_path = _absolute_without_resolving(external_target)
                    continue
                error = AliasError(
                    source.path,
                    "alias_target_missing",
                    f"alias target does not exist: {target_path}",
                )
                break
            chain.append(target_page.path)
            canonical_target_key = _path_key(target_page.path)
            if canonical_target_key in visited:
                error = AliasError(
                    source.path,
                    "alias_cycle",
                    "alias cycle: " + " -> ".join(str(path) for path in chain),
                )
                break
            visited.add(canonical_target_key)
            next_reference = references.get(canonical_target_key)
            if next_reference is None:
                final_page = target_page
                break
            _, target_path = next_reference
        else:
            error = AliasError(
                source.path,
                "alias_chain_too_long",
                f"alias chain exceeds {max_chain_length} links",
            )

        if error is not None:
            result.errors.append(error)
            continue
        assert final_page is not None
        result.aliases.append(
            ResolvedAlias(
                alias=source.name,
                alias_section=source.section,
                alias_language=source.language,
                alias_locale=source.locale,
                alias_type=alias_type,
                source_path=source.path,
                target_path=final_page.path,
                target_name=final_page.name,
                target_section=final_page.section,
                chain=tuple(chain),
            )
        )
    return result
