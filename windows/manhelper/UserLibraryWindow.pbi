XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "UserData.pbi"

DeclareModule UserLibraryWindow
  Declare.i Show()
  Declare Close()
  Declare.i IsOpen()
  Declare.i WindowNumber()
  Declare HandleEvent(Event.i)
EndDeclareModule

Module UserLibraryWindow
  #Window = 4
  Enumeration 300
    #ModeChoice
    #Items
    #DeleteButton
    #RefreshButton
    #CloseButton
  EndEnumeration
  Global Opened.i
  Global NewList Items.Models::UserListItem()

  Procedure Resize()
    Protected Width.i = WindowWidth(#Window)
    Protected Height.i = WindowHeight(#Window)
    ResizeGadget(#ModeChoice, 16, 14, Width - 32, 28)
    ResizeGadget(#Items, 16, 52, Width - 32, Height - 112)
    ResizeGadget(#DeleteButton, 16, Height - 48, 170, 32)
    ResizeGadget(#RefreshButton, 196, Height - 48, 110, 32)
    ResizeGadget(#CloseButton, Width - 110, Height - 48, 94, 32)
  EndProcedure

  Procedure Refresh()
    Protected PageText.s
    ClearGadgetItems(#Items)
    If GetGadgetState(#ModeChoice) = 0
      UserData::LoadBookmarks(Items())
    Else
      UserData::LoadHistory(Items())
    EndIf
    ForEach Items()
      PageText = Items()\Name + "(" + Items()\Section + ")"
      AddGadgetItem(#Items, -1, PageText + #LF$ + Items()\Query + #LF$ +
                    Items()\Timestamp)
    Next
  EndProcedure

  Procedure.i Show()
    If UserDatabase::IsOpen() = #False
      ProcedureReturn #False
    EndIf
    If Opened
      SetActiveWindow(#Window)
      Refresh()
      ProcedureReturn #True
    EndIf
    If OpenWindow(#Window, #PB_Ignore, #PB_Ignore, 760, 520,
                  Localization::Text("library_title"),
                  #PB_Window_SystemMenu | #PB_Window_SizeGadget |
                  #PB_Window_ScreenCentered) = 0
      ProcedureReturn #False
    EndIf
    WindowBounds(#Window, 560, 360, #PB_Ignore, #PB_Ignore)
    ComboBoxGadget(#ModeChoice, 16, 14, 728, 28)
    AddGadgetItem(#ModeChoice, -1, Localization::Text("library_bookmarks"))
    AddGadgetItem(#ModeChoice, -1, Localization::Text("library_history"))
    SetGadgetState(#ModeChoice, 0)
    ListIconGadget(#Items, 16, 52, 728, 408,
                   Localization::Text("library_page"), 180,
                   #PB_ListIcon_FullRowSelect | #PB_ListIcon_AlwaysShowSelection)
    AddGadgetColumn(#Items, 1, Localization::Text("library_query"), 330)
    AddGadgetColumn(#Items, 2, Localization::Text("library_date"), 180)
    ButtonGadget(#DeleteButton, 16, 472, 170, 32,
                 Localization::Text("library_delete"))
    ButtonGadget(#RefreshButton, 196, 472, 110, 32,
                 Localization::Text("library_refresh"))
    ButtonGadget(#CloseButton, 650, 472, 94, 32,
                 Localization::Text("details_close"))
    Opened = #True
    Resize()
    Refresh()
    SetActiveWindow(#Window)
    ProcedureReturn #True
  EndProcedure

  Procedure Close()
    If Opened And IsWindow(#Window)
      CloseWindow(#Window)
    EndIf
    Opened = #False
    ClearList(Items())
  EndProcedure

  Procedure.i IsOpen()
    ProcedureReturn Opened
  EndProcedure

  Procedure.i WindowNumber()
    ProcedureReturn #Window
  EndProcedure

  Procedure HandleEvent(Event.i)
    Protected Index.i
    If Opened = #False Or EventWindow() <> #Window
      ProcedureReturn
    EndIf
    Select Event
      Case #PB_Event_CloseWindow
        Close()
      Case #PB_Event_SizeWindow
        Resize()
      Case #PB_Event_Gadget
        Select EventGadget()
          Case #ModeChoice, #RefreshButton
            Refresh()
          Case #DeleteButton
            Index = GetGadgetState(#Items)
            If SelectElement(Items(), Index)
              If GetGadgetState(#ModeChoice) = 0
                UserData::DeleteBookmark(Items()\PageKey)
              Else
                UserData::DeleteHistory(Items()\Id)
              EndIf
              Refresh()
            EndIf
          Case #CloseButton
            Close()
        EndSelect
    EndSelect
  EndProcedure
EndModule
