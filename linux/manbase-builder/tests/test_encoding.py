from __future__ import annotations

import unicodedata

import pytest

from manbase_builder.encoding import StrictEncodingError, decode_bytes
from manbase_builder.models import DecodeStatus


@pytest.mark.parametrize("encoding", ["koi8-r", "cp1251", "iso-8859-5"])
def test_russian_legacy_encodings(encoding: str) -> None:
    text = "ОПИСАНИЕ\nПрограмма выводит русский текст и параметры команды."
    result = decode_bytes(text.encode(encoding))
    assert result.text == text
    assert result.source_encoding == encoding
    assert result.decode_status == DecodeStatus.FALLBACK


def test_utf8_and_russian_text() -> None:
    result = decode_bytes("Описание программы".encode())
    assert result.text == "Описание программы"
    assert result.source_encoding == "utf-8"
    assert result.decode_status == DecodeStatus.EXACT


def test_utf8_bom() -> None:
    result = decode_bytes(b"\xef\xbb\xbfhello")
    assert result.text == "hello"
    assert result.source_encoding == "utf-8-sig"


def test_ascii() -> None:
    result = decode_bytes(b"NAME\nprintf - format output")
    assert result.text.startswith("NAME")
    assert result.source_encoding == "ascii"


def test_locale_hint_takes_precedence_for_ambiguous_short_text() -> None:
    text = "Тест"
    result = decode_bytes(text.encode("cp1251"), path_locale_hint="ru_RU.CP1251")
    assert result.text == text
    assert result.source_encoding == "cp1251"


def test_mixed_utf8_is_replaced_and_recorded() -> None:
    data = "Русский текст".encode() + b"\xff" + " далее".encode()
    result = decode_bytes(data)
    assert "Русский" in result.text
    assert result.decode_status == DecodeStatus.REPLACED
    assert result.decode_error_count == 1
    assert result.contains_replacement_chars


def test_strict_mode_rejects_uncertain_or_replaced_input() -> None:
    with pytest.raises(StrictEncodingError):
        decode_bytes("Программа".encode("koi8-r"), strict=True)


def test_pseudographics_are_not_lost_with_hint() -> None:
    text = "┌───┐\n│ x │\n└───┘"
    result = decode_bytes(text.encode("koi8-r"), locale_hint="ru_RU.KOI8-R")
    assert result.text == text


def test_nul_newlines_and_nfc_normalization() -> None:
    decomposed = unicodedata.normalize("NFD", "Café")
    result = decode_bytes((decomposed + "\x00\r\nnext\rline").encode())
    assert result.text == "Café\nnext\nline"
    assert unicodedata.is_normalized("NFC", result.text)
