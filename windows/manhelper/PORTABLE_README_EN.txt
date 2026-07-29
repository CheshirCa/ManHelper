ManHelper 0.5.4 — portable preview package

Quick start
===========

1. Extract the complete archive into a separate folder.
2. Run ManHelper.exe.
3. Find the ManHelper icon in the Windows notification area. It may be inside
   the hidden-icons menu.
4. In PuTTY or KiTTY, select and normally copy a command.
5. Press Ctrl+F1.

ManHelper does not send Ctrl+C, does not change the clipboard, and never
executes the selected command or any man-page text.

For normal operation, keep manbase.sqlite next to ManHelper.exe. The relative
value `database_path = manbase.sqlite` is resolved from the ManHelper.exe
folder, not the Windows working directory. User notes, bookmarks, history and
settings are stored separately in:

%LOCALAPPDATA%\ManHelper\man-user.sqlite

They remain when the portable package or manbase.sqlite is replaced.

Controls
========

- Double-click the tray icon to show the main window.
- Use the tray menu to open bookmarks/history and settings.
- Use Exit to close the application normally.
- Man text and source roff are read-only in the Details window.
- Notes are edited in a separate window.

If Ctrl+F1 does not work
========================

- make sure ManHelper is still running and its tray icon is present;
- check whether another application uses Ctrl+F1;
- make sure the command was copied from PuTTY or KiTTY;
- use settings.ini, based on settings.example.ini, to select another hotkey or
  change the terminal-process list.

Integrity
=========

SHA256SUMS.txt contains checksums for the package files.

License
=======

Non-commercial use only.
Copyright (C) CheshirCa 2026, https://t.me/cheshircanest
See LICENSE.txt for the full license text.
