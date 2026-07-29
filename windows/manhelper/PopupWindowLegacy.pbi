XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "Utils.pbi"
XIncludeFile "PopupPosition.pbi"
XIncludeFile "DetailsWindow.pbi"
XIncludeFile "Browser.pbi"

DeclareModule PopupWindow
  Declare.i Show(*Selection.Models::Selection, *Parsed.Models::ParsedCommand,
                 *Results.Models::SearchResults, TerminalName.s, AnchorWindow.i,
                 ProfileId.i, FtsAvailable.i, WebTemplate.s,
                 BrowserUrlLimit.i)
  Declare Close()
  Declare.i IsOpen()
  Declare.i WindowNumber()
  Declare.i ShouldCloseForForeground(HadFocus.i, PopupHandle.i,
                                     ForegroundHandle.i, Age.i)
  Declare HandleEvent(Event.i)
EndDeclareModule

Module PopupWindow
  #Window = 1
  #Width = 620
  #Height = 550
  #TimerFocus = 1
  #ShortcutClose = 100

  Enumeration Gadgets
    #TerminalLabel
    #CommandLabel
    #ResultChoice
    #SummaryLabel
    #SummaryText
    #SynopsisLabel
    #SynopsisText
    #OriginalLabel
    #OriginalText
    #WarningText
    #DetailsButton
    #CopyButton
    #WebButton
  EndEnumeration

  Global Opened.i
  Global OpenedAt.i
  Global HadForeground.i
  Global Normalized.s
  Global ProfileId.i
  Global FtsAvailable.i
  Global WebTemplate.s
  Global BrowserUrlLimit.i
  Global ParsedCopy.Models::ParsedCommand
  Global NewList Pages.Models::PageResult()

  Procedure DisplayPage(Index.i)
    If SelectElement(Pages(), Index)
      SetGadgetText(#CommandLabel, Localization::Text("popup_command") +
                    Pages()\Name + "(" + Pages()\Section + ")")
      SetGadgetText(#SummaryText, Pages()\Summary)
      SetGadgetText(#SynopsisText, Pages()\Synopsis)
    EndIf
  EndProcedure

  Procedure.i WindowNumber()
    ProcedureReturn #Window
  EndProcedure

  Procedure.i IsOpen()
    ProcedureReturn Opened
  EndProcedure

  Procedure.i ShouldCloseForForeground(HadFocus.i, PopupHandle.i,
                                       ForegroundHandle.i, Age.i)
    ProcedureReturn Bool(HadFocus And Age > 600 And
                         ForegroundHandle <> PopupHandle)
  EndProcedure

  Procedure Close()
    If Opened And IsWindow(#Window)
      RemoveWindowTimer(#Window, #TimerFocus)
      CloseWindow(#Window)
    EndIf
    Opened = #False
    HadForeground = #False
    Normalized = ""
    ClearList(Pages())
    ClearStructure(@ParsedCopy, Models::ParsedCommand)
    InitializeStructure(@ParsedCopy, Models::ParsedCommand)
  EndProcedure

  Procedure.i Show(*Selection.Models::Selection, *Parsed.Models::ParsedCommand,
                   *Results.Models::SearchResults, TerminalName.s, AnchorWindow.i,
                   NewProfileId.i, NewFtsAvailable.i, NewWebTemplate.s,
                   NewBrowserUrlLimit.i)
    Protected Position.PopupPosition::Position
    Protected Warnings.s = Utils::JoinWarnings(*Selection\Warnings())
    Protected ChoiceText.s
    If Opened
      Close()
    EndIf

    PopupPosition::Calculate(@Position, AnchorWindow, #Width, #Height)
    If OpenWindow(#Window, Position\X, Position\Y, #Width, #Height,
                  Localization::Text("app_title"),
                  #PB_Window_Tool | #PB_Window_SystemMenu) = 0
      ProcedureReturn #False
    EndIf
    StickyWindow(#Window, #True)
    TextGadget(#TerminalLabel, 16, 14, 548, 22,
               Localization::Text("popup_terminal") + TerminalName)
    ClearList(Pages())
    ClearStructure(@ParsedCopy, Models::ParsedCommand)
    InitializeStructure(@ParsedCopy, Models::ParsedCommand)
    CopyStructure(*Parsed, @ParsedCopy, Models::ParsedCommand)
    ProfileId = NewProfileId
    FtsAvailable = NewFtsAvailable
    WebTemplate = NewWebTemplate
    BrowserUrlLimit = NewBrowserUrlLimit
    ForEach *Results\Pages()
      AddElement(Pages())
      CopyStructure(@*Results\Pages(), @Pages(), Models::PageResult)
    Next
    TextGadget(#CommandLabel, 16, 40, 588, 24,
               Localization::Text("popup_command") + *Parsed\PrimaryCommand)
    ComboBoxGadget(#ResultChoice, 16, 66, 588, 28)
    TextGadget(#SummaryLabel, 16, 102, 588, 20, Localization::Text("popup_summary"))
    EditorGadget(#SummaryText, 16, 124, 588, 64, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
    TextGadget(#SynopsisLabel, 16, 196, 588, 20, Localization::Text("popup_synopsis"))
    EditorGadget(#SynopsisText, 16, 218, 588, 108, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
    TextGadget(#OriginalLabel, 16, 334, 588, 20, Localization::Text("popup_selection"))
    EditorGadget(#OriginalText, 16, 356, 588, 66, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
    TextGadget(#WarningText, 16, 430, 588, 42, Warnings)
    ButtonGadget(#DetailsButton, 16, 498, 130, 34, Localization::Text("popup_details"))
    ButtonGadget(#CopyButton, 156, 498, 130, 34, Localization::Text("popup_copy"))
    ButtonGadget(#WebButton, 296, 498, 180, 34, Localization::Text("popup_web"))

    SetGadgetText(#OriginalText, *Selection\OriginalText)
    If ListSize(Pages()) > 0
      ForEach Pages()
        ChoiceText = Pages()\Name + "(" + Pages()\Section + ")"
        If Pages()\Language <> ""
          ChoiceText + " · " + Pages()\Language
        EndIf
        If Pages()\Locale <> ""
          ChoiceText + " · " + Pages()\Locale
        EndIf
        AddGadgetItem(#ResultChoice, -1, ChoiceText)
      Next
      SetGadgetState(#ResultChoice, 0)
      DisplayPage(0)
    Else
      AddGadgetItem(#ResultChoice, -1, Localization::Text("database_no_results"))
      SetGadgetState(#ResultChoice, 0)
      DisableGadget(#ResultChoice, #True)
      SetGadgetText(#SummaryText, Localization::Text("database_no_results"))
    EndIf
    DisableGadget(#DetailsButton, Bool(ListSize(Pages()) = 0))
    DisableGadget(#WebButton, Bool(*Parsed\PrimaryCommand = ""))
    If *Selection\NormalizedText = ""
      SetGadgetText(#WarningText, Localization::Text("popup_empty"))
      DisableGadget(#CopyButton, #True)
    EndIf
    Normalized = *Selection\NormalizedText
    AddKeyboardShortcut(#Window, #PB_Shortcut_Escape, #ShortcutClose)
    AddWindowTimer(#Window, #TimerFocus, 250)
    OpenedAt = ElapsedMilliseconds()
    HadForeground = #False
    Opened = #True
    SetActiveWindow(#Window)
    ProcedureReturn #True
  EndProcedure

  Procedure HandleEvent(Event.i)
    Protected PageId.q
    Protected Query.s
    Protected Error.String
    If Opened = #False Or EventWindow() <> #Window
      ProcedureReturn
    EndIf
    Select Event
      Case #PB_Event_CloseWindow
        Close()
      Case #PB_Event_Menu
        If EventMenu() = #ShortcutClose
          Close()
        EndIf
      Case #PB_Event_Gadget
        Select EventGadget()
          Case #ResultChoice
            DisplayPage(GetGadgetState(#ResultChoice))
          Case #CopyButton
            If Normalized <> ""
              ; Clipboard changes only after this explicit user action.
              SetClipboardText(Normalized)
            EndIf
          Case #DetailsButton
            If SelectElement(Pages(), GetGadgetState(#ResultChoice))
              PageId = Pages()\Id
              If DetailsWindow::Show(@ParsedCopy, PageId, ProfileId, FtsAvailable,
                                     WebTemplate, BrowserUrlLimit)
                Close()
              EndIf
            EndIf
          Case #WebButton
            Query = Browser::ResolveQuery(ParsedCopy\NormalizedText,
                                          ParsedCopy\PrimaryCommand, "", "")
            If SelectElement(Pages(), GetGadgetState(#ResultChoice))
              If Query = ""
                Query = Browser::ResolveQuery("", Pages()\WebQuery,
                                              Pages()\Name, Pages()\Section)
              EndIf
            EndIf
            If Query <> "" And
               Browser::Search(Query, WebTemplate, BrowserUrlLimit, @Error) = #False
              MessageRequester(Localization::Text("app_title"), Error\s,
                               #PB_MessageRequester_Error)
            EndIf
        EndSelect
      Case #PB_Event_Timer
        ; GetActiveWindow() sees only windows owned by this process. The
        ; foreground WinAPI check is needed to close after a click in another
        ; application.
        If EventTimer() = #TimerFocus
          If GetForegroundWindow_() = WindowID(#Window)
            HadForeground = #True
          ElseIf ShouldCloseForForeground(HadForeground, WindowID(#Window),
                                          GetForegroundWindow_(),
                                          ElapsedMilliseconds() - OpenedAt)
            Close()
          EndIf
        EndIf
    EndSelect
  EndProcedure
EndModule
