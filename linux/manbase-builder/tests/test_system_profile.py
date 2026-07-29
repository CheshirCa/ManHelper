from __future__ import annotations

import logging
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from manbase_builder.system_profile import collect_system_profile, parse_os_release


def completed(args: list[str], stdout: str = "", stderr: str = "", code: int = 0):
    return subprocess.CompletedProcess(args, code, stdout, stderr)


def test_parse_typical_os_release() -> None:
    parsed = parse_os_release(
        'NAME="Debian GNU/Linux"\nVERSION_ID="12"\nVERSION_CODENAME=bookworm\n'
    )
    assert parsed == {
        "NAME": "Debian GNU/Linux",
        "VERSION_ID": "12",
        "VERSION_CODENAME": "bookworm",
    }


def test_debian_profile_and_builder_version(tmp_path: Path) -> None:
    release = tmp_path / "os-release"
    release.write_text(
        'NAME="Debian GNU/Linux"\nVERSION_ID="12"\nVERSION_CODENAME=bookworm\n',
        encoding="utf-8",
    )

    def runner(args):
        if args == ["locale", "-a"]:
            return completed(args, "C\nC.utf8\nru_RU.UTF-8\n")
        return completed(args, 'LANG="ru_RU.UTF-8"\n')

    profile = collect_system_profile(
        "Тестовая система",
        os_release_path=release,
        runner=runner,
        environ={},
        which=lambda name: "/usr/bin/dpkg-query" if name == "dpkg-query" else None,
        now=lambda: datetime(2026, 1, 2, tzinfo=timezone.utc),
        builder_version="9.8.7",
    )
    assert profile.distribution == "Debian GNU/Linux"
    assert profile.version == "12"
    assert profile.codename == "bookworm"
    assert profile.profile_name == "Тестовая система"
    assert profile.system_locale == "ru_RU.UTF-8"
    assert profile.available_locales[-1] == "ru_RU.UTF-8"
    assert profile.package_manager == "dpkg"
    assert profile.builder_version == "9.8.7"


def test_optional_fields_absent_and_unknown_distribution(tmp_path: Path) -> None:
    release = tmp_path / "os-release"
    release.write_text("ID=mystery\n", encoding="utf-8")
    profile = collect_system_profile(
        os_release_path=release,
        runner=lambda args: completed(list(args), code=1, stderr="not available"),
        environ={"LANG": "C.UTF-8"},
        which=lambda name: None,
    )
    assert profile.distribution == "mystery"
    assert profile.version is None
    assert profile.codename is None
    assert profile.package_manager == "unknown"
    assert profile.system_locale == "C.UTF-8"


def test_absent_commands_and_container_without_systemd_are_logged(
    tmp_path: Path, caplog
) -> None:
    caplog.set_level(logging.WARNING)
    missing = tmp_path / "missing"

    def runner(args):
        raise FileNotFoundError(args[0])

    profile = collect_system_profile(
        os_release_path=missing, runner=runner, environ={}, which=lambda name: None
    )
    assert profile.distribution == "Unknown Linux"
    assert profile.available_locales == ()
    assert "Unable to read" in caplog.text
    # localectl is deliberately not required or invoked.
