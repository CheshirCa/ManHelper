XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "CommandTokenizer.pbi"

DeclareModule CommandParser
  Declare Parse(OriginalText.s, NormalizedText.s, *Parsed.Models::ParsedCommand)
EndDeclareModule

Module CommandParser
  Procedure.s Basename(Command.s)
    Protected Result.s = Command
    If FindString(Result, "/")
      Result = StringField(Result, CountString(Result, "/") + 1, "/")
    EndIf
    If FindString(Result, "\")
      Result = GetFilePart(Result)
    EndIf
    ProcedureReturn Result
  EndProcedure

  Procedure.i IsAssignment(Value.s)
    Protected Equals.i = FindString(Value, "=")
    Protected Name.s
    Protected Index.i
    Protected Character.s
    If Equals <= 1
      ProcedureReturn #False
    EndIf
    Name = Left(Value, Equals - 1)
    For Index = 1 To Len(Name)
      Character = Mid(Name, Index, 1)
      If Not ((Character >= "A" And Character <= "Z") Or
              (Character >= "a" And Character <= "z") Or
              (Character >= "0" And Character <= "9" And Index > 1) Or
              Character = "_")
        ProcedureReturn #False
      EndIf
    Next
    ProcedureReturn #True
  EndProcedure

  Procedure.i IsWrapper(Value.s)
    Select LCase(Value)
      Case "sudo", "doas", "env", "command", "builtin", "exec", "nohup",
           "time", "nice", "ionice", "setsid", "stdbuf"
        ProcedureReturn #True
    EndSelect
    ProcedureReturn #False
  EndProcedure

  Procedure.i OptionNeedsValue(Wrapper.s, Option.s)
    Wrapper = LCase(Wrapper)
    Select Wrapper
      Case "sudo", "doas"
        Select Option
          Case "-u", "-g", "-h", "-p", "-C", "-T", "-R", "-D"
            ProcedureReturn #True
        EndSelect
      Case "nice"
        ProcedureReturn Bool(Option = "-n" Or Option = "--adjustment")
      Case "ionice"
        ProcedureReturn Bool(Option = "-c" Or Option = "-n" Or Option = "-t")
      Case "stdbuf"
        ProcedureReturn Bool(Option = "-i" Or Option = "-o" Or Option = "-e")
      Case "time"
        ProcedureReturn Bool(Option = "-f" Or Option = "-o")
      Case "env"
        ProcedureReturn Bool(Option = "-u" Or Option = "--unset")
    EndSelect
    ProcedureReturn #False
  EndProcedure

  Procedure ProcessSegment(List Segment.s(), *Parsed.Models::ParsedCommand, FirstSegment.i)
    Protected Count.i = ListSize(Segment())
    Protected Dim Words.s(Count)
    Protected Index.i
    Protected Wrapper.s
    Protected WrapperIndex.i
    Protected Command.s
    Protected Option.s

    If Count = 0
      ProcedureReturn
    EndIf
    Index = 0
    ForEach Segment()
      Words(Index) = Segment()
      Index + 1
    Next
    Count = Index
    Index = 0

    If Index < Count And (Words(Index) = "$" Or Words(Index) = "#" Or
       Right(Words(Index), 1) = "$" Or Right(Words(Index), 1) = "#")
      Index + 1
    EndIf

    While Index < Count
      While Index < Count And IsAssignment(Words(Index))
        Index + 1
      Wend
      If Index >= Count
        ProcedureReturn
      EndIf

      Wrapper = LCase(Basename(Words(Index)))
      If IsWrapper(Wrapper) = #False
        Break
      EndIf
      WrapperIndex = Index
      Index + 1
      While Index < Count
        Option = Words(Index)
        If Wrapper = "env" And IsAssignment(Option)
          Index + 1
        ElseIf Left(Option, 1) = "-"
          Index + 1
          If FindString(Option, "=") = 0 And OptionNeedsValue(Wrapper, Option) And Index < Count
            Index + 1
          EndIf
        Else
          Break
        EndIf
      Wend
      If Index >= Count
        ; A wrapper name is also a valid command with its own manual page.
        ; If no downstream command remains, search the last wrapper itself.
        Index = WrapperIndex
        Break
      EndIf
    Wend

    If Index >= Count
      ProcedureReturn
    EndIf
    Command = Basename(Words(Index))
    If Command = ""
      ProcedureReturn
    EndIf
    AddElement(*Parsed\Commands())
    *Parsed\Commands() = Command
    If FirstSegment And *Parsed\PrimaryCommand = ""
      *Parsed\PrimaryCommand = Command
      Index + 1
      While Index < Count
        If Words(Index) = "#"
          Break
        EndIf
        AddElement(*Parsed\Arguments())
        *Parsed\Arguments() = Words(Index)
        Index + 1
      Wend
    EndIf
  EndProcedure

  Procedure Parse(OriginalText.s, NormalizedText.s, *Parsed.Models::ParsedCommand)
    NewList Tokens.Models::CommandToken()
    NewList TokenWarnings.s()
    NewList Segment.s()
    Protected FirstSegment.i = #True

    ClearStructure(*Parsed, Models::ParsedCommand)
    InitializeStructure(*Parsed, Models::ParsedCommand)
    *Parsed\OriginalText = OriginalText
    *Parsed\NormalizedText = NormalizedText

    CommandTokenizer::Tokenize(NormalizedText, Tokens(), TokenWarnings())
    ForEach TokenWarnings()
      AddElement(*Parsed\Warnings())
      *Parsed\Warnings() = TokenWarnings()
    Next

    ForEach Tokens()
      If Tokens()\Type = Models::#TokenOperator
        ProcessSegment(Segment(), *Parsed, FirstSegment)
        If ListSize(Segment()) > 0
          FirstSegment = #False
        EndIf
        ClearList(Segment())
      Else
        AddElement(Segment())
        Segment() = Tokens()\Value
      EndIf
    Next
    ProcessSegment(Segment(), *Parsed, FirstSegment)

    If *Parsed\PrimaryCommand = "" And Trim(NormalizedText) <> ""
      AddElement(*Parsed\Warnings())
      *Parsed\Warnings() = Localization::Text("parser_command_missing")
    EndIf
  EndProcedure
EndModule
