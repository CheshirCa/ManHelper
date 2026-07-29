from pathlib import Path
import tomllib

import manbase_builder


ROOT = Path(__file__).resolve().parents[1]


def test_project_versions_are_consistent() -> None:
    version_file = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    pyproject = tomllib.loads(
        (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    )
    assert version_file == "0.1.0"
    assert pyproject["project"]["version"] == version_file
    assert manbase_builder.__version__ == version_file


def test_non_commercial_license_and_attribution_are_present() -> None:
    license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
    assert license_text.startswith("Non-Commercial License")
    assert "commercial use of the software;" in license_text
    assert "Copyright (C) CheshirCa 2026" in license_text
    assert "https://t.me/cheshircanest" in license_text
    assert 'THE SOFTWARE IS PROVIDED "AS IS"' in license_text
