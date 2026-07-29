XIncludeFile "Models.pbi"

XIncludeFile "Localization.pbi"

DeclareModule CommandTokenizer
  Declare Tokenize(Text.s, List Tokens.Models::CommandToken(), List Warnings.s())
EndDeclareModule

Module CommandTokenizer
  Procedure AddToken(List Tokens.Models::CommandToken(), Value.s, Type.i)
    If Value = ""
      ProcedureReturn
    EndIf
    AddElement(Tokens())
    Tokens()\Value = Value
    Tokens()\Type = Type
  EndProcedure

  Procedure Tokenize(Text.s, List Tokens.Models::CommandToken(), List Warnings.s())
    Protected Index.i = 1
    Protected Character.s
    Protected NextCharacter.s
    Protected Current.s
    Protected Quote.s
    Protected Escaped.i

    ClearList(Tokens())
    ClearList(Warnings())
    While Index <= Len(Text)
      Character = Mid(Text, Index, 1)
      If Index < Len(Text)
        NextCharacter = Mid(Text, Index + 1, 1)
      Else
        NextCharacter = ""
      EndIf

      If Escaped
        Current + Character
        Escaped = #False
      ElseIf Quote <> ""
        If Character = Quote
          Quote = ""
        ElseIf Character = "\" And Quote = #DQUOTE$
          Escaped = #True
        Else
          Current + Character
        EndIf
      Else
        Select Character
          Case #DQUOTE$, "'"
            Quote = Character
          Case "\"
            Escaped = #True
          Case " ", #TAB$, #LF$, #CR$
            AddToken(Tokens(), Current, Models::#TokenWord)
            Current = ""
          Case "|", "&"
            AddToken(Tokens(), Current, Models::#TokenWord)
            Current = ""
            If NextCharacter = Character
              AddToken(Tokens(), Character + NextCharacter, Models::#TokenOperator)
              Index + 1
            Else
              AddToken(Tokens(), Character, Models::#TokenOperator)
            EndIf
          Case ";"
            AddToken(Tokens(), Current, Models::#TokenWord)
            Current = ""
            AddToken(Tokens(), Character, Models::#TokenOperator)
          Default
            Current + Character
        EndSelect
      EndIf
      Index + 1
    Wend

    AddToken(Tokens(), Current, Models::#TokenWord)
    If Quote <> ""
      AddElement(Warnings())
      Warnings() = Localization::Text("parser_unclosed_quote")
    EndIf
    If Escaped
      AddElement(Warnings())
      Warnings() = Localization::Text("parser_trailing_escape")
    EndIf
  EndProcedure
EndModule
