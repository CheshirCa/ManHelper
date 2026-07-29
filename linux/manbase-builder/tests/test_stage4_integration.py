from pathlib import Path

from manbase_builder.command_probe import probe_command
from manbase_builder.package_resolver import PackageResolver


def test_real_debian_package_and_safe_command_probes() -> None:
    package = PackageResolver().resolve(Path("/usr/bin/ls"))
    assert package.found
    assert package.name == "coreutils"
    assert package.version

    command = probe_command("ls", collect_help=False)
    assert command.is_available
    assert command.command_path
    assert command.version_text and "ls" in command.version_text

    builtin = probe_command("printf")
    assert builtin.is_available
    assert builtin.command_type in {"builtin", "file"}

    denied = probe_command("systemctl")
    assert not denied.is_available
    assert denied.error_code == "denied"
