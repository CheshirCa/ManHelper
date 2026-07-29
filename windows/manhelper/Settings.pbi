XIncludeFile "Models.pbi"
XIncludeFile "Utils.pbi"

DeclareModule Settings
  #MOD_CONTROL = $0002
  #MOD_ALT = $0001
  #MOD_SHIFT = $0004
  #MOD_WIN = $0008
  #DEFAULT_VK = $70
  Declare.i ParseHotKey(Text.s, *Modifiers.Integer, *VirtualKey.Integer)
  Declare.s ResolveDatabasePath(ConfiguredPath.s)
  Declare Load(*Settings.Models::AppSettings)
EndDeclareModule

Module Settings
  Procedure.i IsAbsoluteWindowsPath(Path.s)
    If Left(Path, 2) = "\\" Or Left(Path, 2) = "//"
      ProcedureReturn #True
    EndIf
    If Len(Path) >= 3 And Mid(Path, 2, 1) = ":" And
       (Mid(Path, 3, 1) = "\" Or Mid(Path, 3, 1) = "/")
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.s ResolveDatabasePath(ConfiguredPath.s)
    Protected Candidate.s
    ConfiguredPath = Trim(ConfiguredPath)
    If ConfiguredPath <> ""
      If IsAbsoluteWindowsPath(ConfiguredPath)
        ProcedureReturn ConfiguredPath
      EndIf
      ; Relative configuration is always anchored to the executable. The
      ; current working directory can be changed by shortcuts or launchers.
      ProcedureReturn GetPathPart(ProgramFilename()) + ConfiguredPath
    EndIf
    Candidate = GetPathPart(ProgramFilename()) + "manbase.sqlite"
    If FileSize(Candidate) >= 0
      ProcedureReturn Candidate
    EndIf
    Candidate = GetPathPart(ProgramFilename()) +
                "..\..\..\Test_Database\manbase.sqlite"
    If FileSize(Candidate) >= 0
      ProcedureReturn Candidate
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.i ParseHotKey(Text.s, *Modifiers.Integer, *VirtualKey.Integer)
    Protected Index.i
    Protected Token.s
    Protected FunctionNumber.i
    Protected Modifiers.i
    Protected VirtualKey.i

    Text = UCase(ReplaceString(Trim(Text), " ", ""))
    For Index = 1 To CountString(Text, "+") + 1
      Token = StringField(Text, Index, "+")
      Select Token
        Case "CTRL", "CONTROL"
          Modifiers | #MOD_CONTROL
        Case "ALT"
          Modifiers | #MOD_ALT
        Case "SHIFT"
          Modifiers | #MOD_SHIFT
        Case "WIN", "WINDOWS"
          Modifiers | #MOD_WIN
        Default
          If Left(Token, 1) = "F"
            FunctionNumber = Val(Mid(Token, 2))
            If FunctionNumber >= 1 And FunctionNumber <= 12
              VirtualKey = $70 + FunctionNumber - 1
            Else
              ProcedureReturn #False
            EndIf
          Else
            ProcedureReturn #False
          EndIf
      EndSelect
    Next

    If Modifiers = 0 Or VirtualKey = 0
      ProcedureReturn #False
    EndIf
    *Modifiers\i = Modifiers
    *VirtualKey\i = VirtualKey
    ProcedureReturn #True
  EndProcedure

  Procedure Load(*Settings.Models::AppSettings)
    Protected HotKey.s = "Ctrl+F1"
    Protected ParsedModifiers.i
    Protected ParsedVirtualKey.i
    *Settings\SupportedProcesses = "putty.exe,kitty.exe"
    *Settings\ClipboardLimit = 4096
    *Settings\HotKeyModifiers = #MOD_CONTROL
    *Settings\HotKeyVirtualKey = #DEFAULT_VK
    *Settings\HotKeyDisplay = HotKey
    *Settings\InterfaceLanguage = "ru"
    *Settings\WebSearchTemplate = "https://www.google.com/search?q={query}"
    *Settings\BrowserUrlLimit = 2048

    If OpenPreferences(Utils::SettingsPath(), #PB_Preference_NoSpace, #PB_UTF8)
      PreferenceGroup("General")
      *Settings\SupportedProcesses = ReadPreferenceString("terminal_processes", *Settings\SupportedProcesses)
      *Settings\ClipboardLimit = ReadPreferenceInteger("clipboard_limit", *Settings\ClipboardLimit)
      HotKey = ReadPreferenceString("hotkey", HotKey)
      *Settings\DatabasePath = ReadPreferenceString("database_path", "")
      *Settings\InterfaceLanguage = ReadPreferenceString("interface_language",
                                                         *Settings\InterfaceLanguage)
      *Settings\WebSearchTemplate = ReadPreferenceString("web_search_template",
                                                         *Settings\WebSearchTemplate)
      *Settings\BrowserUrlLimit = ReadPreferenceInteger("browser_url_limit",
                                                        *Settings\BrowserUrlLimit)
      ClosePreferences()
    EndIf

    If ParseHotKey(HotKey, @ParsedModifiers, @ParsedVirtualKey)
      *Settings\HotKeyModifiers = ParsedModifiers
      *Settings\HotKeyVirtualKey = ParsedVirtualKey
      *Settings\HotKeyDisplay = HotKey
    EndIf

    If *Settings\ClipboardLimit < 256
      *Settings\ClipboardLimit = 256
    ElseIf *Settings\ClipboardLimit > 65536
      *Settings\ClipboardLimit = 65536
    EndIf
    If *Settings\BrowserUrlLimit < 256
      *Settings\BrowserUrlLimit = 256
    ElseIf *Settings\BrowserUrlLimit > 8192
      *Settings\BrowserUrlLimit = 8192
    EndIf
    *Settings\DatabasePath = ResolveDatabasePath(*Settings\DatabasePath)
  EndProcedure
EndModule
