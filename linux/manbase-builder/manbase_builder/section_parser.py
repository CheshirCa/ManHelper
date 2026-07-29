"""Split rendered manual text into ordered, normalized sections."""

from __future__ import annotations

import re

from .models import ParsedSection, RelationWrite, SectionParseResult

SECTION_NAMES = {
    "NAME": "NAME",
    "ИМЯ": "NAME",
    "НАЗВАНИЕ": "NAME",
    "SYNOPSIS": "SYNOPSIS",
    "СИНТАКСИС": "SYNOPSIS",
    "DESCRIPTION": "DESCRIPTION",
    "ОПИСАНИЕ": "DESCRIPTION",
    "OPTIONS": "OPTIONS",
    "ПАРАМЕТРЫ": "OPTIONS",
    "ОПЦИИ": "OPTIONS",
    "COMMANDS": "COMMANDS",
    "КОМАНДЫ": "COMMANDS",
    "EXAMPLES": "EXAMPLES",
    "ПРИМЕРЫ": "EXAMPLES",
    "FILES": "FILES",
    "ФАЙЛЫ": "FILES",
    "ENVIRONMENT": "ENVIRONMENT",
    "ОКРУЖЕНИЕ": "ENVIRONMENT",
    "ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ": "ENVIRONMENT",
    "EXIT STATUS": "EXIT_STATUS",
    "EXIT_STATUS": "EXIT_STATUS",
    "КОД ВОЗВРАТА": "EXIT_STATUS",
    "RETURN VALUE": "RETURN_VALUE",
    "RETURN_VALUE": "RETURN_VALUE",
    "ВОЗВРАЩАЕМОЕ ЗНАЧЕНИЕ": "RETURN_VALUE",
    "ERRORS": "ERRORS",
    "ОШИБКИ": "ERRORS",
    "NOTES": "NOTES",
    "ПРИМЕЧАНИЯ": "NOTES",
    "BUGS": "BUGS",
    "ДЕФЕКТЫ": "BUGS",
    "SECURITY": "SECURITY",
    "БЕЗОПАСНОСТЬ": "SECURITY",
    "WARNINGS": "WARNINGS",
    "ПРЕДУПРЕЖДЕНИЯ": "WARNINGS",
    "SEE ALSO": "SEE_ALSO",
    "SEE_ALSO": "SEE_ALSO",
    "СМОТРИ ТАКЖЕ": "SEE_ALSO",
    "AUTHORS": "AUTHORS",
    "АВТОРЫ": "AUTHORS",
    "COPYRIGHT": "COPYRIGHT",
    "АВТОРСКИЕ ПРАВА": "COPYRIGHT",
}


def _heading_name(line: str) -> str | None:
    if not line or line[0].isspace():
        return None
    candidate = " ".join(line.strip().split())
    if not candidate or len(candidate) > 80 or not any(char.isalpha() for char in candidate):
        return None
    if candidate != candidate.upper():
        return None
    if not all(char.isalnum() or char in " _-" for char in candidate):
        return None
    return candidate


def _section_content(lines: list[str]) -> str:
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def _extract_summary(sections: list[ParsedSection]) -> str | None:
    name_section = next(
        (section for section in sections if section.normalized_name == "NAME"), None
    )
    if name_section is None:
        return None
    for line in name_section.content.splitlines():
        value = line.strip()
        if not value:
            continue
        match = re.match(r"^.+?\s+(?:-|–|—)\s+(.+)$", value)
        return match.group(1).strip() if match else None
    return None


def parse_sections(plain_text: str) -> SectionParseResult:
    """Parse headings conservatively while retaining unknown sections and order."""

    lines = plain_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    sections: list[ParsedSection] = []
    current_name: str | None = None
    current_normalized = "OTHER"
    content: list[str] = []
    have_heading = False

    def finish() -> None:
        nonlocal content
        if current_name is not None or content or not sections:
            body = _section_content(content)
            if current_name is not None or body:
                sections.append(
                    ParsedSection(
                        section_order=len(sections),
                        original_name=current_name,
                        normalized_name=current_normalized,
                        content=body,
                    )
                )
        content = []

    for line in lines:
        heading = _heading_name(line)
        if heading is None:
            content.append(line)
            continue
        if have_heading or any(item.strip() for item in content):
            finish()
        else:
            content = []
        current_name = heading
        current_normalized = SECTION_NAMES.get(heading, "OTHER")
        have_heading = True
    finish()

    summary = _extract_summary(sections)
    synopsis_section = next(
        (section for section in sections if section.normalized_name == "SYNOPSIS"),
        None,
    )
    synopsis = synopsis_section.content if synopsis_section is not None else None
    return SectionParseResult(tuple(sections), summary, synopsis)


def extract_relations(
    sections: tuple[ParsedSection, ...] | list[ParsedSection],
) -> tuple[RelationWrite, ...]:
    """Extract unique man-page references only from SEE ALSO sections."""

    references: list[RelationWrite] = []
    seen: set[tuple[str, str]] = set()
    pattern = re.compile(r"(?<![\w.+:-])([\w.+:-]+)\s*\(([1-9nl][\w.-]*)\)")
    for section in sections:
        if section.normalized_name != "SEE_ALSO":
            continue
        for match in pattern.finditer(section.content):
            key = (match.group(1), match.group(2))
            if key not in seen:
                seen.add(key)
                references.append(RelationWrite(key[0], key[1], "see_also"))
    return tuple(references)
