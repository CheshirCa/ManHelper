EnableExplicit

XIncludeFile "Version.pbi"
XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "Utils.pbi"
XIncludeFile "Settings.pbi"
XIncludeFile "Logging.pbi"
XIncludeFile "AppState.pbi"
XIncludeFile "Tray.pbi"
XIncludeFile "HotKey.pbi"
XIncludeFile "WindowDetect.pbi"
XIncludeFile "TextNormalize.pbi"
XIncludeFile "Clipboard.pbi"
XIncludeFile "PopupPosition.pbi"
XIncludeFile "PopupWindow.pbi"
XIncludeFile "CommandTokenizer.pbi"
XIncludeFile "CommandParser.pbi"
XIncludeFile "Database.pbi"
XIncludeFile "DatabaseCompatibility.pbi"
XIncludeFile "SearchRank.pbi"
XIncludeFile "SearchExact.pbi"
XIncludeFile "SearchFts.pbi"
XIncludeFile "PageRepository.pbi"
XIncludeFile "Browser.pbi"
XIncludeFile "DetailsWindow.pbi"
XIncludeFile "UserDatabase.pbi"
XIncludeFile "UserData.pbi"
XIncludeFile "NotesWindow.pbi"
XIncludeFile "UserLibraryWindow.pbi"
XIncludeFile "SettingsWindow.pbi"

Enumeration Windows
  #WindowMain
EndEnumeration

UseModule AppState

Procedure ShowClipboardPopup(RequireTerminal.i)
  If PopupWindow::IsOpen()
    PopupWindow::Close()
    ProcedureReturn
  EndIf

  If RequireTerminal
    WindowDetect::GetForegroundTerminal(@Terminal, Settings\SupportedProcesses)
    If Terminal\IsSupported = #False
      Logging::Write("INFO", "Hotkey ignored for foreground process: " + Terminal\ExecutableName)
      ProcedureReturn
    EndIf
  Else
    ClearStructure(@Terminal, Models::TerminalWindow)
    Terminal\WindowHandle = GetForegroundWindow_()
    Terminal\ExecutableName = Localization::Text("popup_tray_source")
  EndIf

  ClipboardReader::Capture(@Selection, Settings\ClipboardLimit)
  CommandParser::Parse(Selection\OriginalText, Selection\NormalizedText, @Parsed)
  ForEach Parsed\Warnings()
    AddElement(Selection\Warnings())
    Selection\Warnings() = Parsed\Warnings()
  Next

  ClearList(Results\Pages())
  Results\Query = Parsed\PrimaryCommand
  Results\ErrorMessage = ""
  If DatabaseReady And Parsed\PrimaryCommand <> ""
    SearchExact::Search(Parsed\PrimaryCommand, Compatibility\ProfileId, @Results)
    If ListSize(Results\Pages()) = 0 And Compatibility\FtsAvailable
      SearchFts::Search(Parsed\PrimaryCommand, Compatibility\ProfileId, @Results)
    EndIf
    If ListSize(Results\Pages()) = 0
      AddElement(Selection\Warnings())
      Selection\Warnings() = Localization::Text("database_no_results")
    EndIf
  ElseIf DatabaseReady = #False
    AddElement(Selection\Warnings())
    If Compatibility\Message <> ""
      Selection\Warnings() = Compatibility\Message
    Else
      Selection\Warnings() = Localization::Text("database_not_configured")
    EndIf
  EndIf
  PopupWindow::Show(@Selection, @Parsed, @Results,
                    Terminal\ExecutableName, Terminal\WindowHandle,
                    Compatibility\ProfileId, Compatibility\FtsAvailable,
                    Settings\WebSearchTemplate, Settings\BrowserUrlLimit)
EndProcedure

Define SmokeTest.i
Define DetailsSmokeTest.i
Define ExitCode.i
Define Index.i
For Index = 0 To CountProgramParameters() - 1
  If ProgramParameter(Index) = "--smoke-test"
    SmokeTest = #True
  ElseIf ProgramParameter(Index) = "--details-smoke-test"
    DetailsSmokeTest = #True
  EndIf
Next

Settings::Load(@Settings)
Localization::SetLanguage(Settings\InterfaceLanguage)
Logging::Initialize()

