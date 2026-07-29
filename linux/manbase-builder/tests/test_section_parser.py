from manbase_builder.section_parser import extract_relations, parse_sections


def test_english_page_and_summary() -> None:
    result = parse_sections(
        "NAME\n"
        "    printf - format and print data\n"
        "SYNOPSIS\n"
        "    printf FORMAT [ARGUMENT]...\n"
        "DESCRIPTION\n"
        "    Print data.\n"
    )
    assert [section.normalized_name for section in result.sections] == [
        "NAME",
        "SYNOPSIS",
        "DESCRIPTION",
    ]
    assert result.summary == "format and print data"
    assert result.synopsis == "    printf FORMAT [ARGUMENT]..."


def test_russian_page() -> None:
    result = parse_sections(
        "ИМЯ\n    тест — тестовая программа\n"
        "СИНТАКСИС\n    тест [ПАРАМЕТР]\n"
        "ОПИСАНИЕ\n    Русский текст.\n"
        "СМОТРИ ТАКЖЕ\n    printf(1)\n"
    )
    assert [section.normalized_name for section in result.sections] == [
        "NAME",
        "SYNOPSIS",
        "DESCRIPTION",
        "SEE_ALSO",
    ]
    assert result.summary == "тестовая программа"
    assert "ПАРАМЕТР" in (result.synopsis or "")


def test_mixed_headings_and_original_names() -> None:
    result = parse_sections("NAME\n x - mixed\nОПИСАНИЕ\n text\nOPTIONS\n -x\n")
    assert [section.original_name for section in result.sections] == [
        "NAME",
        "ОПИСАНИЕ",
        "OPTIONS",
    ]
    assert [section.section_order for section in result.sections] == [0, 1, 2]


def test_no_name_does_not_invent_summary() -> None:
    result = parse_sections("DESCRIPTION\nrandom - line\n")
    assert result.summary is None
    assert result.synopsis is None


def test_repeated_options_are_preserved() -> None:
    result = parse_sections("OPTIONS\n first\nOPTIONS\n second\n")
    options = [
        section for section in result.sections if section.normalized_name == "OPTIONS"
    ]
    assert len(options) == 2
    assert options[0].content == " first"
    assert options[1].content == " second"


def test_unknown_heading_is_preserved_as_other() -> None:
    result = parse_sections("HISTORY\n old text\nNAME\n x - utility\n")
    assert result.sections[0].original_name == "HISTORY"
    assert result.sections[0].normalized_name == "OTHER"
    assert result.sections[0].content == " old text"


def test_empty_section_is_preserved() -> None:
    result = parse_sections("NAME\nOPTIONS\nDESCRIPTION\n body\n")
    assert [(section.original_name, section.content) for section in result.sections] == [
        ("NAME", ""),
        ("OPTIONS", ""),
        ("DESCRIPTION", " body"),
    ]
    assert result.summary is None


def test_preamble_and_page_without_headings() -> None:
    with_preamble = parse_sections("manual header\nNAME\n x - utility\n")
    assert with_preamble.sections[0].normalized_name == "OTHER"
    assert with_preamble.sections[0].original_name is None
    assert with_preamble.sections[0].content == "manual header"

    no_headings = parse_sections("ordinary text\nsecond line")
    assert len(no_headings.sections) == 1
    assert no_headings.sections[0].normalized_name == "OTHER"
    assert no_headings.sections[0].content == "ordinary text\nsecond line"


def test_random_indented_uppercase_line_is_not_summary_or_heading() -> None:
    result = parse_sections("DESCRIPTION\n    NAME - not a heading\n")
    assert len(result.sections) == 1
    assert result.sections[0].normalized_name == "DESCRIPTION"
    assert result.summary is None


def test_see_also_relations_are_extracted_and_deduplicated() -> None:
    parsed = parse_sections(
        "DESCRIPTION\n printf(9) here is ordinary text\n"
        "SEE ALSO\n printf(1), printf(3), русская_команда(5), printf(1)\n"
    )
    relations = extract_relations(parsed.sections)
    assert [(item.target_name, item.target_section, item.relation_type) for item in relations] == [
        ("printf", "1", "see_also"),
        ("printf", "3", "see_also"),
        ("русская_команда", "5", "see_also"),
    ]
