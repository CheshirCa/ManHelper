# ManBase Builder: installation and usage

ManBase Builder 0.1.0 is a Linux command-line program that scans installed man
pages and creates a portable Unicode SQLite database for ManHelper. It stores
rendered text, optionally stores source roff, resolves aliases, records page
sections and builds an FTS5 search index. Errors from individual pages are
recorded in `build_errors` without stopping the remaining import.

## Requirements

- Debian, Ubuntu, Armbian, or a compatible Linux distribution;
- Python 3.11 or newer;
- a roff renderer: `mandoc`, `groff`, or `man`;
- system `zstd` or the optional Python package `zstandard` for `.zst` pages.

Builder itself does not require root. On Debian-compatible systems, install
the recommended system packages with:

```bash
sudo apt-get update
sudo apt-get install python3 python3-venv groff man-db zstd
```

`mandoc` is optional and is selected before `groff` and `man` when installed:

```bash
sudo apt-get install mandoc
```

## Installation

From the repository root:

```bash
cd linux/manbase-builder
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install .
```

Verify the installation:

```bash
.venv/bin/manbase-builder --help
```

For development and tests:

```bash
.venv/bin/python -m pip install -e '.[test]'
.venv/bin/python -m pytest
```

## Build a database

```bash
.venv/bin/manbase-builder \
  --output debian13-amd64.sqlite \
  --profile-name "Debian 13 amd64"
```

The output is one SQLite file. By default the builder discovers system man
paths and retains source roff.

To scan only explicitly listed roots or locales, repeat `--manpath` or
`--locale` as needed:

```bash
.venv/bin/manbase-builder \
  --output local.sqlite \
  --manpath /usr/local/share/man \
  --locale ru
```

When at least one `--manpath` is supplied, default roots and the `manpath`
command are not used.

## Update, rebuild and validate

Update an existing database, replacing changed pages and removing missing
ones:

```bash
.venv/bin/manbase-builder --output debian13-amd64.sqlite --update
```

Delete the existing output and build it again:

```bash
.venv/bin/manbase-builder --output debian13-amd64.sqlite --rebuild
```

Validate an existing database:

```bash
.venv/bin/manbase-builder --output debian13-amd64.sqlite --validate
```

Successful validation returns exit code `0`; failure returns `2`.

## Supported options

```text
--output PATH                 required output database
--profile-name NAME           profile label for a new database
--manpath PATH                man root; may be repeated
--locale LOCALE               locale/language filter; may be repeated
--include-roff                store source roff (default)
--exclude-roff                omit source roff
--collect-help                probe section 1 commands for version/help text
--no-collect-help             do not probe commands (default)
--update                      update an existing database
--rebuild                     remove and rebuild the output database
--validate                    validate the database
--strict-encoding             reject fallback/replacement decoding
--max-page-size BYTES         decompressed page/output limit; default 16 MiB
--renderer mandoc|groff|man   force a renderer
--verbose                     verbose logging
--quiet                       suppress normal output
```

`--update` requires an existing database. `--collect-help` is opt-in and probes
eligible section 1 commands with closed standard input, time and output limits,
and a deny-list. It does not execute examples from man pages.

## Search the result

With the SQLite CLI:

```bash
sqlite3 debian13-amd64.sqlite \
  "SELECT name, section FROM page_fts WHERE page_fts MATCH 'journal';"
```

The FTS5 `unicode61` index covers page names, titles, summaries, rendered text
and section content.

## License

Non-commercial use only. See `LICENSE` in the component directory.
