DeclareModule Utils
  Declare.s SettingsDirectory()
  Declare.s SettingsPath()
  Declare.s UserDatabasePath()
  Declare.s JoinWarnings(List Warnings.s())
  Declare.s SafeLeft(Text.s, Maximum.i)
EndDeclareModule

Module Utils
  Procedure.s SettingsDirectory()
    Protected Base.s = GetEnvironmentVariable("LOCALAPPDATA")
    If Base = ""
      Base = GetTemporaryDirectory()
    EndIf
    If Right(Base, 1) <> "\"
      Base + "\"
    EndIf
    ProcedureReturn Base + "ManHelper\"
  EndProcedure

  Procedure.s SettingsPath()
    ProcedureReturn SettingsDirectory() + "settings.ini"
  EndProcedure

  Procedure.s UserDatabasePath()
    ProcedureReturn SettingsDirectory() + "man-user.sqlite"
  EndProcedure

  Procedure.s JoinWarnings(List Warnings.s())
    Protected Result.s
    ForEach Warnings()
      If Result <> ""
        Result + #CRLF$
      EndIf
      Result + Warnings()
    Next
    ProcedureReturn Result
  EndProcedure

  Procedure.s SafeLeft(Text.s, Maximum.i)
    Protected Result.s
    Protected LastCode.i
    If Maximum < 1
      ProcedureReturn ""
    EndIf
    If Len(Text) <= Maximum
      ProcedureReturn Text
    EndIf
    Result = Left(Text, Maximum)
    LastCode = Asc(Right(Result, 1))
    ; Do not leave a leading UTF-16 surrogate without its pair.
    If LastCode >= $D800 And LastCode <= $DBFF
      Result = Left(Result, Len(Result) - 1)
    EndIf
    ProcedureReturn Result
  EndProcedure
EndModule
