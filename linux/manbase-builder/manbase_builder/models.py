"""Data models shared by the first-stage builder modules."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum
from pathlib import Path


class DecodeStatus(StrEnum):
    """Outcome of converting source bytes to Unicode."""

    EXACT = "exact"
    FALLBACK = "fallback"
    REPLACED = "replaced"


@dataclass(frozen=True, slots=True)
class SystemProfile:
    distribution: str
    version: str | None
    codename: str | None
    architecture: str
    kernel: str
    hostname: str
    system_locale: str | None
    available_locales: tuple[str, ...]
    package_manager: str
    builder_version: str
    created_at: datetime
    profile_name: str | None = None


@dataclass(frozen=True, slots=True)
class ManPageSource:
    """A discovered manual page before decompression."""

    path: Path
    name: str
    section: str
    language: str
    locale: str | None
    compression: str
    man_root: Path
    is_symlink: bool = False


@dataclass(frozen=True, slots=True)
class ScanError:
    path: Path
    operation: str
    message: str


@dataclass(slots=True)
class ScanResult:
    pages: list[ManPageSource] = field(default_factory=list)
    errors: list[ScanError] = field(default_factory=list)


@dataclass(frozen=True, slots=True)
class DecodedText:
    text: str
    source_encoding: str
    decode_status: DecodeStatus
    decode_error_count: int
    contains_replacement_chars: bool


@dataclass(frozen=True, slots=True)
class RenderResult:
    plain_text: str | None
    renderer: str | None
    success: bool
    error_code: str | None = None
    error_message: str | None = None
    stderr: str = ""


@dataclass(frozen=True, slots=True)
class ParsedSection:
    section_order: int
    original_name: str | None
    normalized_name: str
    content: str


@dataclass(frozen=True, slots=True)
class SectionParseResult:
    sections: tuple[ParsedSection, ...]
    summary: str | None
    synopsis: str | None


@dataclass(frozen=True, slots=True)
class ResolvedAlias:
    alias: str
    alias_section: str
    alias_language: str
    alias_locale: str | None
    alias_type: str
    source_path: Path
    target_path: Path
    target_name: str
    target_section: str
    chain: tuple[Path, ...]


@dataclass(frozen=True, slots=True)
class AliasError:
    source_path: Path
    error_code: str
    message: str


@dataclass(slots=True)
class AliasResolutionResult:
    aliases: list[ResolvedAlias] = field(default_factory=list)
    errors: list[AliasError] = field(default_factory=list)


@dataclass(frozen=True, slots=True)
class PageWrite:
    profile_id: int
    name: str
    section: str
    language: str
    imported_at: datetime
    content_hash: str
    package_id: int | None = None
    title: str | None = None
    summary: str | None = None
    source_path: str | None = None
    executable_path: str | None = None
    program_version: str | None = None
    locale: str | None = None
    source_encoding: str | None = None
    decode_status: str = "exact"
    decode_error_count: int = 0
    contains_replacement_chars: bool = False
    roff_content: str | None = None
    plain_text: str | None = None
    renderer: str | None = None


@dataclass(frozen=True, slots=True)
class AliasWrite:
    alias: str
    alias_type: str
    alias_section: str | None = None
    alias_language: str | None = None


@dataclass(frozen=True, slots=True)
class RelationWrite:
    target_name: str
    target_section: str | None
    relation_type: str


@dataclass(frozen=True, slots=True)
class DatabaseCheckResult:
    ok: bool
    integrity: str
    foreign_key_errors: tuple[tuple[object, ...], ...]
    schema_version: int | None
    checksum_valid: bool
    fts_available: bool
    errors: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class PackageInfo:
    name: str | None
    version: str | None
    architecture: str | None
    manager: str
    description: str | None = None
    found: bool = False


@dataclass(frozen=True, slots=True)
class CommandProbeResult:
    command_name: str
    command_path: str | None
    command_type: str | None
    version_text: str | None
    help_text: str | None
    is_available: bool
    error_code: str | None = None
    error_message: str | None = None


@dataclass(frozen=True, slots=True)
class PageBundle:
    page: PageWrite
    sections: tuple[ParsedSection, ...] = ()
    aliases: tuple[AliasWrite, ...] = ()
    relations: tuple[RelationWrite, ...] = ()


@dataclass(frozen=True, slots=True)
class UpdateResult:
    written: int
    removed: int
    checksum: str
