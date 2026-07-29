XIncludeFile "Localization.pbi"
XIncludeFile "UserData.pbi"

DeclareModule SettingsWindow
  Declare.i Show()
  Declare Close()
  Declare.i IsOpen()
  Declare.i WindowNumber()
  Declare HandleEvent(Event.i)
EndDeclareModule

Module SettingsWindow
  #Window = 5
  Enumeration 400
    #LanguageLabel
    #LanguageText
    #TemplateLabel
    #TemplateText
    #LimitLabel
    #LimitText
    #Status
    #SaveButton
    #CloseButton
  EndEnumeration
  Global Opened.i

  Procedure LoadValue(Key.s, Gadget.i, DefaultValue.s)
    Protected Value.String
    If UserData::LoadSetting(Key, @Value)
      SetGadgetText(Gadget, Value\s)
    Else
      SetGadgetText(Gadget, DefaultValue)
    EndIf
  EndProcedure

  Procedure.i Show()
    If UserDatabase::IsOpen() = #False
      ProcedureReturn #False
    EndIf
    If Opened
      SetActiveWindow(#Window)
      ProcedureReturn #True
    EndIf
    If OpenWindow(#Window, #PB_Ignore, #PB_Ignore, 680, 310,
                  Localization::Text("settings_title"),
                  #PB_Window_SystemMenu | #PB_Window_ScreenCentered) = 0
      ProcedureReturn #False
    EndIf
    TextGadget(#LanguageLabel, 16, 16, 648, 20,
               Localization::Text("settings_language"))
    StringGadget(#LanguageText, 16, 38, 648, 28, "")
    TextGadget(#TemplateLabel, 16, 78, 648, 20,
               Localization::Text("settings_web_template"))
    StringGadget(#TemplateText, 16, 100, 648, 28, "")
    TextGadget(#LimitLabel, 16, 140, 648, 20,
               Localization::Text("settings_url_limit"))
    StringGadget(#LimitText, 16, 162, 648, 28, "", #PB_String_Numeric)
    TextGadget(#Status, 16, 206, 648, 24, "")
    ButtonGadget(#SaveButton, 444, 246, 100, 32,
                 Localization::Text("settings_save"))
    ButtonGadget(#CloseButton, 554, 246, 110, 32,
                 Localization::Text("details_close"))
    LoadValue("interface_language", #LanguageText, "ru")
    LoadValue("web_search_template", #TemplateText,
              "https://www.google.com/search?q={query}")
    LoadValue("browser_url_limit", #LimitText, "2048")
    Opened = #True
    SetActiveWindow(#Window)
    ProcedureReturn #True
  EndProcedure

  Procedure Close()
    If Opened And IsWindow(#Window)
      CloseWindow(#Window)
    EndIf
    Opened = #False
  EndProcedure

  Procedure.i IsOpen()
    ProcedureReturn Opened
  EndProcedure

  Procedure.i WindowNumber()
    ProcedureReturn #Window
  EndProcedure

  Procedure HandleEvent(Event.i)
    Protected Limit.i
    If Opened = #False Or EventWindow() <> #Window
      ProcedureReturn
    EndIf
    Select Event
      Case #PB_Event_CloseWindow
        Close()
      Case #PB_Event_Gadget
        Select EventGadget()
          Case #SaveButton
            Limit = Val(GetGadgetText(#LimitText))
            If Limit < 256
              Limit = 256
            ElseIf Limit > 8192
              Limit = 8192
            EndIf
            UserData::SaveSetting("interface_language",
                                  LCase(Left(GetGadgetText(#LanguageText), 2)))
            UserData::SaveSetting("web_search_template",
                                  GetGadgetText(#TemplateText))
            UserData::SaveSetting("browser_url_limit", Str(Limit))
            SetGadgetText(#LimitText, Str(Limit))
            SetGadgetText(#Status, Localization::Text("settings_restart"))
          Case #CloseButton
            Close()
        EndSelect
    EndSelect
  EndProcedure
EndModule
