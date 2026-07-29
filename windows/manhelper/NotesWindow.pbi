XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "UserData.pbi"

DeclareModule NotesWindow
  Declare.i Show(*Ref.Models::UserPageRef)
  Declare Close()
  Declare.i IsOpen()
  Declare.i WindowNumber()
  Declare HandleEvent(Event.i)
EndDeclareModule

Module NotesWindow
  #Window = 3
  Enumeration 200
    #PageLabel
    #Editor
    #Status
    #SaveButton
    #DeleteButton
    #CloseButton
  EndEnumeration

  Global Opened.i
  Global Ref.Models::UserPageRef

  Procedure Resize()
    Protected Width.i = WindowWidth(#Window)
    Protected Height.i = WindowHeight(#Window)
    ResizeGadget(#PageLabel, 16, 12, Width - 32, 22)
    ResizeGadget(#Editor, 16, 40, Width - 32, Height - 108)
    ResizeGadget(#Status, 16, Height - 58, Width - 350, 24)
    ResizeGadget(#SaveButton, Width - 330, Height - 66, 100, 32)
    ResizeGadget(#DeleteButton, Width - 220, Height - 66, 100, 32)
    ResizeGadget(#CloseButton, Width - 110, Height - 66, 94, 32)
  EndProcedure

  Procedure.i Show(*NewRef.Models::UserPageRef)
    Protected Text.String
    If UserDatabase::IsOpen() = #False
      ProcedureReturn #False
    EndIf
    If Opened
      Close()
    EndIf
    CopyStructure(*NewRef, @Ref, Models::UserPageRef)
    If OpenWindow(#Window, #PB_Ignore, #PB_Ignore, 680, 440,
                  Localization::Text("notes_title"),
                  #PB_Window_SystemMenu | #PB_Window_SizeGadget |
                  #PB_Window_ScreenCentered) = 0
      ProcedureReturn #False
    EndIf
    WindowBounds(#Window, 480, 300, #PB_Ignore, #PB_Ignore)
    TextGadget(#PageLabel, 16, 12, 648, 22,
               Ref\Name + "(" + Ref\Section + ")")
    EditorGadget(#Editor, 16, 40, 648, 332, #PB_Editor_WordWrap)
    TextGadget(#Status, 16, 382, 314, 24, "")
    ButtonGadget(#SaveButton, 350, 374, 100, 32,
                 Localization::Text("notes_save"))
    ButtonGadget(#DeleteButton, 460, 374, 100, 32,
                 Localization::Text("notes_delete"))
    ButtonGadget(#CloseButton, 570, 374, 94, 32,
                 Localization::Text("details_close"))
    If UserData::LoadNote(@Ref, @Text)
      SetGadgetText(#Editor, Text\s)
    EndIf
    Opened = #True
    Resize()
    SetActiveWindow(#Window)
    SetActiveGadget(#Editor)
    ProcedureReturn #True
  EndProcedure

  Procedure Close()
    If Opened And IsWindow(#Window)
      CloseWindow(#Window)
    EndIf
    Opened = #False
    ClearStructure(@Ref, Models::UserPageRef)
  EndProcedure

  Procedure.i IsOpen()
    ProcedureReturn Opened
  EndProcedure

  Procedure.i WindowNumber()
    ProcedureReturn #Window
  EndProcedure

  Procedure HandleEvent(Event.i)
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
          Case #SaveButton
            If UserData::SaveNote(@Ref, GetGadgetText(#Editor))
              SetGadgetText(#Status, Localization::Text("notes_saved"))
            EndIf
          Case #DeleteButton
            If UserData::DeleteNote(@Ref)
              SetGadgetText(#Editor, "")
              SetGadgetText(#Status, Localization::Text("notes_deleted"))
            EndIf
          Case #CloseButton
            Close()
        EndSelect
    EndSelect
  EndProcedure
EndModule
