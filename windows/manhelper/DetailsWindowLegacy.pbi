XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "PageRepository.pbi"
XIncludeFile "SearchExact.pbi"
XIncludeFile "SearchFts.pbi"
XIncludeFile "Browser.pbi"
XIncludeFile "UserData.pbi"
XIncludeFile "NotesWindow.pbi"

DeclareModule DetailsWindow
  Declare.i Show(*Parsed.Models::ParsedCommand, InitialPageId.q, ProfileId.i,
                 FtsAvailable.i, WebTemplate.s, BrowserUrlLimit.i)
  Declare Close()
  Declare.i IsOpen()
  Declare.i WindowNumber()
  Declare FindNext()
  Declare HandleEvent(Event.i)
EndDeclareModule

Module DetailsWindow
  #Window = 2
  #MinimumWidth = 880
  #MinimumHeight = 520
  #ShortcutClose = 201

  Enumeration 100
    #CommandLabel
    #CommandChoice
    #PageLabel
    #PageChoice
    #ViewLabel
    #ViewChoice
    #PreviousButton
    #NextButton
    #SearchLabel
    #SearchText
    #FindButton
    #StatusText
    #Content
    #CopyButton
    #NoteButton
    #BookmarkButton
    #WebButton
    #CloseButton
  EndEnumeration

  Structure ViewItem
    Label.s
    Content.s
  EndStructure

  Global Opened.i
  Global ProfileId.i
  Global FtsAvailable.i
  Global WebTemplate.s
  Global BrowserUrlLimit.i
  Global SearchOffset.i
  Global DisplayedText.s
  Global CurrentWebQuery.s
  Global OriginalSelection.s
  Global Page.Models::ManualPage
  Global Results.Models::SearchResults
  Global NewList Commands.s()
  Global NewList Views.ViewItem()
  Global CurrentRef.Models::UserPageRef

  Procedure UpdateBookmarkButton()
    If UserDatabase::IsOpen() = #False Or CurrentRef\PageKey = ""
      DisableGadget(#BookmarkButton, #True)
      DisableGadget(#NoteButton, #True)
      ProcedureReturn
    EndIf
    DisableGadget(#BookmarkButton, #False)
    DisableGadget(#NoteButton, #False)
    If UserData::IsBookmarked(@CurrentRef)
      SetGadgetText(#BookmarkButton,
                    Localization::Text("details_bookmark_remove"))
    Else
      SetGadgetText(#BookmarkButton,
                    Localization::Text("details_bookmark_add"))
    EndIf
  EndProcedure

  Procedure Resize()
    Protected Width.i = WindowWidth(#Window)
    Protected Height.i = WindowHeight(#Window)
    Protected ContentTop.i = 132
    Protected BottomTop.i = Height - 46
    ResizeGadget(#CommandChoice, 16, 30, (Width - 48) / 2, 28)
    ResizeGadget(#PageLabel, 32 + (Width - 48) / 2, 8, (Width - 48) / 2, 20)
    ResizeGadget(#PageChoice, 32 + (Width - 48) / 2, 30,
                 (Width - 48) / 2, 28)
    ResizeGadget(#ViewChoice, 16, 88, Width - 252, 28)
    ResizeGadget(#PreviousButton, Width - 220, 86, 94, 30)
    ResizeGadget(#NextButton, Width - 118, 86, 102, 30)
    ResizeGadget(#SearchLabel, 16, BottomTop - 64, 300, 20)
    ResizeGadget(#SearchText, 16, BottomTop - 38, Width - 338, 28)
    ResizeGadget(#FindButton, Width - 314, BottomTop - 38, 110, 28)
    ResizeGadget(#StatusText, Width - 196, BottomTop - 35, 180, 24)
    ResizeGadget(#Content, 16, ContentTop, Width - 32,
                 BottomTop - ContentTop - 68)
    ResizeGadget(#CopyButton, 16, BottomTop, Width - 578, 32)
    ResizeGadget(#NoteButton, Width - 546, BottomTop, 110, 32)
    ResizeGadget(#BookmarkButton, Width - 426, BottomTop, 150, 32)
    ResizeGadget(#WebButton, Width - 266, BottomTop, 150, 32)
    ResizeGadget(#CloseButton, Width - 106, BottomTop, 90, 32)
  EndProcedure

  Procedure DisplayView(Index.i)
    If SelectElement(Views(), Index)
      DisplayedText = Views()\Content
      SetGadgetText(#Content, DisplayedText)
      SetGadgetState(#ViewChoice, Index)
      SearchOffset = 1
      SetGadgetText(#StatusText, "")
    EndIf
    DisableGadget(#PreviousButton, Bool(Index <= 0))
    DisableGadget(#NextButton, Bool(Index < 0 Or Index >= ListSize(Views()) - 1))
  EndProcedure

  Procedure BuildViews()
    Protected Label.s
    ClearGadgetItems(#ViewChoice)
    ClearList(Views())
    If Trim(Page\PlainText) <> ""
      AddElement(Views())
      Views()\Label = Localization::Text("details_full_text")
      Views()\Content = Page\PlainText
    EndIf
    If Trim(Page\RoffContent) <> ""
      AddElement(Views())
      Views()\Label = Localization::Text("details_roff")
      Views()\Content = Page\RoffContent
    EndIf
    ForEach Page\Sections()
      AddElement(Views())
      Label = Page\Sections()\OriginalName
      If Label = ""
        Label = Page\Sections()\NormalizedName
      EndIf
      Views()\Label = Label
      Views()\Content = Page\Sections()\Content
    Next
    ForEach Views()
      AddGadgetItem(#ViewChoice, -1, Views()\Label)
    Next
    If ListSize(Views()) > 0
      DisplayView(0)
    Else
      DisplayedText = ""
      SetGadgetText(#Content, "")
      DisableGadget(#PreviousButton, #True)
      DisableGadget(#NextButton, #True)
    EndIf
  EndProcedure

  Procedure LoadSelectedPage()
    Protected Index.i = GetGadgetState(#PageChoice)
    Protected ViewIndex.i
    Protected PreferredSection.s
    Protected InitialSearch.s
    If SelectElement(Results\Pages(), Index) And
       PageRepository::LoadPage(Results\Pages()\Id, @Page)
      PreferredSection = Results\Pages()\PreferredSection
      InitialSearch = Results\Pages()\InitialSearch
      CurrentWebQuery = Results\Pages()\WebQuery
      UserData::MakePageRef(@Page, @CurrentRef)
      UserData::RegisterProfile(@CurrentRef)
      UserData::AddHistory(@CurrentRef, OriginalSelection)
      SetWindowTitle(#Window, Page\Name + "(" + Page\Section + ") — " +
                     Localization::Text("details_title"))
      BuildViews()
      UpdateBookmarkButton()
      If PreferredSection <> ""
        ViewIndex = 0
        ForEach Views()
          If UCase(Views()\Label) = UCase(PreferredSection)
            DisplayView(ViewIndex)
            Break
          EndIf
          ViewIndex + 1
        Next
      EndIf
      If InitialSearch <> ""
        SetGadgetText(#SearchText, InitialSearch)
        FindNext()
      EndIf
    Else
      MessageRequester(Localization::Text("app_title"),
                       Localization::Text("details_load_failed"),
                       #PB_MessageRequester_Error)
    EndIf
  EndProcedure

  Procedure SearchCommand(Command.s, PreferredPageId.q = 0)
    Protected Index.i
    Protected PreferredIndex.i
    Protected Choice.s
    ClearGadgetItems(#PageChoice)
    SearchExact::Search(Command, ProfileId, @Results)
    If ListSize(Results\Pages()) = 0 And FtsAvailable
      SearchFts::Search(Command, ProfileId, @Results)
    EndIf
    If ListSize(Results\Pages()) = 0
      ClearStructure(@Page, Models::ManualPage)
      InitializeStructure(@Page, Models::ManualPage)
      ClearList(Views())
      DisplayedText = ""
      CurrentWebQuery = ""
      ClearStructure(@CurrentRef, Models::UserPageRef)
      AddGadgetItem(#PageChoice, -1, Localization::Text("database_no_results"))
      DisableGadget(#PageChoice, #True)
      SetGadgetText(#Content, Localization::Text("database_no_results"))
      ProcedureReturn
    EndIf
    DisableGadget(#PageChoice, #False)
    Index = 0
    ForEach Results\Pages()
      Choice = Results\Pages()\Name + "(" + Results\Pages()\Section + ")"
      If Results\Pages()\Language <> ""
        Choice + " · " + Results\Pages()\Language
      EndIf
      If Results\Pages()\Locale <> ""
        Choice + " · " + Results\Pages()\Locale
      EndIf
      AddGadgetItem(#PageChoice, -1, Choice)
      If Results\Pages()\Id = PreferredPageId
        PreferredIndex = Index
      EndIf
      Index + 1
    Next
    SetGadgetState(#PageChoice, PreferredIndex)
    LoadSelectedPage()
  EndProcedure

  Procedure FindNext()
    Protected Query.s = GetGadgetText(#SearchText)
    Protected Position.i
    Protected Message.s
    If Query = "" Or DisplayedText = ""
      SetGadgetText(#StatusText, Localization::Text("details_not_found"))
      ProcedureReturn
    EndIf
    Position = FindString(DisplayedText, Query, SearchOffset, #PB_String_NoCase)
    If Position = 0 And SearchOffset > 1
      Position = FindString(DisplayedText, Query, 1, #PB_String_NoCase)
    EndIf
    If Position = 0
      SetGadgetText(#StatusText, Localization::Text("details_not_found"))
      SearchOffset = 1
      ProcedureReturn
    EndIf
    ; EditorGadget has no standard selection/caret API. These two messages are
    ; isolated here so Russian and English matches are visibly selected.
    SendMessage_(GadgetID(#Content), #EM_SETSEL, Position - 1,
                 Position - 1 + Len(Query))
    SendMessage_(GadgetID(#Content), #EM_SCROLLCARET, 0, 0)
    Message = ReplaceString(Localization::Text("details_found"),
                            "{position}", Str(Position))
    SetGadgetText(#StatusText, Message)
    SearchOffset = Position + Len(Query)
  EndProcedure

  Procedure.i Show(*Parsed.Models::ParsedCommand, InitialPageId.q, NewProfileId.i,
                   NewFtsAvailable.i, NewWebTemplate.s, NewBrowserUrlLimit.i)
    Protected InitialCommand.s
    If Opened
      SetActiveWindow(#Window)
      ProcedureReturn #True
    EndIf
    ProfileId = NewProfileId
    FtsAvailable = NewFtsAvailable
    WebTemplate = NewWebTemplate
    BrowserUrlLimit = NewBrowserUrlLimit
    OriginalSelection = *Parsed\NormalizedText
    ClearList(Commands())
    ForEach *Parsed\Commands()
      AddElement(Commands())
      Commands() = *Parsed\Commands()
    Next
    If ListSize(Commands()) = 0 And *Parsed\PrimaryCommand <> ""
      AddElement(Commands())
      Commands() = *Parsed\PrimaryCommand
    EndIf
    If ListSize(Commands()) = 0
      ProcedureReturn #False
    EndIf

    If OpenWindow(#Window, #PB_Ignore, #PB_Ignore, 940, 700,
                  Localization::Text("details_title"),
                  #PB_Window_SystemMenu | #PB_Window_SizeGadget |
                  #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget |
                  #PB_Window_ScreenCentered) = 0
      ProcedureReturn #False
    EndIf
    WindowBounds(#Window, #MinimumWidth, #MinimumHeight, #PB_Ignore, #PB_Ignore)
    TextGadget(#CommandLabel, 16, 8, 300, 20,
               Localization::Text("details_command"))
    ComboBoxGadget(#CommandChoice, 16, 30, 440, 28)
    TextGadget(#PageLabel, 472, 8, 300, 20, Localization::Text("details_page"))
    ComboBoxGadget(#PageChoice, 472, 30, 452, 28)
    TextGadget(#ViewLabel, 16, 66, 300, 20, Localization::Text("details_view"))
    ComboBoxGadget(#ViewChoice, 16, 88, 688, 28)
    ButtonGadget(#PreviousButton, 720, 86, 94, 30,
                 Localization::Text("details_previous"))
    ButtonGadget(#NextButton, 822, 86, 102, 30,
                 Localization::Text("details_next"))
    EditorGadget(#Content, 16, 132, 908, 468,
                 #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
    TextGadget(#SearchLabel, 16, 610, 300, 20,
               Localization::Text("details_search"))
    StringGadget(#SearchText, 16, 632, 586, 28, "")
    ButtonGadget(#FindButton, 610, 632, 110, 28,
                 Localization::Text("details_find_next"))
    TextGadget(#StatusText, 728, 635, 196, 24, "")
    ButtonGadget(#CopyButton, 16, 654, 362, 32,
                 Localization::Text("details_copy"))
    ButtonGadget(#NoteButton, 394, 654, 110, 32,
                 Localization::Text("details_note"))
    ButtonGadget(#BookmarkButton, 514, 654, 150, 32,
                 Localization::Text("details_bookmark_add"))
    ButtonGadget(#WebButton, 674, 654, 150, 32,
                 Localization::Text("details_web"))
    ButtonGadget(#CloseButton, 834, 654, 90, 32,
                 Localization::Text("details_close"))
    DisableGadget(#NoteButton, #True)
    DisableGadget(#BookmarkButton, #True)

    ForEach Commands()
      AddGadgetItem(#CommandChoice, -1, Commands())
    Next
    SetGadgetState(#CommandChoice, 0)
    FirstElement(Commands())
    InitialCommand = Commands()
    AddKeyboardShortcut(#Window, #PB_Shortcut_Escape, #ShortcutClose)
    Opened = #True
    Resize()
    SearchCommand(InitialCommand, InitialPageId)
    SetActiveWindow(#Window)
    ProcedureReturn #True
  EndProcedure

  Procedure Close()
    If Opened And IsWindow(#Window)
      CloseWindow(#Window)
    EndIf
    Opened = #False
    DisplayedText = ""
    CurrentWebQuery = ""
    OriginalSelection = ""
    ClearStructure(@CurrentRef, Models::UserPageRef)
    ClearList(Commands())
    ClearList(Views())
    ClearList(Results\Pages())
    ClearStructure(@Page, Models::ManualPage)
    InitializeStructure(@Page, Models::ManualPage)
  EndProcedure

  Procedure.i IsOpen()
    ProcedureReturn Opened
  EndProcedure

  Procedure.i WindowNumber()
    ProcedureReturn #Window
  EndProcedure

  Procedure HandleEvent(Event.i)
    Protected Index.i
    Protected Error.String
    Protected Query.s
    Protected BookmarkState.i
    If Opened = #False Or EventWindow() <> #Window
      ProcedureReturn
    EndIf
    Select Event
      Case #PB_Event_CloseWindow
        Close()
      Case #PB_Event_SizeWindow
        Resize()
      Case #PB_Event_Menu
        If EventMenu() = #ShortcutClose
          Close()
        EndIf
      Case #PB_Event_Gadget
        Select EventGadget()
          Case #CommandChoice
            Index = GetGadgetState(#CommandChoice)
            If SelectElement(Commands(), Index)
              SearchCommand(Commands())
            EndIf
          Case #PageChoice
            LoadSelectedPage()
          Case #ViewChoice
            DisplayView(GetGadgetState(#ViewChoice))
          Case #PreviousButton
            DisplayView(GetGadgetState(#ViewChoice) - 1)
          Case #NextButton
            DisplayView(GetGadgetState(#ViewChoice) + 1)
          Case #FindButton
            FindNext()
          Case #CopyButton
            If DisplayedText <> ""
              SetClipboardText(DisplayedText)
            EndIf
          Case #NoteButton
            NotesWindow::Show(@CurrentRef)
          Case #BookmarkButton
            BookmarkState = Bool(UserData::IsBookmarked(@CurrentRef) = #False)
            UserData::SetBookmarked(@CurrentRef, BookmarkState)
            UpdateBookmarkButton()
          Case #WebButton
            Query = Browser::ResolveQuery(OriginalSelection, CurrentWebQuery,
                                          Page\Name, Page\Section)
            If Page\Name <> "" And
               Browser::Search(Query, WebTemplate, BrowserUrlLimit,
                               @Error) = #False
              MessageRequester(Localization::Text("app_title"), Error\s,
                               #PB_MessageRequester_Error)
            EndIf
          Case #CloseButton
            Close()
        EndSelect
    EndSelect
  EndProcedure
EndModule
