"""Render decoded roff safely with a bounded external formatter."""

from __future__ import annotations

import logging
import os
import re
import selectors
import shutil
import subprocess
import tempfile
import time
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path

from .models import RenderResult

LOGGER = logging.getLogger(__name__)
_ANSI_ESCAPE = re.compile(
    r"\x1b(?:[@-_][0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))"
)
_OVERSTRIKE = re.compile(r".\x08")


class RendererProcessError(Exception):
    def __init__(self, code: str, message: str, stderr: bytes = b"") -> None:
        super().__init__(message)
        self.code = code
        self.stderr = stderr


ProcessRunner = Callable[
    [Sequence[str], Mapping[str, str], float, int], tuple[bytes, bytes]
]


def clean_terminal_text(text: str) -> str:
    """Remove terminal-only formatting and normalize line endings."""

    text = _ANSI_ESCAPE.sub("", text)
    while "\x08" in text:
        cleaned = _OVERSTRIKE.sub("", text)
        if cleaned == text:
            text = text.replace("\x08", "")
            break
        text = cleaned
    return text.replace("\r\n", "\n").replace("\r", "\n").replace("\x00", "")


def _controlled_environment() -> dict[str, str]:
    path = os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin")
    locale_name = "C.UTF-8"
    return {
        "PATH": path,
        "LANG": locale_name,
        "LC_ALL": locale_name,
        "PAGER": "cat",
        "MANPAGER": "cat",
        "GROFF_NO_SGR": "1",
    }


def _run_limited(
    command: Sequence[str],
    environment: Mapping[str, str],
    timeout: float,
    max_output: int,
) -> tuple[bytes, bytes]:
    process = subprocess.Popen(
        list(command),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=dict(environment),
        shell=False,
    )
    assert process.stdout is not None and process.stderr is not None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ, "stdout")
    selector.register(process.stderr, selectors.EVENT_READ, "stderr")
    output = bytearray()
    errors = bytearray()
    deadline = time.monotonic() + timeout
    try:
        while selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RendererProcessError("timeout", f"renderer exceeded {timeout:g}s")
            events = selector.select(min(remaining, 0.25))
            if not events and process.poll() is not None:
                events = [(key, 0) for key in tuple(selector.get_map().values())]
            for key, _ in events:
                chunk = os.read(key.fileobj.fileno(), 64 * 1024)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                destination = output if key.data == "stdout" else errors
                destination.extend(chunk)
                if len(output) > max_output or len(errors) > max_output:
                    raise RendererProcessError(
                        "output_limit",
                        f"renderer output exceeds {max_output} bytes",
                        bytes(errors[:max_output]),
                    )
        return_code = process.wait(timeout=max(0.01, deadline - time.monotonic()))
    except RendererProcessError:
        process.kill()
        process.wait()
        raise
    except subprocess.TimeoutExpired as exc:
        process.kill()
        process.wait()
        raise RendererProcessError(
            "timeout", f"renderer exceeded {timeout:g}s"
        ) from exc
    finally:
        selector.close()
    if return_code != 0:
        raise RendererProcessError(
            "renderer_failed",
            f"renderer exited with status {return_code}",
            bytes(errors),
        )
    return bytes(output), bytes(errors)


def _select_renderer(
    preferred: str | None, which: Callable[[str], str | None]
) -> tuple[str, str] | None:
    allowed = (preferred,) if preferred else ("mandoc", "groff", "man")
    for name in allowed:
        if name not in {"mandoc", "groff", "man"}:
            raise ValueError(f"unsupported renderer: {name}")
        executable = which(name)
        if executable:
            return name, executable
    return None


def render_roff(
    roff_text: str,
    *,
    preferred: str | None = None,
    timeout: float = 10.0,
    max_output: int = 4 * 1024 * 1024,
    which: Callable[[str], str | None] = shutil.which,
    runner: ProcessRunner = _run_limited,
) -> RenderResult:
    """Render one Unicode roff document or return a non-fatal failure."""

    if timeout <= 0:
        raise ValueError("timeout must be positive")
    if max_output <= 0:
        raise ValueError("max_output must be positive")
    selected = _select_renderer(preferred, which)
    if selected is None:
        return RenderResult(
            plain_text=None,
            renderer=None,
            success=False,
            error_code="renderer_unavailable",
            error_message="mandoc, groff and man are unavailable",
        )
    renderer_name, executable = selected
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".roff", delete=False
        ) as source:
            source.write(roff_text)
            temporary_path = Path(source.name)
        if renderer_name == "mandoc":
            command = [executable, "-T", "utf8", str(temporary_path)]
        elif renderer_name == "groff":
            command = [
                executable,
                "-Kutf8",
                "-Tutf8",
                "-mandoc",
                str(temporary_path),
            ]
        else:
            command = [executable, "--local-file", str(temporary_path)]
        stdout, stderr = runner(
            command, _controlled_environment(), timeout, max_output
        )
        plain_text = clean_terminal_text(stdout.decode("utf-8", "replace"))
        stderr_text = clean_terminal_text(stderr.decode("utf-8", "replace"))
        return RenderResult(
            plain_text=plain_text,
            renderer=renderer_name,
            success=True,
            stderr=stderr_text,
        )
    except RendererProcessError as exc:
        LOGGER.warning("%s could not render page: %s", renderer_name, exc)
        return RenderResult(
            plain_text=None,
            renderer=renderer_name,
            success=False,
            error_code=exc.code,
            error_message=str(exc),
            stderr=clean_terminal_text(exc.stderr.decode("utf-8", "replace")),
        )
    except OSError as exc:
        LOGGER.warning("%s could not start: %s", renderer_name, exc)
        return RenderResult(
            plain_text=None,
            renderer=renderer_name,
            success=False,
            error_code="renderer_os_error",
            error_message=str(exc),
        )
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink()
            except FileNotFoundError:
                pass
