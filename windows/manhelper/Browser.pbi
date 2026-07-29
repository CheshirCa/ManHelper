XIncludeFile "Localization.pbi"

DeclareModule Browser
  Declare.s EncodeQuery(Query.s)
  Declare.s ResolveQuery(NormalizedText.s, Command.s, PageName.s, Section.s)
  Declare.i BuildUrl(Query.s, Template.s, Maximum.i, *Url.String, *Error.String)
  Declare.i OpenUrl(Url.s)
  Declare.i Search(Query.s, Template.s, Maximum.i, *Error.String)
EndDeclareModule

Module Browser
  Procedure.s ResolveQuery(NormalizedText.s, Command.s, PageName.s, Section.s)
    If Trim(NormalizedText) <> ""
      ProcedureReturn Trim(NormalizedText)
    EndIf
    If Trim(Command) <> ""
      ProcedureReturn Trim(Command)
    EndIf
    If Trim(PageName) <> ""
      If Trim(Section) <> ""
        ProcedureReturn Trim(PageName) + "(" + Trim(Section) + ")"
      EndIf
      ProcedureReturn Trim(PageName)
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.s EncodeQuery(Query.s)
    Protected Bytes.i = StringByteLength(Query, #PB_UTF8)
    Protected *Buffer
    Protected Index.i
    Protected Value.i
    Protected Result.s

    If Bytes = 0
      ProcedureReturn ""
    EndIf
    *Buffer = AllocateMemory(Bytes + 1)
    If *Buffer = 0
      ProcedureReturn ""
    EndIf
    PokeS(*Buffer, Query, -1, #PB_UTF8)
    For Index = 0 To Bytes - 1
      Value = PeekA(*Buffer + Index) & $FF
      If (Value >= 'a' And Value <= 'z') Or
         (Value >= 'A' And Value <= 'Z') Or
         (Value >= '0' And Value <= '9') Or
         Value = '-' Or Value = '.' Or Value = '_' Or Value = '~'
        Result + Chr(Value)
      Else
        Result + "%" + RSet(Hex(Value), 2, "0")
      EndIf
    Next
    FreeMemory(*Buffer)
    ProcedureReturn Result
  EndProcedure

  Procedure.i BuildUrl(Query.s, Template.s, Maximum.i, *Url.String, *Error.String)
    Protected LowerTemplate.s = LCase(Trim(Template))
    *Url\s = ""
    *Error\s = ""
    If FindString(Template, "{query}") = 0 Or
       (Left(LowerTemplate, 8) <> "https://" And Left(LowerTemplate, 7) <> "http://")
      *Error\s = Localization::Text("browser_invalid_template")
      ProcedureReturn #False
    EndIf
    *Url\s = ReplaceString(Trim(Template), "{query}", EncodeQuery(Query))
    If Len(*Url\s) > Maximum
      *Url\s = ""
      *Error\s = Localization::Text("browser_url_too_long")
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i OpenUrl(Url.s)
    ; RunProgram() expects an executable and does not reliably resolve the
    ; user's URL association. ShellExecuteW opens the system browser directly,
    ; without cmd.exe or interpreting the selected text as a command.
    ProcedureReturn Bool(ShellExecute_(0, "open", Url, 0, 0, #SW_SHOWNORMAL) > 32)
  EndProcedure

  Procedure.i Search(Query.s, Template.s, Maximum.i, *Error.String)
    Protected Url.String
    If BuildUrl(Query, Template, Maximum, @Url, *Error) = #False
      ProcedureReturn #False
    EndIf
    If OpenUrl(Url\s) = #False
      *Error\s = Localization::Text("browser_open_failed")
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure
EndModule
