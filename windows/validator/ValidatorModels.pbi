DeclareModule ValidatorModels
  Enumeration
    #SeverityInfo
    #SeverityWarning
    #SeverityError
    #SeverityIncompatible
  EndEnumeration

  Structure ValidationIssue
    Severity.i
    Code.s
    Message.s
    Context.s
  EndStructure

  Structure ValidationReport
    DatabasePath.s
    ClientVersion.s
    Status.s
    StartedAt.s
    CompletedAt.s
    FileSizeBefore.q
    FileSizeAfter.q
    FileDateBefore.i
    FileDateAfter.i
    PagesCount.q
    SectionsCount.q
    AliasesCount.q
    FtsCount.q
    Map Meta.s()
    List Issues.ValidationIssue()
  EndStructure

  Declare InitReport(*Report.ValidationReport, DatabasePath.s, ClientVersion.s)
  Declare AddIssue(*Report.ValidationReport, Severity.i, Code.s, Message.s, Context.s = "")
  Declare.s SeverityName(Severity.i)
  Declare.s CalculateStatus(*Report.ValidationReport)
  Declare.i ExitCodeForStatus(Status.s)
EndDeclareModule

Module ValidatorModels
  Procedure InitReport(*Report.ValidationReport, DatabasePath.s, ClientVersion.s)
    ClearStructure(*Report, ValidationReport)
    InitializeStructure(*Report, ValidationReport)
    *Report\DatabasePath = DatabasePath
    *Report\ClientVersion = ClientVersion
    *Report\Status = "INVALID"
    *Report\StartedAt = FormatDate("%yyyy-%mm-%ddT%hh:%ii:%ss", Date())
  EndProcedure

  Procedure AddIssue(*Report.ValidationReport, Severity.i, Code.s, Message.s, Context.s = "")
    AddElement(*Report\Issues())
    *Report\Issues()\Severity = Severity
    *Report\Issues()\Code = Code
    *Report\Issues()\Message = Message
    *Report\Issues()\Context = Context
  EndProcedure

  Procedure.s SeverityName(Severity.i)
    Select Severity
      Case #SeverityInfo
        ProcedureReturn "INFO"
      Case #SeverityWarning
        ProcedureReturn "WARNING"
      Case #SeverityError
        ProcedureReturn "ERROR"
      Case #SeverityIncompatible
        ProcedureReturn "INCOMPATIBLE"
    EndSelect
    ProcedureReturn "UNKNOWN"
  EndProcedure

  Procedure.s CalculateStatus(*Report.ValidationReport)
    Protected HasWarning.i
    ForEach *Report\Issues()
      Select *Report\Issues()\Severity
        Case #SeverityIncompatible
          ProcedureReturn "INCOMPATIBLE"
        Case #SeverityError
          *Report\Status = "INVALID"
        Case #SeverityWarning
          HasWarning = #True
      EndSelect
    Next

    If *Report\Status = "INVALID"
      ; InitReport starts with INVALID, therefore distinguish actual errors.
      ForEach *Report\Issues()
        If *Report\Issues()\Severity = #SeverityError
          ProcedureReturn "INVALID"
        EndIf
      Next
    EndIf

    If HasWarning
      ProcedureReturn "VALID_WITH_WARNINGS"
    EndIf
    ProcedureReturn "VALID"
  EndProcedure

  Procedure.i ExitCodeForStatus(Status.s)
    Select Status
      Case "VALID", "VALID_WITH_WARNINGS"
        ProcedureReturn 0
      Case "INVALID"
        ProcedureReturn 2
      Case "INCOMPATIBLE"
        ProcedureReturn 3
    EndSelect
    ProcedureReturn 4
  EndProcedure
EndModule
