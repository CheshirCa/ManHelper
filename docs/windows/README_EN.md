# ManHelper for Windows: installation and usage

ManHelper 0.5.4 is a Windows tray application for looking up Linux manual
pages while working in PuTTY or KiTTY. It reads already-copied Unicode text,
parses shell-like command lines without executing them, and searches a local
SQLite man-page database opened read-only.

## Requirements

- 64-bit Windows 10 or Windows 11;
- PuTTY or KiTTY for the default terminal-process configuration;
- the files `ManHelper.exe` and `manbase.sqlite` from the release package.

No Python, Linux subsystem or installer is required for the portable package.

## Install the portable release

1. Download `ManHelper-0.5.4-windows-x64.zip` from GitHub Releases.
2. Optionally compare the archive hash with the repository release checksum.
3. Extract the complete ZIP into a separate folder.
4. Keep `ManHelper.exe` and `manbase.sqlite` together.
5. Run `ManHelper.exe`.

The application icon appears in the Windows notification area and may be
inside the hidden-icons menu. User notes, bookmarks, history and persisted
settings are stored separately in:

```text
%LOCALAPPDATA%\ManHelper\man-user.sqlite
```

Replacing the portable application folder or `manbase.sqlite` does not remove
that user database.

## Basic use

1. In PuTTY or KiTTY, select a command or command line.
2. Copy it normally.
3. Press `Ctrl+F1`.
4. If several manual sections match, choose the required result in the popup.
5. Open Details to read the full rendered text, source roff or stored sections.

The popup provides explicit copy, details and web-search actions. The Details
window supports command/page/section navigation, local Unicode text search,
copying displayed text, notes and bookmarks. The tray menu opens bookmarks and
history, settings, or exits the application.

ManHelper never sends `Ctrl+C` to the terminal and never executes the selected
text. The global hotkey reads the current clipboard only when the foreground
process matches a configured terminal.

## Settings

On first use the built-in defaults apply. To bootstrap custom values, copy
`settings.example.ini` to:

```text
%LOCALAPPDATA%\ManHelper\settings.ini
```

Supported keys:

```ini
[General]
terminal_processes = putty.exe,kitty.exe
clipboard_limit = 4096
hotkey = Ctrl+F1
database_path = manbase.sqlite
interface_language = ru
web_search_template = https://www.google.com/search?q={query}
browser_url_limit = 2048
```

- `terminal_processes` is a comma-separated executable-name list.
- `clipboard_limit` is clamped to 256–65536 characters.
- `hotkey` accepts `Ctrl`, `Alt`, `Shift` or `Win` plus `F1`–`F12`.
- A relative `database_path` is resolved from the `ManHelper.exe` directory.
  Absolute drive and UNC paths are also accepted.
- `interface_language` accepts `ru` or `en`; Russian is the default.
- `web_search_template` must begin with `http://` or `https://` and contain
  the literal `{query}`.
- `browser_url_limit` is clamped to 256–8192 characters.

Language, web-search template and URL limit are also persisted in the user
database and can be edited from the tray Settings window. Restart ManHelper
after changing settings to apply all changes.

## If the hotkey does not work

- Check that the tray icon is still present.
- Check whether another application has registered the same hotkey.
- Copy the text before pressing the hotkey.
- Ensure the foreground application is one of the configured terminal
  processes.
- Use `settings.ini` to select another supported hotkey if necessary.

## Build from source

Building is optional and is not needed for the portable release.

Requirements:

- PureBasic x64;
- Visual Studio C++ x64 Build Tools;
- PowerShell;
- the vendored SQLite amalgamation under `windows/validator/vendor/sqlite`.

From the repository root:

```powershell
cd windows\manhelper
.\build.ps1
```

The GUI executable is written to `build\ManHelper.exe` and is compiled without
a console window.

The validator is built separately:

```powershell
cd ..\validator
.\build.ps1
```

This creates `build\ManBaseValidator.exe` and
`build\ManBaseValidatorGUI.exe`. Validator usage:

```powershell
.\build\ManBaseValidator.exe --database C:\data\manbase.sqlite
.\build\ManBaseValidator.exe --database C:\data\manbase.sqlite --report report.json
.\build\ManBaseValidatorGUI.exe --database C:\data\manbase.sqlite
```

## License

Non-commercial use only. See `LICENSE`.
