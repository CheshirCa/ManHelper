"""Linux subprocess execution with hard time and output bounds."""

from __future__ import annotations

import os
import selectors
import subprocess
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class BoundedProcessResult:
    returncode: int
    stdout: bytes
    stderr: bytes


class BoundedProcessError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def run_bounded(
    command: Sequence[str],
    *,
    timeout: float,
    max_output: int,
    environment: Mapping[str, str] | None = None,
) -> BoundedProcessResult:
    if timeout <= 0 or max_output <= 0:
        raise ValueError("timeout and max_output must be positive")
    process = subprocess.Popen(
        list(command),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=None if environment is None else dict(environment),
        shell=False,
    )
    assert process.stdout is not None and process.stderr is not None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ, "out")
    selector.register(process.stderr, selectors.EVENT_READ, "err")
    stdout, stderr = bytearray(), bytearray()
    deadline = time.monotonic() + timeout
    try:
        while selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise BoundedProcessError("timeout", f"process exceeded {timeout:g}s")
            for key, _ in selector.select(min(remaining, 0.25)):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                target = stdout if key.data == "out" else stderr
                target.extend(chunk)
                if len(target) > max_output:
                    raise BoundedProcessError(
                        "output_limit", f"process output exceeds {max_output} bytes"
                    )
        try:
            returncode = process.wait(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired as exc:
            raise BoundedProcessError("timeout", f"process exceeded {timeout:g}s") from exc
    except BaseException:
        process.kill()
        process.wait()
        raise
    finally:
        selector.close()
    return BoundedProcessResult(returncode, bytes(stdout), bytes(stderr))
