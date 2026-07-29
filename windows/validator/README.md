# ManBase Validator for Windows

Read-only CLI and GUI validators for ManBase SQLite databases. They check
schema compatibility, SQLite integrity, stored checksums, Unicode page
content, page sections and the FTS5 index.

Build:

```powershell
.\build.ps1
```

Usage:

```powershell
.\build\ManBaseValidator.exe --database C:\data\manbase.sqlite
.\build\ManBaseValidator.exe --database C:\data\manbase.sqlite --report report.json
.\build\ManBaseValidator.exe --database C:\data\manbase.sqlite --report report.txt --format text
.\build\ManBaseValidatorGUI.exe --database C:\data\manbase.sqlite
```

See the [English](../../docs/windows/README_EN.md) or
[Russian](../../docs/windows/README_RU.md) Windows documentation for build
requirements.

Version: `0.2.0`.

Non-commercial use only. See [LICENSE](LICENSE).
