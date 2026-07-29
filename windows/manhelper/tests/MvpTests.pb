EnableExplicit

XIncludeFile "..\Version.pbi"
XIncludeFile "..\Models.pbi"
XIncludeFile "..\Localization.pbi"
XIncludeFile "..\Utils.pbi"
XIncludeFile "..\TextNormalize.pbi"
XIncludeFile "..\Clipboard.pbi"
XIncludeFile "..\WindowDetect.pbi"
XIncludeFile "..\HotKey.pbi"
XIncludeFile "..\Tray.pbi"
XIncludeFile "..\Settings.pbi"
XIncludeFile "..\CommandTokenizer.pbi"
XIncludeFile "..\CommandParser.pbi"
XIncludeFile "..\Database.pbi"
XIncludeFile "..\DatabaseCompatibility.pbi"
XIncludeFile "..\SearchRank.pbi"
XIncludeFile "..\SearchExact.pbi"
XIncludeFile "..\SearchFts.pbi"
XIncludeFile "..\PageRepository.pbi"
XIncludeFile "..\Browser.pbi"
XIncludeFile "..\PopupWindow.pbi"
XIncludeFile "..\UserDatabase.pbi"
XIncludeFile "..\UserData.pbi"
XIncludeFile "..\NotesWindow.pbi"
XIncludeFile "..\UserLibraryWindow.pbi"
XIncludeFile "..\SettingsWindow.pbi"

OpenConsole("ManHelper MVP tests")

Global Failures.i
Define Selection.Models::Selection
Define TerminalPath.s
Define ClipboardBefore.s
Define ClipboardAfter.s
Define ParsedModifiers.i
Define ParsedKey.i
Define DatabasePath.s = ProgramParameter(0)
Define UserDatabasePath.s = ProgramParameter(1)
Define Parsed.Models::ParsedCommand
Define Compatibility.Models::DatabaseCompatibility
Define Results.Models::SearchResults
Define Page.Models::ManualPage
Define Url.String
Define BrowserError.String
Define PreviousSectionOrder.i = -1
Define UserRef.Models::UserPageRef
Define SamePageRef.Models::UserPageRef
Define NoteText.String
Define HasDecorativeHeader.i
Define DecorativeHeader.s

Procedure AssertTrue(Value.i, Name.s)
  If Value = #False
    PrintN("FAIL " + Name)
    Failures + 1
  Else
    PrintN("PASS " + Name)
  EndIf
EndProcedure

Procedure AssertText(Actual.s, Expected.s, Name.s)
  If Actual <> Expected
    PrintN("FAIL " + Name)
    Failures + 1
  Else
    PrintN("PASS " + Name)
  EndIf
EndProcedure

Procedure AssertParsed(Text.s, ExpectedCommand.s, ExpectedArguments.i, Name.s)
  Shared Parsed.Models::ParsedCommand
  CommandParser::Parse(Text, Text, @Parsed)
  AssertText(Parsed\PrimaryCommand, ExpectedCommand, Name + " command")
  AssertTrue(Bool(ListSize(Parsed\Arguments()) = ExpectedArguments),
             Name + " arguments")
EndProcedure

