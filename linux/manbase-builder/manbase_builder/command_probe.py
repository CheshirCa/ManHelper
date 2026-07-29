"""Opt-in, bounded probing of installed commands."""

from __future__ import annotations

import os
import shutil
from collections.abc import Callable

from .models import CommandProbeResult
from .subprocess_utils import BoundedProcessError, BoundedProcessResult, run_bounded

DEFAULT_DENY_LIST = frozenset({
    "shutdown", "reboot", "poweroff", "halt", "init", "systemctl",
    "mount", "umount", "mkfs", "fdisk", "parted", "sudo", "su",
})


def probe_command(
    command_name: str,
    *,
    enabled: bool = True,
    collect_help: bool = True,
    deny_list: frozenset[str] = DEFAULT_DENY_LIST,
    timeout: float = 2,
    max_output: int = 256 * 1024,
    which: Callable[[str], str | None] = shutil.which,
    runner: Callable[..., BoundedProcessResult] = run_bounded,
) -> CommandProbeResult:
    if not enabled:
        return CommandProbeResult(command_name, None, None, None, None, False, "disabled")
    if command_name in deny_list or "/" in command_name or "\x00" in command_name:
        return CommandProbeResult(command_name, None, None, None, None, False, "denied")
    path = which(command_name)
    command_type = "file" if path else None
    if path is None:
        bash = which("bash")
        if bash:
            try:
                located = runner(
                    [bash, "--noprofile", "--norc", "-c",
                     'command -V -- "$1"', "manbase-probe", command_name],
                    timeout=timeout, max_output=max_output,
                )
                if located.returncode == 0:
                    text = located.stdout.decode("utf-8", "replace").strip()
                    return CommandProbeResult(
                        command_name, None, "builtin", text or None, None, True
                    )
            except (OSError, BoundedProcessError):
                pass
        return CommandProbeResult(
            command_name, None, None, None, None, False, "not_found"
        )
    environment = {
        "PATH": os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin"),
        "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8",
    }

    def invoke(option: str) -> tuple[str | None, str | None]:
        try:
            result = runner(
                [path, option], timeout=timeout, max_output=max_output,
                environment=environment,
            )
        except BoundedProcessError as exc:
            return None, exc.code
        except OSError:
            return None, "os_error"
        output = (result.stdout + result.stderr).decode("utf-8", "replace").strip()
        return (output or None), (None if result.returncode == 0 else "nonzero_exit")

    version, version_error = invoke("--version")
    help_text, help_error = invoke("--help") if collect_help else (None, None)
    error = version_error or help_error
    return CommandProbeResult(
        command_name, path, command_type, version, help_text, True,
        error, None if error is None else "one or more probes failed",
    )
