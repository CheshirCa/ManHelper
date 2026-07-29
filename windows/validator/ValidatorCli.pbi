XIncludeFile "ValidatorAppState.pbi"
XIncludeFile "Localization.pbi"

DeclareModule ValidatorCli
  Declare.i Parse(*Options.ValidatorAppState::CliOptions, *Error.String)
  Declare PrintUsage()
EndDeclareModule

Module ValidatorCli
  Procedure PrintUsage()
    PrintN(Localization::Text("usage"))
  EndProcedure

  Procedure.i RequireValue(Index.i, Count.i, Name.s, *Error.String)
    If Index + 1 >= Count
      *Error\s = Localization::Text("missing_value") + " " + Name
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i Parse(*Options.ValidatorAppState::CliOptions, *Error.String)
    Protected Count.i = CountProgramParameters()
    Protected Index.i
    Protected Argument.s

    *Options\Format = ""
    While Index < Count
      Argument = ProgramParameter(Index)
      Select Argument
        Case "--database", "-d"
          If RequireValue(Index, Count, Argument, *Error) = #False
            ProcedureReturn #False
          EndIf
          Index + 1
          *Options\DatabasePath = ProgramParameter(Index)
        Case "--report", "-r"
          If RequireValue(Index, Count, Argument, *Error) = #False
            ProcedureReturn #False
          EndIf
          Index + 1
          *Options\ReportPath = ProgramParameter(Index)
        Case "--format", "-f"
          If RequireValue(Index, Count, Argument, *Error) = #False
            ProcedureReturn #False
          EndIf
          Index + 1
          *Options\Format = LCase(ProgramParameter(Index))
          If *Options\Format <> "text" And *Options\Format <> "json"
            *Error\s = "--format: ожидается text или json."
            ProcedureReturn #False
          EndIf
        Case "--help", "-h", "/?"
          *Options\ShowHelp = #True
        Case "--version", "-v"
          *Options\ShowVersion = #True
        Default
          *Error\s = Localization::Text("unknown_argument") + " " + Argument
          ProcedureReturn #False
      EndSelect
      Index + 1
    Wend

    If *Options\ShowHelp Or *Options\ShowVersion
      ProcedureReturn #True
    EndIf
    If *Options\DatabasePath = ""
      *Error\s = Localization::Text("missing_database")
      ProcedureReturn #False
    EndIf
    If *Options\Format = ""
      If LCase(GetExtensionPart(*Options\ReportPath)) = "json"
        *Options\Format = "json"
      Else
        *Options\Format = "text"
      EndIf
    EndIf
    ProcedureReturn #True
  EndProcedure
EndModule
