"""Configuration and validation for ManBase Builder."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


DEFAULT_MANPATHS = (
    Path("/usr/share/man"),
    Path("/usr/local/share/man"),
    Path("/usr/local/man"),
)


@dataclass(frozen=True, slots=True)
class BuilderConfig:
    profile_name: str | None = None
    manpaths: tuple[Path, ...] = field(default_factory=tuple)
    locales: tuple[str, ...] = field(default_factory=tuple)
    include_roff: bool = True
    collect_help: bool = False
    strict_encoding: bool = False
    max_page_size: int = 16 * 1024 * 1024
    subprocess_timeout: float = 10.0
    max_subprocess_output: int = 4 * 1024 * 1024

    def __post_init__(self) -> None:
        object.__setattr__(
            self, "manpaths", tuple(Path(path).expanduser() for path in self.manpaths)
        )
        object.__setattr__(self, "locales", tuple(self.locales))
        if self.max_page_size <= 0:
            raise ValueError("max_page_size must be positive")
        if self.subprocess_timeout <= 0:
            raise ValueError("subprocess_timeout must be positive")
        if self.max_subprocess_output <= 0:
            raise ValueError("max_subprocess_output must be positive")
