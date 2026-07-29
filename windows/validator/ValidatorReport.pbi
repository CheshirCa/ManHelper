XIncludeFile "ValidatorModels.pbi"

DeclareModule ValidatorReport
  Declare.s AsText(*Report.ValidatorModels::ValidationReport)
  Declare.s AsJson(*Report.ValidatorModels::ValidationReport)
  Declare.i Save(*Report.ValidatorModels::ValidationReport, Path.s, Format.s)
EndDeclareModule

Module ValidatorReport
  Procedure AddString(*Object, Key.s, Value.s)
    SetJSONString(AddJSONMember(*Object, Key), Value)
  EndProcedure

  Procedure AddInteger(*Object, Key.s, Value.q)
    SetJSONQuad(AddJSONMember(*Object, Key), Value)
  EndProcedure

  Procedure.s AsText(*Report.ValidatorModels::ValidationReport)
    Protected Result.s
    Result = "ManBase Validator " + *Report\ClientVersion + #CRLF$
    Result + "Status: " + *Report\Status + #CRLF$
    Result + "Database: " + *Report\DatabasePath + #CRLF$
    Result + "Started: " + *Report\StartedAt + #CRLF$
    Result + "Completed: " + *Report\CompletedAt + #CRLF$
    Result + "Pages: " + Str(*Report\PagesCount) + #CRLF$
    Result + "Sections: " + Str(*Report\SectionsCount) + #CRLF$
    Result + "Aliases: " + Str(*Report\AliasesCount) + #CRLF$
    Result + "FTS rows: " + Str(*Report\FtsCount) + #CRLF$
    Result + #CRLF$ + "Meta:" + #CRLF$
    ForEach *Report\Meta()
      Result + "  " + MapKey(*Report\Meta()) + " = " + *Report\Meta() + #CRLF$
    Next
    Result + #CRLF$ + "Checks:" + #CRLF$
    If ListSize(*Report\Issues()) = 0
      Result + "  No issues." + #CRLF$
    Else
      ForEach *Report\Issues()
        Result + "  [" + ValidatorModels::SeverityName(*Report\Issues()\Severity) + "] "
        Result + *Report\Issues()\Code + ": " + *Report\Issues()\Message
        If *Report\Issues()\Context <> ""
          Result + " (" + *Report\Issues()\Context + ")"
        EndIf
        Result + #CRLF$
      Next
    EndIf
    ProcedureReturn Result
  EndProcedure

  Procedure.s AsJson(*Report.ValidatorModels::ValidationReport)
    Protected Json.i = CreateJSON(#PB_Any)
    Protected *Root
    Protected *Counts
    Protected *Meta
    Protected *Issues
    Protected *Issue
    Protected Result.s
    If Json = 0
      ProcedureReturn "{}"
    EndIf
    *Root = SetJSONObject(JSONValue(Json))
    AddString(*Root, "validator_version", *Report\ClientVersion)
    AddString(*Root, "status", *Report\Status)
    AddString(*Root, "database", *Report\DatabasePath)
    AddString(*Root, "started_at", *Report\StartedAt)
    AddString(*Root, "completed_at", *Report\CompletedAt)

    *Counts = SetJSONObject(AddJSONMember(*Root, "counts"))
    AddInteger(*Counts, "pages", *Report\PagesCount)
    AddInteger(*Counts, "sections", *Report\SectionsCount)
    AddInteger(*Counts, "aliases", *Report\AliasesCount)
    AddInteger(*Counts, "fts", *Report\FtsCount)

    *Meta = SetJSONObject(AddJSONMember(*Root, "meta"))
    ForEach *Report\Meta()
      AddString(*Meta, MapKey(*Report\Meta()), *Report\Meta())
    Next

    *Issues = SetJSONArray(AddJSONMember(*Root, "issues"))
    ForEach *Report\Issues()
      *Issue = SetJSONObject(AddJSONElement(*Issues))
      AddString(*Issue, "severity", ValidatorModels::SeverityName(*Report\Issues()\Severity))
      AddString(*Issue, "code", *Report\Issues()\Code)
      AddString(*Issue, "message", *Report\Issues()\Message)
      AddString(*Issue, "context", *Report\Issues()\Context)
    Next
    Result = ComposeJSON(Json, #PB_JSON_PrettyPrint)
    FreeJSON(Json)
    ProcedureReturn Result
  EndProcedure

  Procedure.i Save(*Report.ValidatorModels::ValidationReport, Path.s, Format.s)
    Protected File.i
    Protected Content.s
    If Path = ""
      ProcedureReturn #True
    EndIf
    If Format = "json"
      Content = AsJson(*Report)
    Else
      Content = AsText(*Report)
    EndIf
    File = CreateFile(#PB_Any, Path, #PB_File_SharedRead)
    If File = 0
      ProcedureReturn #False
    EndIf
    WriteString(File, Content, #PB_UTF8)
    CloseFile(File)
    ProcedureReturn #True
  EndProcedure
EndModule
