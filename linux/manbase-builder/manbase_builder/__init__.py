"""ManBase Builder public package."""

from .config import BuilderConfig
from .models import (
    DecodeStatus,
    DecodedText,
    AliasError,
    AliasResolutionResult,
    AliasWrite,
    DatabaseCheckResult,
    CommandProbeResult,
    ManPageSource,
    PackageInfo,
    PageBundle,
    PageWrite,
    ParsedSection,
    RenderResult,
    RelationWrite,
    ResolvedAlias,
    ScanError,
    ScanResult,
    SectionParseResult,
    SystemProfile,
    UpdateResult,
)

__all__ = [
    "BuilderConfig",
    "AliasError",
    "AliasResolutionResult",
    "AliasWrite",
    "DatabaseCheckResult",
    "CommandProbeResult",
    "DecodeStatus",
    "DecodedText",
    "ManPageSource",
    "PackageInfo",
    "PageBundle",
    "PageWrite",
    "ParsedSection",
    "RenderResult",
    "RelationWrite",
    "ResolvedAlias",
    "ScanError",
    "ScanResult",
    "SectionParseResult",
    "SystemProfile",
    "UpdateResult",
]

__version__ = "0.1.0"
