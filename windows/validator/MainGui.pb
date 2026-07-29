EnableExplicit

XIncludeFile "Version.pbi"
XIncludeFile "ValidatorModels.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "Utils.pbi"
XIncludeFile "ValidatorDatabase.pbi"
XIncludeFile "ValidatorSchema.pbi"
XIncludeFile "ValidatorIntegrity.pbi"
XIncludeFile "ValidatorEncoding.pbi"
XIncludeFile "ValidatorContent.pbi"
XIncludeFile "ValidatorFts.pbi"
XIncludeFile "ValidatorReport.pbi"
XIncludeFile "ValidatorRunner.pbi"

Enumeration Windows
  #WindowMain
EndEnumeration

Enumeration Gadgets
  #DatabaseLabel
  #DatabasePath
  #BrowseButton
  #ValidateButton
  #SaveJsonButton
  #SaveTextButton
  #Progress
  #StatusLabel
  #CountsLabel
  #IssuesList
  #DetailsLabel
  #DetailsEditor
EndEnumeration

Global Report.ValidatorModels::ValidationReport
Global HasReport.i
Global SmokeTest.i

Procedure.s GuiText(Key.s)
  ProcedureReturn Localization::Text(Key)
EndProcedure

Procedure.i SeverityCount(Severity.i)
  Protected Count.i
  ForEach Report\Issues()
    If Report\Issues()\Severity = Severity
      Count + 1
    EndIf
  Next
  ProcedureReturn Count
EndProcedure

Procedure.s CountsText()
  Protected Value.s = GuiText("gui_counts")
  Value = ReplaceString(Value, "%pages%", Str(Report\PagesCount))
  Value = ReplaceString(Value, "%sections%", Str(Report\SectionsCount))
  Value = ReplaceString(Value, "%aliases%", Str(Report\AliasesCount))
  Value = ReplaceString(Value, "%fts%", Str(Report\FtsCount))
  ProcedureReturn Value
EndProcedure

Procedure.i StatusColor(Status.s)
  Select Status
    Case "VALID"
      ProcedureReturn RGB(20, 120, 50)
    Case "VALID_WITH_WARNINGS"
      ProcedureReturn RGB(180, 105, 0)
    Case "INCOMPATIBLE", "INVALID"
      ProcedureReturn RGB(180, 30, 30)
  EndSelect
  ProcedureReturn RGB(60, 60, 60)
EndProcedure