InitializeStructure(@Selection, Models::Selection)
Selection\OriginalText = "systemctl" + #CRLF$ + "статус" + Chr(1) + #TAB$ + "😀"
TextNormalize::Normalize(@Selection, 4096)
AssertText(Selection\NormalizedText, "systemctl" + #LF$ + "статус" + #TAB$ + "😀", "Unicode normalization")
AssertTrue(Bool(ListSize(Selection\Warnings()) = 1), "Control warning")

ClearStructure(@Selection, Models::Selection)
InitializeStructure(@Selection, Models::Selection)
Selection\OriginalText = LSet("", 4200, "x")
TextNormalize::Normalize(@Selection, 4096)
AssertTrue(Bool(Len(Selection\NormalizedText) = 4096), "Clipboard limit")
AssertTrue(Selection\WasTruncated, "Truncation flag")

AssertTrue(WindowDetect::IsSupportedProcess("PUTTY.EXE", "putty.exe,kitty.exe"), "PuTTY process")
AssertTrue(WindowDetect::IsSupportedProcess("kitty.exe", "putty.exe,kitty.exe"), "KiTTY process")
AssertTrue(Bool(WindowDetect::IsSupportedProcess("notepad.exe", "putty.exe,kitty.exe") = #False), "Unsupported process")
AssertTrue(Settings::ParseHotKey("Ctrl+Shift+F12", @ParsedModifiers, @ParsedKey), "Parse configurable hotkey")
AssertTrue(Bool(ParsedModifiers = ($0002 | $0004)), "Parsed hotkey modifiers")
AssertTrue(Bool(ParsedKey = $7B), "Parsed hotkey key")
AssertTrue(Bool(Settings::ParseHotKey("Ctrl+F99", @ParsedModifiers, @ParsedKey) = #False), "Reject invalid hotkey")
AssertTrue(Bool(DetailsWindow::WheelPosition(100, 120, 500) = 46),
           "Mouse wheel scrolls outer content upward")
AssertTrue(Bool(DetailsWindow::WheelPosition(10, 120, 500) = 0),
           "Mouse wheel clamps at content top")
AssertTrue(Bool(DetailsWindow::WheelPosition(490, -120, 500) = 500),
           "Mouse wheel clamps at content bottom")
AssertText(Settings::ResolveDatabasePath("manbase.sqlite"),
           GetPathPart(ProgramFilename()) + "manbase.sqlite",
           "Relative database path uses executable directory")
AssertText(Settings::ResolveDatabasePath("data\manbase.sqlite"),
           GetPathPart(ProgramFilename()) + "data\manbase.sqlite",
           "Relative database subdirectory uses executable directory")
AssertText(Settings::ResolveDatabasePath("D:\Data\manbase.sqlite"),
           "D:\Data\manbase.sqlite", "Absolute database path is preserved")
Localization::SetLanguage("en")
AssertText(Localization::Text("details_title"), "Manual details",
           "English interface localization")
AssertText(Localization::Text("popup_selection"), "Selected",
           "Compact English selection label")
Localization::SetLanguage("ru")
AssertText(Localization::Text("details_title"), "Подробная справка",
           "Russian interface localization")
AssertText(Localization::Text("popup_selection"), "Выделено",
           "Compact Russian selection label")

AssertText(Browser::EncodeQuery("тест &?#" + #DQUOTE$),
           "%D1%82%D0%B5%D1%81%D1%82%20%26%3F%23%22",
           "UTF-8 reserved URL encoding")
AssertTrue(Browser::BuildUrl("systemctl status", "https://example.test/?q={query}",
                             2048, @Url, @BrowserError),
           "Build safe browser URL")
AssertText(Url\s, "https://example.test/?q=systemctl%20status",
           "Browser URL value")
AssertText(Browser::ResolveQuery("apt install", "apt", "apt", "8"),
           "apt install", "Web query prefers selected command text")
AssertText(Browser::ResolveQuery("", "logout", "bash", "1"),
           "logout", "Web query falls back to parsed command")
AssertText(Browser::ResolveQuery("", "", "bash", "1"),
           "bash(1)", "Web query page fallback")
AssertTrue(Browser::BuildUrl(Browser::ResolveQuery("apt install", "apt",
                                                   "apt", "8"),
                             "https://www.google.com/search?q={query}",
                             2048, @Url, @BrowserError),
           "Selected command web URL")
AssertText(Url\s, "https://www.google.com/search?q=apt%20install",
           "Selected command web URL value")
AssertTrue(Bool(Browser::BuildUrl("test", "file:///{query}", 2048,
                                  @Url, @BrowserError) = #False),
           "Reject unsafe browser scheme")
AssertTrue(Bool(Browser::BuildUrl(LSet("", 300, "x"),
                                  "https://example.test/?q={query}", 256,
                                  @Url, @BrowserError) = #False),
           "Enforce browser URL limit")

AssertTrue(UserDatabase::Initialize(UserDatabasePath),
           "Migrate user database")
AssertTrue(Bool(UserDatabase::LastBackupPath() <> ""),
           "Backup before user database migration")
AssertTrue(Bool(FileSize(UserDatabase::LastBackupPath()) >= 0),
           "User database backup exists")
AssertTrue(Bool(UserData::CountRows("notes") = 0), "Notes table")
AssertTrue(Bool(UserData::CountRows("bookmarks") = 0), "Bookmarks table")
AssertTrue(Bool(UserData::CountRows("history") = 0), "History table")
AssertTrue(Bool(UserData::CountRows("settings") = 0), "Settings table")
AssertTrue(Bool(UserData::CountRows("profiles") = 0), "Profiles table")
AssertTrue(Bool(UserData::CountRows("search_providers") = 1),
           "Default search provider")

InitializeStructure(@Page, Models::ManualPage)
Page\Id = 111
Page\ProfileKey = "Debian GNU/Linux|13|x86_64"
Page\Name = "systemctl"
Page\Section = "1"
Page\Language = "ru"
Page\Locale = "ru_RU.UTF-8"
UserData::MakePageRef(@Page, @UserRef)
AssertTrue(UserData::SaveNote(@UserRef, "Русская заметка 😀"),
           "Save Unicode note")
AssertTrue(UserData::LoadNote(@UserRef, @NoteText), "Load Unicode note")
AssertText(NoteText\s, "Русская заметка 😀", "Unicode note value")
AssertTrue(UserData::SetBookmarked(@UserRef, #True), "Add bookmark")
AssertTrue(UserData::IsBookmarked(@UserRef), "Bookmark state")
AssertTrue(UserData::AddHistory(@UserRef, "sudo systemctl status"),
           "Add history")
AssertTrue(UserData::RegisterProfile(@UserRef), "Register user profile")
AssertTrue(UserData::SaveSetting("test_unicode", "значение"),
           "Save user setting")
AssertTrue(UserData::LoadSetting("test_unicode", @NoteText),
           "Load user setting")
AssertText(NoteText\s, "значение", "User setting value")

Page\Id = 999999
UserData::MakePageRef(@Page, @SamePageRef)
AssertText(SamePageRef\PageKey, UserRef\PageKey,
           "Stable page key ignores system row id")
AssertTrue(UserData::LoadNote(@SamePageRef, @NoteText),
           "Note survives system page id change")
AssertText(NoteText\s, "Русская заметка 😀",
           "Persisted note after page id change")
AssertTrue(UserData::SetBookmarked(@UserRef, #False), "Remove bookmark")
AssertTrue(Bool(UserData::IsBookmarked(@UserRef) = #False),
           "Bookmark removed")
AssertTrue(UserData::DeleteNote(@UserRef), "Delete note")
AssertTrue(NotesWindow::Show(@UserRef), "Notes window smoke")
AssertTrue(NotesWindow::IsOpen(), "Notes window is open")
NotesWindow::Close()
AssertTrue(UserLibraryWindow::Show(), "User library window smoke")
AssertTrue(UserLibraryWindow::IsOpen(), "User library window is open")
UserLibraryWindow::Close()
AssertTrue(SettingsWindow::Show(), "Settings window smoke")
AssertTrue(SettingsWindow::IsOpen(), "Settings window is open")
SettingsWindow::Close()
UserDatabase::Close()
ClearStructure(@Page, Models::ManualPage)
AssertTrue(Bool(PopupWindow::ShouldCloseForForeground(#False, 100, 200, 1000) = #False),
           "Popup does not close before receiving focus")
AssertTrue(Bool(PopupWindow::ShouldCloseForForeground(#True, 100, 100, 1000) = #False),
           "Focused popup remains open")
AssertTrue(PopupWindow::ShouldCloseForForeground(#True, 100, 200, 1000),
           "Popup closes after actual focus loss")

TerminalPath = WindowDetect::ExecutablePathForProcessId(GetCurrentProcessId_())
AssertTrue(Bool(TerminalPath <> ""), "Current executable path")
AssertText(LCase(GetFilePart(TerminalPath)), "mvptests.exe", "Current executable name")

ClipboardBefore = GetClipboardText()
ClipboardReader::Capture(@Selection, 4096)
ClipboardAfter = GetClipboardText()
AssertText(ClipboardAfter, ClipboardBefore, "Clipboard remains unchanged")

InitializeStructure(@Parsed, Models::ParsedCommand)
AssertParsed("systemctl restart nginx", "systemctl", 2, "Simple parser")
AssertParsed("sudo", "sudo", 0, "Standalone sudo command")
AssertParsed("sudo --version", "sudo", 1, "Standalone sudo option")
AssertParsed("env", "env", 0, "Standalone env command")
AssertParsed("sudo systemctl restart nginx", "systemctl", 2, "Sudo wrapper")
AssertParsed("sudo -u root systemctl status nginx", "systemctl", 2, "Sudo option")
AssertParsed("LANG=C systemctl status nginx", "systemctl", 2, "Assignment")
AssertParsed("env LANG=ru_RU.UTF-8 journalctl -u nginx", "journalctl", 2, "Env wrapper")
AssertParsed("nohup rsync -a source destination", "rsync", 3, "Nohup wrapper")
AssertParsed("/usr/bin/find /var/log -type f", "find", 3, "Command path")
AssertParsed("$ systemctl status nginx", "systemctl", 2, "Shell prompt")
AssertParsed("echo " + #DQUOTE$ + "привет мир" + #DQUOTE$, "echo", 1,
             "Unicode quoted argument")
AssertParsed("echo hello\ world", "echo", 1, "Escaped whitespace")
CommandParser::Parse("journalctl -u nginx | grep error", "journalctl -u nginx | grep error", @Parsed)
AssertText(Parsed\PrimaryCommand, "journalctl", "Pipeline primary command")
AssertTrue(Bool(ListSize(Parsed\Commands()) = 2), "Pipeline command list")
LastElement(Parsed\Commands())
AssertText(Parsed\Commands(), "grep", "Pipeline secondary command")
CommandParser::Parse("true && false || echo ok; date", "true && false || echo ok; date", @Parsed)
AssertTrue(Bool(ListSize(Parsed\Commands()) = 4), "Shell operator command list")
CommandParser::Parse("echo " + #DQUOTE$ + "незакрытая", "echo " + #DQUOTE$ + "незакрытая", @Parsed)
AssertTrue(Bool(ListSize(Parsed\Warnings()) = 1), "Unclosed quote warning")
CommandParser::Parse("", "", @Parsed)
AssertText(Parsed\PrimaryCommand, "", "Empty command")
AssertTrue(Bool(ListSize(Parsed\Warnings()) = 0), "Empty command has no warning")

InitializeStructure(@Compatibility, Models::DatabaseCompatibility)
InitializeStructure(@Results, Models::SearchResults)
AssertTrue(Database::OpenReadOnly(DatabasePath), "Open system database read-only")
DatabaseCompatibility::Check(@Compatibility)
AssertTrue(Compatibility\IsCompatible, "Database compatibility")
AssertTrue(Compatibility\FtsAvailable, "FTS5 availability")
AssertTrue(Bool(Compatibility\ProfileId = 1), "Database profile")

SearchExact::Search("sudo", Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) > 0), "Exact sudo search")
If ListSize(Results\Pages()) > 0
  FirstElement(Results\Pages())
  AssertText(Results\Pages()\Name, "sudo", "Standalone sudo result name")
  AssertText(Results\Pages()\Section, "8", "Standalone sudo result section")
EndIf

SearchExact::Search("systemctl", Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) > 0), "Exact systemctl search")
If ListSize(Results\Pages()) > 0
  FirstElement(Results\Pages())
  AssertText(Results\Pages()\Name, "systemctl", "Exact result name")
  AssertText(Results\Pages()\Section, "1", "Exact result section")
  InitializeStructure(@Page, Models::ManualPage)
  AssertTrue(PageRepository::LoadPage(Results\Pages()\Id, @Page),
             "Load complete page by parameter")
  AssertText(Page\Name, "systemctl", "Complete page name")
  AssertTrue(Bool(Len(Page\PlainText) > 1000), "Complete plain text")
  AssertTrue(Bool(ListSize(Page\Sections()) > 0), "Non-empty page sections")
  ForEach Page\Sections()
    AssertTrue(Bool(Trim(Page\Sections()\Content) <> ""),
               "Empty sections hidden")
    AssertTrue(Bool(Page\Sections()\Order > PreviousSectionOrder),
               "Page sections ordered")
    PreviousSectionOrder = Page\Sections()\Order
  Next
  ClearStructure(@Page, Models::ManualPage)
EndIf

DecorativeHeader = "WHOAMI(1)        User Commands        WHOAMI(1)"
HasDecorativeHeader = PageRepository::IsDecorativeHeader("whoami", "1", "", "OTHER", DecorativeHeader)
AssertTrue(HasDecorativeHeader, "Detect decorative man header")
HasDecorativeHeader = PageRepository::IsDecorativeHeader("whoami", "1", "AUTHOR", "OTHER", "Written by Richard Mlynarik.")
AssertTrue(Bool(HasDecorativeHeader = #False),
           "Keep real nonstandard section")
SearchExact::Search("whoami(1)", Compatibility\ProfileId, @Results)
If ListSize(Results\Pages()) > 0
  FirstElement(Results\Pages())
  AssertTrue(PageRepository::LoadPage(Results\Pages()\Id, @Page),
             "Load whoami page")
  HasDecorativeHeader = #False
  ForEach Page\Sections()
    If Page\Sections()\OriginalName = "" And
       UCase(Page\Sections()\NormalizedName) = "OTHER"
      HasDecorativeHeader = #True
    EndIf
  Next
  AssertTrue(Bool(HasDecorativeHeader = #False),
             "Decorative man header is filtered")
  ClearStructure(@Page, Models::ManualPage)
EndIf

SearchExact::Search("printf(3)", Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) = 1), "Name and section search")
If ListSize(Results\Pages()) = 1
  FirstElement(Results\Pages())
  AssertText(Results\Pages()\Section, "3", "Requested section remains separate")
EndIf

SearchExact::Search("printf", Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) = 2), "Multiple sections returned")
If ListSize(Results\Pages()) = 2
  FirstElement(Results\Pages())
  AssertText(Results\Pages()\Section, "1", "Section ranking")
EndIf

SearchExact::Search("CIRCLEQ_EMPTY", Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) > 0), "Alias search")
If ListSize(Results\Pages()) > 0
  FirstElement(Results\Pages())
  AssertText(Results\Pages()\Name, "circleq", "Alias target")
  AssertText(Results\Pages()\MatchKind, "alias", "Alias match kind")
EndIf

SearchExact::Search("logout", Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) = 1), "Shell builtin search")
If ListSize(Results\Pages()) = 1
  FirstElement(Results\Pages())
  AssertText(Results\Pages()\Name, "bash", "Shell builtin target page")
  AssertText(Results\Pages()\Section, "1", "Shell builtin target section")
  AssertText(Results\Pages()\MatchKind, "shell_builtin",
             "Shell builtin match kind")
  AssertTrue(Bool(FindString(LCase(Results\Pages()\Synopsis),
                             "exit a login shell") > 0),
             "Shell builtin focused description")
  AssertText(Results\Pages()\PreferredSection, "SHELL BUILTIN COMMANDS",
             "Shell builtin preferred section")
  AssertTrue(Bool(FindString(LCase(Results\Pages()\InitialSearch),
                             "logout exit a login shell") > 0),
             "Shell builtin initial search")
  AssertText(Results\Pages()\WebQuery, "logout",
             "Shell builtin web query")
  AssertTrue(Browser::BuildUrl(Results\Pages()\WebQuery,
                               "https://www.google.com/search?q={query}",
                               2048, @Url, @BrowserError),
             "Shell builtin web URL")
  AssertText(Url\s, "https://www.google.com/search?q=logout",
             "Shell builtin web URL value")
EndIf

SearchExact::Search("manhelper-command-that-does-not-exist",
                    Compatibility\ProfileId, @Results)
AssertTrue(Bool(ListSize(Results\Pages()) = 0), "Missing exact command")

SearchFts::Search("service", Compatibility\ProfileId, @Results)
AssertTrue(Bool(Results\ErrorMessage = ""), "English FTS executes")
AssertTrue(Bool(ListSize(Results\Pages()) > 0), "English FTS results")
SearchFts::Search("система", Compatibility\ProfileId, @Results)
AssertTrue(Bool(Results\ErrorMessage = ""), "Unicode FTS executes")

ClearStructure(@Parsed, Models::ParsedCommand)
InitializeStructure(@Parsed, Models::ParsedCommand)
CommandParser::Parse("systemctl", "systemctl", @Parsed)
Selection\OriginalText = "systemctl"
Selection\NormalizedText = "systemctl"
ClearList(Selection\Warnings())
SearchExact::Search("systemctl", Compatibility\ProfileId, @Results)
AssertTrue(PopupWindow::Show(@Selection, @Parsed, @Results, "kitty.exe", 0,
                             Compatibility\ProfileId,
                             Compatibility\FtsAvailable,
                             "https://www.google.com/search?q={query}", 2048),
           "Redesigned popup smoke")
AssertTrue(Bool(WindowWidth(PopupWindow::WindowNumber()) = 440 And
                WindowHeight(PopupWindow::WindowNumber()) = 304),
           "Compact popup dimensions")
PopupWindow::Close()
If ListSize(Results\Pages()) > 0
  FirstElement(Results\Pages())
  AssertTrue(DetailsWindow::Show(@Parsed, Results\Pages()\Id,
                                 Compatibility\ProfileId,
                                 Compatibility\FtsAvailable,
                                 "https://www.google.com/search?q={query}",
                                 2048),
             "Redesigned details smoke")
  AssertTrue(Bool(DetailsWindow::RenderedBlockCount() > 1),
             "Structured manual section rendering")
  AssertTrue(Bool(DetailsWindow::WheelRoutingCount() = DetailsWindow::RenderedBlockCount()),
             "Section editors route mouse wheel to outer scroll area")
  DetailsWindow::Close()
  AssertTrue(Bool(DetailsWindow::WheelRoutingCount() = 0),
             "Section mouse wheel hooks are released")
EndIf
Database::Close()

If OpenWindow(0, 0, 0, 1, 1, "hotkey-test", #PB_Window_Invisible)
  AssertTrue(Tray::Initialize(0, "Ctrl+F1"), "Create application tray icon")
  AssertTrue(Tray::IsReady(), "Application tray icon is present")
  Tray::Shutdown()
  AssertTrue(HotKey::Register(WindowID(0), $0002 | $0004, $7B), "Register global hotkey")
  AssertTrue(HotKey::Register(WindowID(0), $0002 | $0004, $7B), "Repeat hotkey registration")
  If OpenWindow(1, 0, 0, 1, 1, "hotkey-conflict-test", #PB_Window_Invisible)
    AssertTrue(Bool(RegisterHotKey_(WindowID(1), $1234, $0002 | $0004, $7B) = #False), "Occupied hotkey is rejected")
    CloseWindow(1)
  EndIf
  HotKey::Unregister()
  AssertTrue(HotKey::Register(WindowID(0), $0002 | $0004, $7B), "Register hotkey after release")
  HotKey::Unregister()
  CloseWindow(0)
Else
  PrintN("FAIL Hidden test window")
  Failures + 1
EndIf

End Failures
