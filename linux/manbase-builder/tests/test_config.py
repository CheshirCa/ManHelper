from pathlib import Path

import pytest

from manbase_builder.config import BuilderConfig


def test_config_normalizes_paths() -> None:
    config = BuilderConfig(manpaths=("/tmp/man",), locales=("ru",))
    assert config.manpaths == (Path("/tmp/man"),)
    assert config.locales == ("ru",)


@pytest.mark.parametrize("field", ["max_page_size", "subprocess_timeout", "max_subprocess_output"])
def test_positive_limits(field: str) -> None:
    with pytest.raises(ValueError):
        BuilderConfig(**{field: 0})