Procedure FillReport()
  Protected Text.s
  Protected WarningCount.i = SeverityCount(ValidatorModels::#SeverityWarning)
  Protected ErrorCount.i = SeverityCount(ValidatorModels::#SeverityError) +
                                   SeverityCount(ValidatorModels::#SeverityIncompatible)

  ClearGadgetItems(#IssuesList)
  ForEach Report\Issues()
    Text = ValidatorModels::SeverityName(Report\Issues()\Severity) + #LF$
    Text + Report\Issues()\Code + #LF$
    Text + ValidatorUtils::TruncateText(Report\Issues()\Message, 180) + #LF$
    Text + ValidatorUtils::TruncateText(Report\Issues()\Context, 220)
    AddGadgetItem(#IssuesList, -1, Text)
  Next

  SetGadgetText(#StatusLabel, GuiText("gui_result") + Report\Status + "   " +
                                  GuiText("gui_warning_count") + Str(WarningCount) + "   " +
                                  GuiText("gui_error_count") + Str(ErrorCount))
  SetGadgetColor(#StatusLabel, #PB_Gadget_FrontColor, StatusColor(Report\Status))
  SetGadgetText(#CountsLabel, CountsText())
  SetGadgetText(#DetailsEditor, ValidatorReport::AsText(@Report))
  DisableGadget(#SaveJsonButton, #False)
  DisableGadget(#SaveTextButton, #False)
  HasReport = #True
EndProcedure

Procedure SetBusy(Busy.i)
  DisableGadget(#DatabasePath, Busy)
  DisableGadget(#BrowseButton, Busy)
  DisableGadget(#ValidateButton, Busy)
  If Busy
    DisableGadget(#SaveJsonButton, #True)
    DisableGadget(#SaveTextButton, #True)
    SetGadgetState(#Progress, 20)
    SetGadgetText(#StatusLabel, GuiText("gui_running"))
    SetGadgetColor(#StatusLabel, #PB_Gadget_FrontColor, RGB(50, 90, 160))
  Else
    SetGadgetState(#Progress, 100)
  EndIf
EndProcedure

Procedure ValidateSelectedDatabase()
  Protected Path.s = Trim(GetGadgetText(#DatabasePath))
  If Path = ""
    MessageRequester(GuiText("gui_title"), GuiText("gui_no_database"), #PB_MessageRequester_Warning)
    ProcedureReturn
  EndIf

  SetBusy(#True)
  ValidatorRunner::Run(Path, @Report)
  FillReport()
  SetBusy(#False)
EndProcedure

Procedure BrowseDatabase()
  Protected Selected.s = OpenFileRequester(GuiText("gui_select_database"),
                                           GetGadgetText(#DatabasePath),
                                           GuiText("gui_database_filter"), 0,
                                           0, WindowID(#WindowMain))
  If Selected <> ""
    SetGadgetText(#DatabasePath, Selected)
  EndIf
EndProcedure

Procedure SaveReport(Format.s)
  Protected Filter.s
  Protected Extension.s
  Protected Path.s
  If HasReport = #False
    ProcedureReturn
  EndIf
  If Format = "json"
    Filter = GuiText("gui_report_filter_json")
    Extension = "json"
  Else
    Filter = GuiText("gui_report_filter_text")
    Extension = "txt"
  EndIf
  Path = SaveFileRequester(GuiText("gui_save_report"), GuiText("gui_default_report") + "." + Extension,
                           Filter, 0, WindowID(#WindowMain))
  If Path = ""
    ProcedureReturn
  EndIf
  If GetExtensionPart(Path) = ""
    Path + "." + Extension
  EndIf
  If ValidatorReport::Save(@Report, Path, Format)
    SetGadgetText(#StatusLabel, GuiText("gui_saved") + " " + Path)
  Else
    MessageRequester(GuiText("gui_title"), GuiText("gui_save_failed"), #PB_MessageRequester_Error)
  EndIf
EndProcedure

Procedure ShowSelectedIssue()
  Protected Index.i = GetGadgetState(#IssuesList)
  Protected Text.s
  If Index < 0 Or SelectElement(Report\Issues(), Index) = 0
    ProcedureReturn
  EndIf
  Text = "[" + ValidatorModels::SeverityName(Report\Issues()\Severity) + "] " +
         Report\Issues()\Code + #CRLF$ + #CRLF$
  Text + Report\Issues()\Message
  If Report\Issues()\Context <> ""
    Text + #CRLF$ + #CRLF$ + Report\Issues()\Context
  EndIf
  SetGadgetText(#DetailsEditor, Text)
EndProcedure

Procedure ResizeInterface()
  Protected Width.i = WindowWidth(#WindowMain)
  Protected Height.i = WindowHeight(#WindowMain)
  Protected ListHeight.i = (Height - 215) * 2 / 3
  Protected DetailsY.i
  Protected DetailsHeight.i

  If ListHeight < 180
    ListHeight = 180
  EndIf

  ResizeGadget(#DatabasePath, #PB_Ignore, #PB_Ignore, Width - 245, #PB_Ignore)
  ResizeGadget(#BrowseButton, Width - 115, #PB_Ignore, #PB_Ignore, #PB_Ignore)
  ResizeGadget(#Progress, #PB_Ignore, #PB_Ignore, Width - 40, #PB_Ignore)
  ResizeGadget(#StatusLabel, #PB_Ignore, #PB_Ignore, Width - 40, #PB_Ignore)
  ResizeGadget(#CountsLabel, #PB_Ignore, #PB_Ignore, Width - 40, #PB_Ignore)
  ResizeGadget(#IssuesList, #PB_Ignore, #PB_Ignore, Width - 40, ListHeight)

  DetailsY = 165 + ListHeight
  DetailsHeight = Height - DetailsY - 44
  If DetailsHeight < 80
    DetailsHeight = 80
  EndIf
  ResizeGadget(#DetailsLabel, #PB_Ignore, DetailsY, Width - 40, #PB_Ignore)
  ResizeGadget(#DetailsEditor, #PB_Ignore, DetailsY + 24, Width - 40, DetailsHeight)
EndProcedure

Procedure ParseGuiArguments()
  Protected Index.i
  Protected Argument.s
  While Index < CountProgramParameters()
    Argument = ProgramParameter(Index)
    Select Argument
      Case "--database", "-d"
        If Index + 1 < CountProgramParameters()
          Index + 1
          SetGadgetText(#DatabasePath, ProgramParameter(Index))
        EndIf
      Case "--smoke-test"
        SmokeTest = #True
    EndSelect
    Index + 1
  Wend
EndProcedure

If OpenWindow(#WindowMain, 0, 0, 980, 700, GuiText("gui_title"),
              #PB_Window_SystemMenu | #PB_Window_SizeGadget |
              #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget |
              #PB_Window_ScreenCentered) = 0
  End 1
EndIf

WindowBounds(#WindowMain, 760, 620, #PB_Ignore, #PB_Ignore)
TextGadget(#DatabaseLabel, 20, 20, 100, 24, GuiText("gui_database"))
StringGadget(#DatabasePath, 120, 16, 735, 28, "")
ButtonGadget(#BrowseButton, 865, 16, 95, 28, GuiText("gui_browse"))
ButtonGadget(#ValidateButton, 20, 54, 120, 30, GuiText("gui_validate"))
ButtonGadget(#SaveJsonButton, 150, 54, 140, 30, GuiText("gui_save_json"))
ButtonGadget(#SaveTextButton, 300, 54, 150, 30, GuiText("gui_save_text"))
ProgressBarGadget(#Progress, 20, 92, 940, 12, 0, 100)
TextGadget(#StatusLabel, 20, 112, 940, 22, GuiText("gui_ready"))
TextGadget(#CountsLabel, 20, 134, 940, 20, "")
ListIconGadget(#IssuesList, 20, 155, 940, 323, GuiText("gui_severity"), 90,
               #PB_ListIcon_FullRowSelect | #PB_ListIcon_GridLines |
               #PB_ListIcon_AlwaysShowSelection)
AddGadgetColumn(#IssuesList, 1, GuiText("gui_code"), 190)
AddGadgetColumn(#IssuesList, 2, GuiText("gui_message"), 350)
AddGadgetColumn(#IssuesList, 3, GuiText("gui_context"), 300)
TextGadget(#DetailsLabel, 20, 488, 940, 22, GuiText("gui_details"))
EditorGadget(#DetailsEditor, 20, 512, 940, 168, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)

DisableGadget(#SaveJsonButton, #True)
DisableGadget(#SaveTextButton, #True)
ParseGuiArguments()

If SmokeTest
  PostEvent(#PB_Event_CloseWindow, #WindowMain, 0)
EndIf

Define Event.i
Define Finished.i
Repeat
  Event = WaitWindowEvent()
  Select Event
    Case #PB_Event_CloseWindow
      Finished = #True
    Case #PB_Event_SizeWindow
      ResizeInterface()
    Case #PB_Event_Gadget
      Select EventGadget()
        Case #BrowseButton
          BrowseDatabase()
        Case #ValidateButton
          ValidateSelectedDatabase()
        Case #SaveJsonButton
          SaveReport("json")
        Case #SaveTextButton
          SaveReport("text")
        Case #IssuesList
          If EventType() = #PB_EventType_Change
            ShowSelectedIssue()
          EndIf
      EndSelect
  EndSelect
Until Finished

End 0
