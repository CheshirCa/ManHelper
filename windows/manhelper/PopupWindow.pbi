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
  #Width = 440
  #Height = 304
  #TimerFocus = 1
  #ShortcutClose = 100
  #IconCopy = $E8C8
  #IconWeb = $E774

  Enumeration Gadgets
    #Card
    #Breadcrumb
    #CommandName
    #SectionText
    #ResultChoice
    #SummaryText
    #SyntaxCard
    #SynopsisText
    #SelectionLabel
    #SelectionBadge
    #WarningText
    #DetailsButton
    #CopyButton
    #WebButton
  EndEnumeration

  Global Opened.i
  Global OpenedAt.i
  Global HadForeground.i
  Global Normalized.s
  Global Terminal.s
  Global ProfileId.i
  Global FtsAvailable.i
  Global WebTemplate.s
  Global BrowserUrlLimit.i
  Global FontRegular.i
  Global FontMuted.i
  Global FontCommand.i
  Global FontMono.i
  Global FontIcons.i
  Global ParsedCopy.Models::ParsedCommand
  Global NewList Pages.Models::PageResult()

  Procedure EnsureFonts()
    If FontRegular = 0
      FontRegular = LoadFont(#PB_Any, "Segoe UI", 10)
      FontMuted = LoadFont(#PB_Any, "Segoe UI", 8)
      FontCommand = LoadFont(#PB_Any, "Segoe UI", 12, #PB_Font_Bold)
      FontMono = LoadFont(#PB_Any, "Consolas", 10)
      FontIcons = LoadFont(#PB_Any, "Segoe MDL2 Assets", 10)
    EndIf
  EndProcedure

  Procedure SetFontIfAvailable(Gadget.i, Font.i)
    If Font
      SetGadgetFont(Gadget, FontID(Font))
    EndIf
  EndProcedure

  Procedure DisplayPage(Index.i)
    Protected PageLabel.s
    Protected BreadcrumbText.s
    If SelectElement(Pages(), Index)
      PageLabel = Pages()\Name + "(" + Pages()\Section + ")"
      BreadcrumbText = Terminal + "  ›  " + PageLabel
      If Pages()\Language <> ""
        BreadcrumbText + " · " + Pages()\Language
      EndIf
      If Pages()\Locale <> ""
        BreadcrumbText + " · " + Pages()\Locale
      EndIf
      SetGadgetText(#Breadcrumb, BreadcrumbText)
      SetGadgetText(#CommandName, Pages()\Name)
      SetGadgetText(#SectionText, Pages()\Section)
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
    Terminal = ""
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
    Protected PageCount.i
    If Opened
      Close()
    EndIf

    EnsureFonts()
    PopupPosition::Calculate(@Position, AnchorWindow, #Width, #Height)
    If OpenWindow(#Window, Position\X, Position\Y, #Width, #Height, "",
                  #PB_Window_BorderLess | #PB_Window_Tool) = 0
      ProcedureReturn #False
    EndIf
    StickyWindow(#Window, #True)

    ContainerGadget(#Card, 0, 0, #Width, #Height, #PB_Container_Flat)
    SetGadgetColor(#Card, #PB_Gadget_BackColor, RGB(250, 250, 250))
    TextGadget(#Breadcrumb, 16, 13, 408, 18, TerminalName)
    TextGadget(#CommandName, 16, 37, 330, 23, *Parsed\PrimaryCommand)
    TextGadget(#SectionText, 384, 40, 40, 18, "", #PB_Text_Right)
    ComboBoxGadget(#ResultChoice, 16, 64, 408, 26)
    TextGadget(#SummaryText, 16, 98, 408, 36, "")
    ContainerGadget(#SyntaxCard, 16, 140, 408, 44, #PB_Container_Flat)
    SetGadgetColor(#SyntaxCard, #PB_Gadget_BackColor, RGB(242, 244, 247))
    TextGadget(#SynopsisText, 10, 7, 388, 30, "")
    CloseGadgetList()
    TextGadget(#SelectionLabel, 16, 194, 110, 20,
               LCase(Localization::Text("popup_selection")) + ":")
    TextGadget(#SelectionBadge, 118, 191, 306, 24,
               *Selection\OriginalText, #PB_Text_Border)
    TextGadget(#WarningText, 16, 220, 408, 28, Warnings)
    ButtonGadget(#DetailsButton, 16, 256, 324, 34,
                 Localization::Text("popup_details"))
    ButtonGadget(#CopyButton, 346, 256, 36, 34, Chr(#IconCopy))
    ButtonGadget(#WebButton, 388, 256, 36, 34, Chr(#IconWeb))
    CloseGadgetList()

    SetFontIfAvailable(#Breadcrumb, FontMuted)
    SetFontIfAvailable(#CommandName, FontCommand)
    SetFontIfAvailable(#SectionText, FontMuted)
    SetFontIfAvailable(#ResultChoice, FontRegular)
    SetFontIfAvailable(#SummaryText, FontRegular)
    SetFontIfAvailable(#SynopsisText, FontMono)
    SetFontIfAvailable(#SelectionLabel, FontMuted)
    SetFontIfAvailable(#SelectionBadge, FontMono)
    SetFontIfAvailable(#WarningText, FontMuted)
    SetFontIfAvailable(#DetailsButton, FontRegular)
    SetFontIfAvailable(#CopyButton, FontIcons)
    SetFontIfAvailable(#WebButton, FontIcons)
    SetGadgetColor(#Breadcrumb, #PB_Gadget_FrontColor, RGB(112, 117, 124))
    SetGadgetColor(#SectionText, #PB_Gadget_FrontColor, RGB(112, 117, 124))
    SetGadgetColor(#SummaryText, #PB_Gadget_FrontColor, RGB(70, 74, 80))
    SetGadgetColor(#SelectionLabel, #PB_Gadget_FrontColor, RGB(112, 117, 124))
    SetGadgetColor(#SelectionBadge, #PB_Gadget_BackColor, RGB(226, 238, 252))
    SetGadgetColor(#SelectionBadge, #PB_Gadget_FrontColor, RGB(36, 90, 145))
    SetGadgetColor(#WarningText, #PB_Gadget_FrontColor, RGB(166, 86, 25))
    GadgetToolTip(#CopyButton, Localization::Text("popup_copy"))
    GadgetToolTip(#WebButton, Localization::Text("popup_web"))
    GadgetToolTip(#SelectionBadge, *Selection\OriginalText)

    ClearList(Pages())
    ClearStructure(@ParsedCopy, Models::ParsedCommand)
    InitializeStructure(@ParsedCopy, Models::ParsedCommand)
    CopyStructure(*Parsed, @ParsedCopy, Models::ParsedCommand)
    Terminal = TerminalName
    ProfileId = NewProfileId
    FtsAvailable = NewFtsAvailable
    WebTemplate = NewWebTemplate
    BrowserUrlLimit = NewBrowserUrlLimit
    ForEach *Results\Pages()
      AddElement(Pages())
      CopyStructure(@*Results\Pages(), @Pages(), Models::PageResult)
    Next

    PageCount = ListSize(Pages())
    If PageCount > 0
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
      SetGadgetText(#Breadcrumb, TerminalName)
      SetGadgetText(#SummaryText, Localization::Text("database_no_results"))
    EndIf

    DisableGadget(#DetailsButton, Bool(PageCount = 0))
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
        ; PureBasic only reports active windows owned by this process.
        ; The foreground WinAPI check is required for clicks in other apps.
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
