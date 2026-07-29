from __future__ import annotations

from manbase_builder.command_probe import probe_command
from manbase_builder.subprocess_utils import BoundedProcessError, BoundedProcessResult


def test_version_help_and_stderr() -> None:
    def runner(command, **kwargs):
        if command[-1] == "--version":
            return BoundedProcessResult(0, b"demo 1.2\n", b"")
        return BoundedProcessResult(0, b"", b"usage: demo\n")

    result = probe_command("demo", which=lambda name: "/bin/demo", runner=runner)
    assert result.is_available
    assert result.version_text == "demo 1.2"
    assert result.help_text == "usage: demo"


def test_missing_version_nonzero_is_nonfatal() -> None:
    def runner(command, **kwargs):
        return BoundedProcessResult(1, b"", b"unsupported")

    result = probe_command("demo", which=lambda name: "/bin/demo", runner=runner)
    assert result.is_available
    assert result.error_code == "nonzero_exit"


def test_timeout_and_large_output_are_recorded() -> None:
    for code in ("timeout", "output_limit"):
        def runner(command, **kwargs):
            raise BoundedProcessError(code, code)
        result = probe_command("demo", which=lambda name: "/bin/demo", runner=runner)
        assert result.is_available
        assert result.error_code == code


def test_deny_disabled_and_missing() -> None:
    assert probe_command("shutdown").error_code == "denied"
    assert probe_command("../tool").error_code == "denied"
    assert probe_command("demo", enabled=False).error_code == "disabled"
    assert probe_command("absent", which=lambda name: None).error_code == "not_found"


def test_builtin_uses_fixed_shell_program_without_interpolation() -> None:
    observed = []

    def runner(command, **kwargs):
        observed.append(command)
        return BoundedProcessResult(0, b"printf is a shell builtin\n", b"")

    result = probe_command(
        "printf", which=lambda name: "/bin/bash" if name == "bash" else None,
        runner=runner,
    )
    assert result.command_type == "builtin"
    assert result.is_available
    assert observed[0][-1] == "printf"
    assert '"$1"' in observed[0][4]


def test_help_can_be_disabled() -> None:
    calls = []

    def runner(command, **kwargs):
        calls.append(command)
        return BoundedProcessResult(0, b"v1", b"")

    result = probe_command(
        "demo", collect_help=False, which=lambda name: "/bin/demo", runner=runner
    )
    assert result.help_text is None
    assert len(calls) == 1
