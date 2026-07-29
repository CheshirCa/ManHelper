# Changelog

## 0.5.4 - 2026-07-28

- Fixed nested read-only section editors consuming the mouse wheel separately.
- Mouse-wheel input over any man section now scrolls the outer Details
  document with consistent steps and top/bottom clamping.
- Restored every subclassed editor procedure before dynamic section gadgets
  are freed.
- Added wheel-position, active-routing and cleanup regression tests.

## 0.5.3 - 2026-07-28

- Replaced the machine-specific `C:\Data\manbase.sqlite` example with the
  portable `database_path = manbase.sqlite`.
- Relative system-database paths are now resolved from the directory
  containing `ManHelper.exe`, not from the process working directory.
- Kept explicitly configured drive-absolute and UNC paths supported.
- Added regression tests for a neighboring database, a relative subdirectory
  and an absolute database path.

## 0.5.2 - 2026-07-28

- Fixed standalone wrapper commands such as `sudo` being discarded by the
  command parser.
- A wrapper is now skipped only when a downstream command remains after its
  options and assignments.
- Preserved existing behavior for `sudo systemctl`, `env LANG=C command` and
  other real wrapper invocations.
- Added parser and real-database regression tests for `sudo`, `sudo --version`,
  `env` and `sudo(8)`.

## 0.5.1 - 2026-07-28

- Shortened the localized popup selection label and reserved additional width
  so the native static control cannot wrap over adjacent rows.
- Filtered anonymous one-line man page headers such as
  `WHOAMI(1) User Commands WHOAMI(1)` from structured Details rendering.
- Kept genuine nonstandard sections such as `AUTHOR` and `REPORTING BUGS`.
- Added localization, decorative-header detection and real-database regression
  tests.

## 0.5.0 - 2026-07-28

- Rebuilt the popup as a compact borderless command card.
- Added terminal/page breadcrumbs, command typography, a syntax panel and a
  selected-text badge.
- Replaced equal-weight popup actions with one primary button and icon actions
  using the built-in Segoe MDL2 Assets font.
- Consolidated command, page and view selectors into one details toolbar.
- Consolidated local search and previous/next match navigation into one row.
- Replaced the flat full-page text dump with structured, scrollable man
  sections backed by dynamic read-only editor gadgets.
- Consolidated details actions into a primary Copy button and tooltip-backed
  note, bookmark and web-search icons.
- Added compact-popup and structured-section UI smoke tests.

## 0.4.0 - 2026-07-28

- Added a separate versioned user SQLite database with backup-before-migration.
- Added stable profile/page keys independent of system `pages.id`.
- Added Unicode notes in a separate editable window.
- Added bookmark toggling and bounded page-open history.
- Added tray access to bookmark/history management and persistent settings.
- Added profiles and search-provider storage with a default Google provider.
- Added migration, backup, Unicode, persistence and user-window smoke tests.
- Added a reproducible portable preview package with the validated man database,
  Russian quick-start instructions, license and SHA-256 checksums.
- Made GUI smoke tests wait for the process and verify its actual exit code.

## 0.3.4 - 2026-07-28

- Made normalized selected command text the primary web-search query.
- Fixed `apt install` opening a web search for the storage page `apt(8)`.
- Kept parsed command and `name(section)` as safe fallback query sources.

## 0.3.3 - 2026-07-28

- Preserved the selected shell-builtin name separately from its container page.
- Fixed web search for `logout` opening a query for `bash(1)`.

## 0.3.2 - 2026-07-28

- Fixed shell builtins such as `logout` resolving to same-named C library aliases.
- Details now opens the builtin-command section at the focused definition.

## 0.3.1 - 2026-07-28

- Added a dedicated multi-size Windows application icon and embedded tray icon.
- Made tray initialization failures visible to the user.
- Fixed the popup closing immediately when Windows had not yet assigned it foreground.
- Added automated popup lifecycle and tray registration regression tests.

## 0.3.0 - 2026-07-28

- Added parameterized loading of complete man pages and ordered non-empty sections.
- Added a resizable details window with pipeline, page and section navigation.
- Added read-only plain-text and source-roff views, Unicode find and explicit copy.
- Enabled popup Details and web-search actions.
- Added strict UTF-8 URL encoding and safe system-browser launch without `cmd.exe`.
- Expanded Russian localization and added an independent English UI mode.
- Added complete-page, browser, localization and details-window smoke tests.

## 0.2.0 - 2026-07-28

- Added non-executing shell-like command tokenization and wrapper-aware parsing.
- Added read-only access to the ManBase SQLite database and compatibility checks.
- Added parameterized exact, alias, command-info and Unicode FTS5 search.
- Added section-priority ranking and result selection in the popup.
- Added integration tests against the real Debian database with immutability checks.

## 0.1.0 - 2026-07-28

- Added tray lifecycle and global Ctrl+F1 registration.
- Added PuTTY/KiTTY foreground-process verification.
- Added immutable Unicode clipboard capture and normalization.
- Added a monitor-aware popup with explicit copy action.
- Added automated MVP and GUI-subsystem tests.
