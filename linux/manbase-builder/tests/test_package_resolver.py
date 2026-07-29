from pathlib import Path

from manbase_builder.package_resolver import PackageResolver
from manbase_builder.subprocess_utils import BoundedProcessResult


def test_debian_package_and_cache(tmp_path: Path) -> None:
    calls = []

    def runner(command, **kwargs):
        calls.append(command)
        if "-S" in command:
            return BoundedProcessResult(0, b"coreutils: /usr/bin/ls\n", b"")
        return BoundedProcessResult(
            0, b"coreutils\t9.7-3\tamd64\tGNU core utilities\n", b""
        )

    resolver = PackageResolver(executable="/usr/bin/dpkg-query", runner=runner)
    first = resolver.resolve("/usr/bin/ls")
    second = resolver.resolve("/usr/bin/ls")
    assert first == second
    assert first.name == "coreutils"
    assert first.version == "9.7-3"
    assert first.found
    assert len(calls) == 2


def test_no_package_multiple_answers_and_missing_executable() -> None:
    def runner(command, **kwargs):
        if "-S" in command:
            return BoundedProcessResult(0, b"pkg-a, pkg-b: /shared\n", b"")
        return BoundedProcessResult(0, b"pkg-a\t1\tall\tShared\n", b"")

    result = PackageResolver(executable="/dpkg", runner=runner).resolve(
        "/usr/share/shared"
    )
    assert result.name == "pkg-a"
    assert not PackageResolver(executable="").resolve("/usr/local/tool").found


def test_file_without_package_is_not_critical() -> None:
    resolver = PackageResolver(
        executable="/dpkg",
        runner=lambda command, **kwargs: BoundedProcessResult(1, b"", b"not found"),
    )
    result = resolver.resolve("/usr/local/bin/local")
    assert not result.found
    assert result.manager == "dpkg"


def test_unknown_manager() -> None:
    result = PackageResolver(manager="other").resolve("/tmp/file")
    assert result.manager == "unknown"
    assert not result.found
