"""Collect a system profile without requiring root or systemd."""

from __future__ import annotations

import logging
import os
import platform
import shutil
import socket
import subprocess
from collections.abc import Callable, Mapping, Sequence
from datetime import datetime, timezone
from pathlib import Path

from . import __version__
from .models import SystemProfile

LOGGER = logging.getLogger(__name__)
CommandRunner = Callable[[Sequence[str]], subprocess.CompletedProcess[str]]


def _run_command(command: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(command),
        check=False,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=5,
        stdin=subprocess.DEVNULL,
    )


def parse_os_release(text: str) -> dict[str, str]:
    """Parse os-release without evaluating it as shell code."""

    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            quote = value[0]
            value = value[1:-1]
            if quote == '"':
                value = (
                    value.replace(r"\\", "\\")
                    .replace(r"\"", '"')
                    .replace(r"\n", "\n")
                )
        values[key.strip()] = value
    return values


def _safe_command(
    runner: CommandRunner, command: Sequence[str], source: str
) -> subprocess.CompletedProcess[str] | None:
    try:
        result = runner(command)
    except (OSError, subprocess.SubprocessError) as exc:
        LOGGER.warning("Unable to read %s: %s", source, exc)
        return None
    if result.returncode != 0:
        LOGGER.warning(
            "%s returned %s: %s", source, result.returncode, result.stderr.strip()
        )
        return None
    return result


def _detect_package_manager(which: Callable[[str], str | None]) -> str:
    for executable, manager in (
        ("dpkg-query", "dpkg"),
        ("rpm", "rpm"),
        ("apk", "apk"),
        ("pacman", "pacman"),
    ):
        if which(executable):
            return manager
    return "unknown"


def collect_system_profile(
    profile_name: str | None = None,
    *,
    os_release_path: Path = Path("/etc/os-release"),
    runner: CommandRunner = _run_command,
    environ: Mapping[str, str] | None = None,
    which: Callable[[str], str | None] = shutil.which,
    now: Callable[[], datetime] | None = None,
    builder_version: str = __version__,
) -> SystemProfile:
    """Collect stable profile fields, tolerating unavailable optional sources."""

    environment = os.environ if environ is None else environ
    os_data: dict[str, str] = {}
    try:
        os_data = parse_os_release(os_release_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as exc:
        LOGGER.warning("Unable to read %s: %s", os_release_path, exc)

    system_locale = (
        environment.get("LC_ALL")
        or environment.get("LC_CTYPE")
        or environment.get("LANG")
        or None
    )
    locale_result = _safe_command(runner, ["locale"], "locale")
    if locale_result:
        for line in locale_result.stdout.splitlines():
            if line.startswith("LANG=") and not system_locale:
                system_locale = line.partition("=")[2].strip().strip('"') or None
                break

    locales_result = _safe_command(runner, ["locale", "-a"], "available locales")
    available_locales = (
        tuple(
            dict.fromkeys(
                line.strip()
                for line in locales_result.stdout.splitlines()
                if line.strip()
            )
        )
        if locales_result
        else ()
    )

    created_at = (now or (lambda: datetime.now(timezone.utc)))()
    distribution = os_data.get("NAME") or os_data.get("ID") or "Unknown Linux"
    return SystemProfile(
        distribution=distribution,
        version=os_data.get("VERSION_ID") or os_data.get("VERSION"),
        codename=os_data.get("VERSION_CODENAME") or os_data.get("UBUNTU_CODENAME"),
        architecture=platform.machine() or "unknown",
        kernel=platform.release() or "unknown",
        hostname=socket.gethostname(),
        system_locale=system_locale,
        available_locales=available_locales,
        package_manager=_detect_package_manager(which),
        builder_version=builder_version,
        created_at=created_at,
        profile_name=profile_name,
    )
