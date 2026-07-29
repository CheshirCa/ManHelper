"""Package-manager adapters, with a Debian implementation and caching."""

from __future__ import annotations

import shutil
from collections.abc import Callable, Sequence
from pathlib import Path

from .models import PackageInfo
from .subprocess_utils import BoundedProcessError, BoundedProcessResult, run_bounded

Runner = Callable[..., BoundedProcessResult]


class PackageResolver:
    def __init__(
        self,
        manager: str = "dpkg",
        *,
        executable: str | None = None,
        runner: Runner = run_bounded,
        timeout: float = 5,
        max_output: int = 64 * 1024,
    ) -> None:
        self.manager = manager
        self.executable = executable or (
            shutil.which("dpkg-query") if manager == "dpkg" else None
        )
        self.runner = runner
        self.timeout = timeout
        self.max_output = max_output
        self._path_cache: dict[str, PackageInfo] = {}
        self._package_cache: dict[str, PackageInfo] = {}

    def _run(self, command: Sequence[str]) -> BoundedProcessResult:
        return self.runner(
            command, timeout=self.timeout, max_output=self.max_output
        )

    def resolve(self, path: Path | str) -> PackageInfo:
        absolute_path = Path(path).absolute()
        key = str(absolute_path)
        if key in self._path_cache:
            return self._path_cache[key]
        unknown = PackageInfo(None, None, None, self.manager, found=False)
        if self.manager != "dpkg" or not self.executable:
            result = PackageInfo(None, None, None, "unknown", found=False)
            self._path_cache[key] = result
            return result
        managed_roots = ("/usr/", "/bin/", "/sbin/", "/lib/", "/etc/", "/var/")
        if key.startswith("/usr/local/") or not key.startswith(managed_roots):
            self._path_cache[key] = unknown
            return unknown
        try:
            owner = self._run([self.executable, "-S", key])
            if owner.returncode != 0:
                self._path_cache[key] = unknown
                return unknown
            names = []
            for line in owner.stdout.decode("utf-8", "replace").splitlines():
                prefix, separator, _ = line.partition(": ")
                if separator:
                    names.extend(item.strip() for item in prefix.split(",") if item.strip())
            if not names:
                self._path_cache[key] = unknown
                return unknown
            package_name = names[0]
            if package_name in self._package_cache:
                result = self._package_cache[package_name]
            else:
                details = self._run(
                    [
                        self.executable, "-W",
                        "-f=${Package}\\t${Version}\\t${Architecture}\\t${binary:Summary}\\n",
                        package_name,
                    ]
                )
                fields = details.stdout.decode("utf-8", "replace").rstrip("\n").split("\t", 3)
                result = PackageInfo(
                    fields[0] if fields else package_name,
                    fields[1] if len(fields) > 1 else None,
                    fields[2] if len(fields) > 2 else None,
                    "dpkg",
                    fields[3] if len(fields) > 3 else None,
                    details.returncode == 0,
                )
                self._package_cache[package_name] = result
        except (OSError, BoundedProcessError):
            result = unknown
        self._path_cache[key] = result
        return result
