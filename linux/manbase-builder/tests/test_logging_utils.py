import logging

import pytest

from manbase_builder.logging_utils import configure_logging


def test_logging_levels() -> None:
    configure_logging(verbose=True)
    assert logging.getLogger().level == logging.DEBUG
    configure_logging(quiet=True)
    assert logging.getLogger().level == logging.ERROR
    configure_logging()
    assert logging.getLogger().level == logging.INFO


def test_conflicting_logging_modes() -> None:
    with pytest.raises(ValueError):
        configure_logging(verbose=True, quiet=True)
