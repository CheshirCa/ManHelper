"""Decode source bytes into normalized Unicode."""

from __future__ import annotations

import codecs
import re
import unicodedata

from .models import DecodeStatus, DecodedText


class StrictEncodingError(UnicodeError):
    """Raised when strict mode rejects damaged or uncertain input."""


_ENCODING_ALIASES = {
    "utf8": "utf-8",
    "utf-8": "utf-8",
    "koi8r": "koi8-r",
    "koi8-r": "koi8-r",
    "cp1251": "cp1251",
    "windows1251": "cp1251",
    "windows-1251": "cp1251",
    "iso88595": "iso-8859-5",
    "iso-8859-5": "iso-8859-5",
}
_RUSSIAN_COMMON = (
    "ст", "но", "то", "на", "ен", "ов", "ни", "ра", "во", "ко", "пр",
    "не", "ос", "ро", "го", "ал", "по", "ер", "ть", "ет", "ин", "ан",
)


def encoding_from_locale(locale_name: str | None) -> str | None:
    if not locale_name or "." not in locale_name:
        return None
    codeset = locale_name.split(".", 1)[1].split("@", 1)[0]
    normalized = re.sub(r"[^a-zA-Z0-9-]", "", codeset).lower()
    return _ENCODING_ALIASES.get(normalized)


def _legacy_score(text: str) -> float:
    if not text:
        return 0.0
    printable = sum(character.isprintable() or character in "\r\n\t" for character in text)
    controls = len(text) - printable
    cyrillic = sum("\u0400" <= character <= "\u04ff" for character in text)
    box = sum("\u2500" <= character <= "\u259f" for character in text)
    lowered = text.lower()
    common = sum(lowered.count(pair) for pair in _RUSSIAN_COMMON)
    return printable * 0.1 + cyrillic * 0.3 + common * 2.5 - controls * 5 - box * 0.8


def _looks_mixed_utf8(data: bytes) -> bool:
    decoded = data.decode("utf-8", "replace")
    replacements = decoded.count("\ufffd")
    non_ascii = sum(ord(character) > 127 and character != "\ufffd" for character in decoded)
    return replacements > 0 and non_ascii >= max(2, replacements * 2)


def _normalize(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\x00", "")
    return unicodedata.normalize("NFC", text)


def decode_bytes(
    data: bytes,
    *,
    locale_hint: str | None = None,
    path_locale_hint: str | None = None,
    strict: bool = False,
) -> DecodedText:
    """Decode bytes using deterministic hints and Cyrillic-aware fallback scoring."""

    if data.startswith(codecs.BOM_UTF8):
        text = data.decode("utf-8-sig", "strict")
        return DecodedText(_normalize(text), "utf-8-sig", DecodeStatus.EXACT, 0, False)
    if not data or all(byte < 128 for byte in data):
        text = data.decode("ascii")
        return DecodedText(_normalize(text), "ascii", DecodeStatus.EXACT, 0, False)
    try:
        text = data.decode("utf-8", "strict")
        return DecodedText(_normalize(text), "utf-8", DecodeStatus.EXACT, 0, False)
    except UnicodeDecodeError:
        pass

    hinted: list[str] = []
    for hint in (path_locale_hint, locale_hint):
        encoding = encoding_from_locale(hint)
        if encoding and encoding != "utf-8" and encoding not in hinted:
            hinted.append(encoding)
    candidates = hinted + [
        encoding
        for encoding in ("koi8-r", "cp1251", "iso-8859-5")
        if encoding not in hinted
    ]
    decoded_candidates = [(encoding, data.decode(encoding, "strict")) for encoding in candidates]
    if hinted:
        # An explicit codeset from the page path/locale is stronger evidence than
        # language-frequency heuristics (notably for roff pseudographics).
        best_encoding, best_text = decoded_candidates[0]
    else:
        best_encoding, best_text = max(
            decoded_candidates,
            key=lambda item: (_legacy_score(item[1]), -candidates.index(item[0])),
        )

    if _looks_mixed_utf8(data):
        replaced = data.decode("utf-8", "replace")
        error_count = replaced.count("\ufffd")
        result = DecodedText(
            _normalize(replaced),
            "utf-8",
            DecodeStatus.REPLACED,
            error_count,
            True,
        )
    else:
        result = DecodedText(
            _normalize(best_text),
            best_encoding,
            DecodeStatus.FALLBACK,
            0,
            "\ufffd" in best_text,
        )
    if strict and result.decode_status is not DecodeStatus.EXACT:
        raise StrictEncodingError(
            f"strict decoding rejected {result.source_encoding} "
            f"with status {result.decode_status}"
        )
    return result