If SmokeTest = #False And DetailsSmokeTest = #False
  If UserDatabase::Initialize(Utils::UserDatabasePath())
    Define StoredValue.String
    If UserData::LoadSetting("interface_language", @StoredValue)
      Settings\InterfaceLanguage = StoredValue\s
    Else
      UserData::SaveSetting("interface_language", Settings\InterfaceLanguage)
    EndIf
    If UserData::LoadSetting("web_search_template", @StoredValue)
      Settings\WebSearchTemplate = StoredValue\s
    Else
      UserData::SaveSetting("web_search_template", Settings\WebSearchTemplate)
    EndIf
    If UserData::LoadSetting("browser_url_limit", @StoredValue)
      Settings\BrowserUrlLimit = Val(StoredValue\s)
    Else
      UserData::SaveSetting("browser_url_limit", Str(Settings\BrowserUrlLimit))
    EndIf
    If Settings\BrowserUrlLimit < 256
      Settings\BrowserUrlLimit = 256
    ElseIf Settings\BrowserUrlLimit > 8192
      Settings\BrowserUrlLimit = 8192
    EndIf
    Localization::SetLanguage(Settings\InterfaceLanguage)
  Else
    Logging::Write("ERROR", Localization::Text("user_database_error") + " " +
                   UserDatabase::LastError())
    MessageRequester(Localization::Text("app_title"),
                     Localization::Text("user_database_error"),
                     #PB_MessageRequester_Error)
  EndIf
EndIf

If SmokeTest = #False And Settings\DatabasePath <> ""
  If Database::OpenReadOnly(Settings\DatabasePath)
    DatabaseCompatibility::Check(@Compatibility)
    DatabaseReady = Compatibility\IsCompatible
    Logging::Write("INFO", Compatibility\Message)
  Else
    Compatibility\Message = Localization::Text("database_open_failed")
    Logging::Write("ERROR", Compatibility\Message + " " + Settings\DatabasePath)
  EndIf
ElseIf Settings\DatabasePath = ""
  Compatibility\Message = Localization::Text("database_not_configured")
EndIf

If OpenWindow(#WindowMain, 0, 0, 1, 1, Localization::Text("app_title"),
              #PB_Window_Invisible) = 0
  End 1
EndIf

Define TrayReady.i = Tray::Initialize(#WindowMain, Settings\HotKeyDisplay)
If TrayReady = #False
  Logging::Write("ERROR", "System tray initialization failed.")
  MessageRequester(Localization::Text("app_title"),
                   Localization::Text("tray_error"),
                   #PB_MessageRequester_Error)
  ExitCode = 1
  PostEvent(#PB_Event_CloseWindow, #WindowMain, 0)
EndIf

If TrayReady And SmokeTest = #False And DetailsSmokeTest = #False
  If HotKey::Register(WindowID(#WindowMain), Settings\HotKeyModifiers,
                      Settings\HotKeyVirtualKey) = #False
    Logging::Write("ERROR", "RegisterHotKey failed: " + Str(HotKey::LastErrorCode()))
    MessageRequester(Localization::Text("app_title"),
                     Localization::Text("hotkey_error") + Settings\HotKeyDisplay,
                     #PB_MessageRequester_Error)
  EndIf
ElseIf TrayReady And SmokeTest
  PostEvent(#PB_Event_CloseWindow, #WindowMain, 0)
ElseIf TrayReady
  InitializeStructure(@Parsed, Models::ParsedCommand)
  Parsed\PrimaryCommand = "systemctl"
  AddElement(Parsed\Commands())
  Parsed\Commands() = Parsed\PrimaryCommand
  SearchExact::Search(Parsed\PrimaryCommand, Compatibility\ProfileId, @Results)
  If ListSize(Results\Pages()) > 0
    FirstElement(Results\Pages())
    DetailsWindow::Show(@Parsed, Results\Pages()\Id, Compatibility\ProfileId,
                        Compatibility\FtsAvailable, Settings\WebSearchTemplate,
                        Settings\BrowserUrlLimit)
    PostEvent(#PB_Event_CloseWindow, DetailsWindow::WindowNumber(), 0)
  Else
    ExitCode = 1
  EndIf
  PostEvent(#PB_Event_CloseWindow, #WindowMain, 0)
EndIf

Define Event.i
Repeat
  Event = WaitWindowEvent()
  If NotesWindow::IsOpen() And EventWindow() = NotesWindow::WindowNumber()
    NotesWindow::HandleEvent(Event)
  ElseIf UserLibraryWindow::IsOpen() And
         EventWindow() = UserLibraryWindow::WindowNumber()
    UserLibraryWindow::HandleEvent(Event)
  ElseIf SettingsWindow::IsOpen() And
         EventWindow() = SettingsWindow::WindowNumber()
    SettingsWindow::HandleEvent(Event)
  ElseIf DetailsWindow::IsOpen() And EventWindow() = DetailsWindow::WindowNumber()
    DetailsWindow::HandleEvent(Event)
  ElseIf PopupWindow::IsOpen() And EventWindow() = PopupWindow::WindowNumber()
    PopupWindow::HandleEvent(Event)
  Else
    Select Event
      Case #WM_HOTKEY
        ShowClipboardPopup(#True)
      Case #PB_Event_CloseWindow
        Running = #False
      Case #PB_Event_SysTray
        If EventType() = #PB_EventType_LeftDoubleClick
          ShowClipboardPopup(#False)
        EndIf
      Case #PB_Event_Menu
        Select EventMenu()
          Case Tray::#MenuShow
            ShowClipboardPopup(#False)
          Case Tray::#MenuLibrary
            UserLibraryWindow::Show()
          Case Tray::#MenuSettings
            SettingsWindow::Show()
          Case Tray::#MenuExit
            Running = #False
        EndSelect
    EndSelect
  EndIf
Until Running = #False

PopupWindow::Close()
DetailsWindow::Close()
NotesWindow::Close()
UserLibraryWindow::Close()
SettingsWindow::Close()
Database::Close()
UserDatabase::Close()
HotKey::Unregister()
Tray::Shutdown()
CloseWindow(#WindowMain)
End ExitCode
