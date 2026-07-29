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
  Declare.i RenderedBlockCount()
  Declare.i WheelRoutingCount()
  Declare.i WheelPosition(Current.i, Delta.i, Maximum.i)
  Declare FindNext()
  Declare HandleEvent(Event.i)
EndDeclareModule

Module DetailsWindow
  #Window = 2
  #MinimumWidth = 720
  #MinimumHeight = 480
  #ShortcutClose = 201
  #ShortcutFind = 202
  #IconPrevious = $E76B
  #IconNext = $E76C
  #IconNote = $E70F
  #IconBookmark = $E8A4
  #IconWeb = $E774
  #WindowProcedureIndex = -4
  #WheelPixels = 54

  Enumeration 100
    #Toolbar
    #CommandChoice
    #PageChoice
    #ViewChoice
    #SearchBar
    #SearchText
    #PreviousButton
    #NextButton
    #StatusText
    #ContentArea
    #BottomBar
    #CopyButton
    #NoteButton
    #BookmarkButton
    #WebButton
  EndEnumeration

  Structure ViewItem
    Label.s
    Content.s
  EndStructure

  Structure RenderBlock
    Label.s
    Content.s
    LabelGadget.i
    ContentGadget.i
    ContentHandle.i
    StartOffset.i
    Y.i
    Height.i
  EndStructure

  Global Opened.i
  Global ProfileId.i
  Global FtsAvailable.i
  Global WebTemplate.s
  Global BrowserUrlLimit.i
  Global LastMatch.i
  Global DisplayedText.s
  Global CurrentWebQuery.s
  Global OriginalSelection.s
  Global FontRegular.i
  Global FontMuted.i
  Global FontMono.i
  Global FontIcons.i
  Global Page.Models::ManualPage
  Global Results.Models::SearchResults
  Global NewList Commands.s()
  Global NewList Views.ViewItem()
  Global NewList Blocks.RenderBlock()
  Global NewMap EditorProcedures.i()
  Global CurrentRef.Models::UserPageRef

  Procedure EnsureFonts()
    If FontRegular = 0
      FontRegular = LoadFont(#PB_Any, "Segoe UI", 10)
      FontMuted = LoadFont(#PB_Any, "Segoe UI", 8, #PB_Font_Bold)
      FontMono = LoadFont(#PB_Any, "Consolas", 10)
      FontIcons = LoadFont(#PB_Any, "Segoe MDL2 Assets", 10)
    EndIf
  EndProcedure

  Procedure SetFontIfAvailable(Gadget.i, Font.i)
    If Font
      SetGadgetFont(Gadget, FontID(Font))
    EndIf
  EndProcedure

  Procedure.i WheelPosition(Current.i, Delta.i, Maximum.i)
    Protected Result.i = Current - (Delta * #WheelPixels / 120)
    If Result < 0
      Result = 0
    ElseIf Result > Maximum
      Result = Maximum
    EndIf
    ProcedureReturn Result
  EndProcedure

  Procedure.i EditorWheelCallback(Handle.i, Message.i, WParam.i, LParam.i)
    Protected Delta.w
    Protected Maximum.i
    Protected Current.i
    Protected OldProcedure.i
    If Message = #WM_MOUSEWHEEL And IsGadget(#ContentArea)
      Delta = (WParam >> 16) & $FFFF
      Maximum = GetGadgetAttribute(#ContentArea,
                                   #PB_ScrollArea_InnerHeight)
      Maximum - GadgetHeight(#ContentArea)
      If Maximum < 0
        Maximum = 0
      EndIf
      Current = GetGadgetAttribute(#ContentArea, #PB_ScrollArea_Y)
      SetGadgetAttribute(#ContentArea, #PB_ScrollArea_Y,
                         WheelPosition(Current, Delta, Maximum))
      ProcedureReturn 0
    EndIf
    If FindMapElement(EditorProcedures(), Str(Handle))
      OldProcedure = EditorProcedures()
    EndIf
    If OldProcedure
      ProcedureReturn CallWindowProc_(OldProcedure, Handle, Message,
                                      WParam, LParam)
    EndIf
    ProcedureReturn DefWindowProc_(Handle, Message, WParam, LParam)
  EndProcedure

  Procedure RegisterEditorWheel(Gadget.i)
    Protected Handle.i = GadgetID(Gadget)
    Protected OldProcedure.i
    If Handle = 0
      ProcedureReturn
    EndIf
    OldProcedure = SetWindowLongPtr_(Handle, #WindowProcedureIndex,
                                     @EditorWheelCallback())
    If OldProcedure
      EditorProcedures(Str(Handle)) = OldProcedure
    EndIf
  EndProcedure

  Procedure UnregisterEditorWheel(Handle.i)
    If Handle And FindMapElement(EditorProcedures(), Str(Handle))
      SetWindowLongPtr_(Handle, #WindowProcedureIndex, EditorProcedures())
      DeleteMapElement(EditorProcedures())
    EndIf
  EndProcedure

  Procedure ClearBlocks()
    ForEach Blocks()
      If IsGadget(Blocks()\LabelGadget)
        FreeGadget(Blocks()\LabelGadget)
      EndIf
      If IsGadget(Blocks()\ContentGadget)
        UnregisterEditorWheel(Blocks()\ContentHandle)
        FreeGadget(Blocks()\ContentGadget)
      EndIf
    Next
    ClearList(Blocks())
    DisplayedText = ""
    LastMatch = 0
  EndProcedure

  Procedure.i EstimateHeight(Text.s, Width.i)
    Protected LineCount.i = CountString(Text, #LF$) + 1
    Protected CharactersPerLine.i = (Width - 36) / 8
    Protected Index.i
    Protected Line.s
    Protected WrappedLines.i
    If CharactersPerLine < 24
      CharactersPerLine = 24
    EndIf
    For Index = 1 To LineCount
      Line = StringField(Text, Index, #LF$)
      WrappedLines + 1 + Len(Line) / CharactersPerLine
    Next
    If WrappedLines < 2
      WrappedLines = 2
    EndIf
    ProcedureReturn WrappedLines * 18 + 12
  EndProcedure

  Procedure AddBlock(Label.s, Content.s, *Y.Integer, InnerWidth.i)
    Protected ContentHeight.i = EstimateHeight(Content, InnerWidth)
    AddElement(Blocks())
    Blocks()\Label = Label
    Blocks()\Content = Content
    Blocks()\StartOffset = Len(DisplayedText) + 1
    Blocks()\Y = *Y\i
    Blocks()\Height = ContentHeight
    Blocks()\LabelGadget = TextGadget(#PB_Any, 18, *Y\i, InnerWidth - 36,
                                      18, UCase(Label))
    SetFontIfAvailable(Blocks()\LabelGadget, FontMuted)
    SetGadgetColor(Blocks()\LabelGadget, #PB_Gadget_FrontColor,
                   RGB(126, 130, 136))
    *Y\i + 22
    Blocks()\ContentGadget = EditorGadget(#PB_Any, 18, *Y\i, InnerWidth - 36,
                                          ContentHeight,
                                          #PB_Editor_ReadOnly |
                                          #PB_Editor_WordWrap)
    Blocks()\ContentHandle = GadgetID(Blocks()\ContentGadget)
    RegisterEditorWheel(Blocks()\ContentGadget)
    SetFontIfAvailable(Blocks()\ContentGadget, FontMono)
    SetGadgetColor(Blocks()\ContentGadget, #PB_Gadget_BackColor,
                   RGB(250, 250, 250))
    SetGadgetText(Blocks()\ContentGadget, Content)
    *Y\i + ContentHeight + 14
    DisplayedText + Content + #LF$
  EndProcedure

  Procedure RenderView(Index.i)
    Protected Y.i = 16
    Protected InnerWidth.i = GadgetWidth(#ContentArea) - 20
    Protected Label.s
    If InnerWidth < 560
      InnerWidth = 560
    EndIf
    ClearBlocks()
    OpenGadgetList(#ContentArea)
    If Index = 0 And ListSize(Page\Sections()) > 0
      ForEach Page\Sections()
        Label = Page\Sections()\OriginalName
        If Label = ""
          Label = Page\Sections()\NormalizedName
        EndIf
        AddBlock(Label, Page\Sections()\Content, @Y, InnerWidth)
      Next
    ElseIf SelectElement(Views(), Index)
      AddBlock(Views()\Label, Views()\Content, @Y, InnerWidth)
    EndIf
    CloseGadgetList()
    If Y < GadgetHeight(#ContentArea)
      Y = GadgetHeight(#ContentArea)
    EndIf
    SetGadgetAttribute(#ContentArea, #PB_ScrollArea_InnerWidth, InnerWidth)
    SetGadgetAttribute(#ContentArea, #PB_ScrollArea_InnerHeight, Y + 8)
    SetGadgetAttribute(#ContentArea, #PB_ScrollArea_Y, 0)
    SetGadgetText(#StatusText, "")
  EndProcedure

  Procedure UpdateBookmarkButton()
    If UserDatabase::IsOpen() = #False Or CurrentRef\PageKey = ""
      DisableGadget(#BookmarkButton, #True)
      DisableGadget(#NoteButton, #True)
      ProcedureReturn
    EndIf
    DisableGadget(#BookmarkButton, #False)
    DisableGadget(#NoteButton, #False)
    SetGadgetText(#BookmarkButton, Chr(#IconBookmark))
    If UserData::IsBookmarked(@CurrentRef)
      GadgetToolTip(#BookmarkButton,
                    Localization::Text("details_bookmark_remove"))
    Else
      GadgetToolTip(#BookmarkButton,
                    Localization::Text("details_bookmark_add"))
    EndIf
  EndProcedure

  Procedure Resize()
    Protected Width.i = WindowWidth(#Window)
    Protected Height.i = WindowHeight(#Window)
    Protected PageWidth.i = Width - 388
    Protected SearchWidth.i = Width - 116
    Protected ContentTop.i = 102
    Protected BottomTop.i = Height - 52
    Protected MainButtonWidth.i = Width - 170
    Protected InnerWidth.i
    If PageWidth < 250
      PageWidth = 250
    EndIf
    ResizeGadget(#Toolbar, 0, 0, Width, 46)
    ResizeGadget(#CommandChoice, 16, 10, 150, 28)
    ResizeGadget(#PageChoice, 174, 10, PageWidth, 28)
    ResizeGadget(#ViewChoice, Width - 206, 10, 190, 28)
    ResizeGadget(#SearchBar, 0, 46, Width, 56)
    ResizeGadget(#SearchText, 16, 8, SearchWidth, 28)
    ResizeGadget(#PreviousButton, Width - 92, 8, 36, 28)
    ResizeGadget(#NextButton, Width - 50, 8, 36, 28)
    ResizeGadget(#StatusText, 16, 38, Width - 32, 16)
    ResizeGadget(#ContentArea, 0, ContentTop, Width,
                 BottomTop - ContentTop)
    InnerWidth = GadgetWidth(#ContentArea) - 20
    If InnerWidth < 560
      InnerWidth = 560
    EndIf
    ForEach Blocks()
      ResizeGadget(Blocks()\LabelGadget, 18, #PB_Ignore,
                   InnerWidth - 36, #PB_Ignore)
      ResizeGadget(Blocks()\ContentGadget, 18, #PB_Ignore,
                   InnerWidth - 36, #PB_Ignore)
    Next
    SetGadgetAttribute(#ContentArea, #PB_ScrollArea_InnerWidth, InnerWidth)
    ResizeGadget(#BottomBar, 0, BottomTop, Width, 52)
    ResizeGadget(#CopyButton, 16, 9, MainButtonWidth, 34)
    ResizeGadget(#NoteButton, Width - 148, 9, 36, 34)
    ResizeGadget(#BookmarkButton, Width - 106, 9, 36, 34)
    ResizeGadget(#WebButton, Width - 64, 9, 36, 34)
  EndProcedure

  Procedure DisplayView(Index.i)
    If SelectElement(Views(), Index)
      SetGadgetState(#ViewChoice, Index)
      RenderView(Index)
    EndIf
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
      ClearBlocks()
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
      CurrentWebQuery = ""
      ClearStructure(@CurrentRef, Models::UserPageRef)
      AddGadgetItem(#PageChoice, -1, Localization::Text("database_no_results"))
      DisableGadget(#PageChoice, #True)
      ClearBlocks()
      OpenGadgetList(#ContentArea)
      Protected EmptyY.i = 16
      AddBlock("", Localization::Text("database_no_results"), @EmptyY,
               GadgetWidth(#ContentArea) - 20)
      CloseGadgetList()
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

  Procedure ShowMatch(Position.i, Query.s)
    Protected LocalPosition.i
    Protected Message.s
    ForEach Blocks()
      If Position >= Blocks()\StartOffset And
         Position <= Blocks()\StartOffset + Len(Blocks()\Content)
        LocalPosition = Position - Blocks()\StartOffset
        ; EditorGadget has no PureBasic selection/caret command. The isolated
        ; messages make Unicode matches visible without changing the text.
        SendMessage_(GadgetID(Blocks()\ContentGadget), #EM_SETSEL,
                     LocalPosition, LocalPosition + Len(Query))
        SendMessage_(GadgetID(Blocks()\ContentGadget), #EM_SCROLLCARET, 0, 0)
        SetGadgetAttribute(#ContentArea, #PB_ScrollArea_Y, Blocks()\Y)
        Break
      EndIf
    Next
    LastMatch = Position
    Message = ReplaceString(Localization::Text("details_found"),
                            "{position}", Str(Position))
    SetGadgetText(#StatusText, Message)
  EndProcedure

  Procedure FindNext()
    Protected Query.s = GetGadgetText(#SearchText)
    Protected Start.i = LastMatch + 1
    Protected Position.i
    If Query = "" Or DisplayedText = ""
      SetGadgetText(#StatusText, Localization::Text("details_not_found"))
      ProcedureReturn
    EndIf
    If Start < 1
      Start = 1
    EndIf
    Position = FindString(DisplayedText, Query, Start, #PB_String_NoCase)
    If Position = 0 And Start > 1
      Position = FindString(DisplayedText, Query, 1, #PB_String_NoCase)
    EndIf
    If Position = 0
      SetGadgetText(#StatusText, Localization::Text("details_not_found"))
      LastMatch = 0
      ProcedureReturn
    EndIf
    ShowMatch(Position, Query)
  EndProcedure

  Procedure FindPrevious()
    Protected Query.s = GetGadgetText(#SearchText)
    Protected Limit.i = LastMatch - 1
    Protected Position.i
    Protected Candidate.i
    If Query = "" Or DisplayedText = ""
      SetGadgetText(#StatusText, Localization::Text("details_not_found"))
      ProcedureReturn
    EndIf
    If Limit < 1
      Limit = Len(DisplayedText)
    EndIf
    Candidate = FindString(DisplayedText, Query, 1, #PB_String_NoCase)
    While Candidate > 0 And Candidate <= Limit
      Position = Candidate
      Candidate = FindString(DisplayedText, Query, Candidate + 1,
                             #PB_String_NoCase)
    Wend
    If Position = 0
      SetGadgetText(#StatusText, Localization::Text("details_not_found"))
      ProcedureReturn
    EndIf
    ShowMatch(Position, Query)
  EndProcedure

  Procedure.i Show(*Parsed.Models::ParsedCommand, InitialPageId.q, NewProfileId.i,
                   NewFtsAvailable.i, NewWebTemplate.s, NewBrowserUrlLimit.i)
    Protected InitialCommand.s
    If Opened
      SetActiveWindow(#Window)
      ProcedureReturn #True
    EndIf
    EnsureFonts()
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

    If OpenWindow(#Window, #PB_Ignore, #PB_Ignore, 880, 640,
                  Localization::Text("details_title"),
                  #PB_Window_SystemMenu | #PB_Window_SizeGadget |
                  #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget |
                  #PB_Window_ScreenCentered) = 0
      ProcedureReturn #False
    EndIf
    WindowBounds(#Window, #MinimumWidth, #MinimumHeight,
                 #PB_Ignore, #PB_Ignore)

    ContainerGadget(#Toolbar, 0, 0, 880, 46, #PB_Container_Flat)
    ComboBoxGadget(#CommandChoice, 16, 10, 150, 28)
    ComboBoxGadget(#PageChoice, 174, 10, 500, 28)
    ComboBoxGadget(#ViewChoice, 682, 10, 182, 28)
    CloseGadgetList()
    ContainerGadget(#SearchBar, 0, 46, 880, 56, #PB_Container_Flat)
    StringGadget(#SearchText, 16, 8, 764, 28, "")
    ButtonGadget(#PreviousButton, 788, 8, 36, 28, Chr(#IconPrevious))
    ButtonGadget(#NextButton, 830, 8, 36, 28, Chr(#IconNext))
    TextGadget(#StatusText, 16, 38, 848, 16, "")
    CloseGadgetList()
    ScrollAreaGadget(#ContentArea, 0, 102, 880, 486, 860, 600, 10,
                     #PB_ScrollArea_BorderLess)
    CloseGadgetList()
    ContainerGadget(#BottomBar, 0, 588, 880, 52, #PB_Container_Flat)
    ButtonGadget(#CopyButton, 16, 9, 710, 34,
                 Localization::Text("details_copy"))
    ButtonGadget(#NoteButton, 732, 9, 36, 34, Chr(#IconNote))
    ButtonGadget(#BookmarkButton, 774, 9, 36, 34, Chr(#IconBookmark))
    ButtonGadget(#WebButton, 816, 9, 36, 34, Chr(#IconWeb))
    CloseGadgetList()

    SetFontIfAvailable(#CommandChoice, FontRegular)
    SetFontIfAvailable(#PageChoice, FontRegular)
    SetFontIfAvailable(#ViewChoice, FontRegular)
    SetFontIfAvailable(#SearchText, FontRegular)
    SetFontIfAvailable(#StatusText, FontMuted)
    SetFontIfAvailable(#PreviousButton, FontIcons)
    SetFontIfAvailable(#NextButton, FontIcons)
    SetFontIfAvailable(#CopyButton, FontRegular)
    SetFontIfAvailable(#NoteButton, FontIcons)
    SetFontIfAvailable(#BookmarkButton, FontIcons)
    SetFontIfAvailable(#WebButton, FontIcons)
    SetGadgetColor(#StatusText, #PB_Gadget_FrontColor, RGB(112, 117, 124))
    GadgetToolTip(#SearchText, Localization::Text("details_search"))
    GadgetToolTip(#PreviousButton, Localization::Text("details_previous"))
    GadgetToolTip(#NextButton, Localization::Text("details_next"))
    GadgetToolTip(#NoteButton, Localization::Text("details_note"))
    GadgetToolTip(#BookmarkButton,
                  Localization::Text("details_bookmark_add"))
    GadgetToolTip(#WebButton, Localization::Text("details_web"))
    DisableGadget(#NoteButton, #True)
    DisableGadget(#BookmarkButton, #True)

    ForEach Commands()
      AddGadgetItem(#CommandChoice, -1, Commands())
    Next
    SetGadgetState(#CommandChoice, 0)
    FirstElement(Commands())
    InitialCommand = Commands()
    AddKeyboardShortcut(#Window, #PB_Shortcut_Escape, #ShortcutClose)
    AddKeyboardShortcut(#Window, #PB_Shortcut_Return, #ShortcutFind)
    Opened = #True
    Resize()
    SearchCommand(InitialCommand, InitialPageId)
    SetActiveWindow(#Window)
    ProcedureReturn #True
  EndProcedure

  Procedure Close()
    ClearBlocks()
    If Opened And IsWindow(#Window)
      CloseWindow(#Window)
    EndIf
    Opened = #False
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

  Procedure.i RenderedBlockCount()
    ProcedureReturn ListSize(Blocks())
  EndProcedure

  Procedure.i WheelRoutingCount()
    ProcedureReturn MapSize(EditorProcedures())
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
        Select EventMenu()
          Case #ShortcutClose
            Close()
          Case #ShortcutFind
            FindNext()
        EndSelect
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
            FindPrevious()
          Case #NextButton
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
        EndSelect
    EndSelect
  EndProcedure
EndModule
