from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

from manbase_builder.roff_renderer import (
    RendererProcessError,
    _run_limited,
    clean_terminal_text,
    render_roff,
)


def fake_which(available: set[str]):
    return lambda name: f"/usr/bin/{name}" if name in available else None


def test_mandoc_has_priority_and_controlled_environment() -> None:
    observed = {}

    def runner(command, environment, timeout, max_output):
        observed.update(
            command=command,
            environment=environment,
            timeout=timeout,
            max_output=max_output,
        )
        assert Path(command[-1]).read_text(encoding="utf-8").startswith(".TH")
        return "ИМЯ\n  тест".encode(), b"warning"

    result = render_roff(
        ".TH ТЕСТ 1",
        which=fake_which({"mandoc", "groff", "man"}),
        runner=runner,
        timeout=3,
        max_output=99,
    )
    assert result.success
    assert result.renderer == "mandoc"
    assert result.plain_text == "ИМЯ\n  тест"
    assert observed["command"][:3] == ["/usr/bin/mandoc", "-T", "utf8"]
    assert observed["environment"]["LC_ALL"] == "C.UTF-8"
    assert observed["environment"]["MANPAGER"] == "cat"
    assert observed["timeout"] == 3
    assert observed["max_output"] == 99


def test_groff_fallback() -> None:
    def runner(command, environment, timeout, max_output):
        assert command[:4] == ["/usr/bin/groff", "-Kutf8", "-Tutf8", "-mandoc"]
        return b"NAME\n", b""

    result = render_roff(
        ".TH TEST 1", which=fake_which({"groff", "man"}), runner=runner
    )
    assert result.success
    assert result.renderer == "groff"


def test_preferred_man() -> None:
    def runner(command, environment, timeout, max_output):
        assert command[:2] == ["/usr/bin/man", "--local-file"]
        return b"NAME\n", b""

    result = render_roff(
        ".TH TEST 1", preferred="man", which=fake_which({"man"}), runner=runner
    )
    assert result.renderer == "man"


def test_no_renderer_preserves_roff_at_caller() -> None:
    roff = ".TH TEST 1"
    result = render_roff(roff, which=lambda name: None)
    assert not result.success
    assert result.plain_text is None
    assert result.renderer is None
    assert result.error_code == "renderer_unavailable"
    assert roff == ".TH TEST 1"


@pytest.mark.parametrize("code", ["timeout", "output_limit", "renderer_failed"])
def test_renderer_failure_is_nonfatal(code: str) -> None:
    def runner(command, environment, timeout, max_output):
        raise RendererProcessError(code, "fixture failure", b"\xfferror")

    result = render_roff(
        ".TH BAD 1", which=fake_which({"mandoc"}), runner=runner
    )
    assert not result.success
    assert result.error_code == code
    assert result.renderer == "mandoc"
    assert "error" in result.stderr


def test_russian_roff_is_written_as_utf8() -> None:
    def runner(command, environment, timeout, max_output):
        assert "Описание" in Path(command[-1]).read_text(encoding="utf-8")
        return "ОПИСАНИЕ\nТекст".encode(), b""

    result = render_roff(
        ".SH ОПИСАНИЕ\nОписание", which=fake_which({"groff"}), runner=runner
    )
    assert result.plain_text == "ОПИСАНИЕ\nТекст"


def test_backspace_and_ansi_are_removed() -> None:
    dirty = "\x1b[31mN\x1b[0mA\bAME\n_\bX\r\n"
    assert clean_terminal_text(dirty) == "NAME\nX\n"


def test_invalid_configuration() -> None:
    with pytest.raises(ValueError):
        render_roff("", preferred="other")
    with pytest.raises(ValueError):
        render_roff("", timeout=0)
    with pytest.raises(ValueError):
        render_roff("", max_output=0)


def test_real_process_timeout_is_enforced() -> None:
    with pytest.raises(RendererProcessError, match="exceeded") as raised:
        _run_limited(
            [sys.executable, "-c", "import time; time.sleep(2)"],
            {"PATH": os.environ.get("PATH", "")},
            0.05,
            1024,
        )
    assert raised.value.code == "timeout"


def test_real_process_output_limit_is_enforced() -> None:
    with pytest.raises(RendererProcessError) as raised:
        _run_limited(
            [sys.executable, "-c", "print('x' * 1000)"],
            {"PATH": os.environ.get("PATH", "")},
            1,
            10,
        )
    assert raised.value.code == "output_limit"
