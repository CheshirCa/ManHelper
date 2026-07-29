DeclareModule ValidatorUtils
  Declare.s IsoTimestamp()
  Declare.i CompareVersions(LeftVersion.s, RightVersion.s)
  Declare.i IsSafeInteger(Text.s)
  Declare.s SqliteReadOnlyUri(Path.s)
  Declare.s TruncateText(Text.s, Maximum.i = 240)
EndDeclareModule

Module ValidatorUtils
  Procedure.s IsoTimestamp()
    ProcedureReturn FormatDate("%yyyy-%mm-%ddT%hh:%ii:%ss", Date())
  EndProcedure

  Procedure.i VersionPart(Version.s, Index.i)
    Protected Part.s = StringField(Version, Index, ".")
    Protected Digits.s
    Protected Position.i
    For Position = 1 To Len(Part)
      If Mid(Part, Position, 1) >= "0" And Mid(Part, Position, 1) <= "9"
        Digits + Mid(Part, Position, 1)
      Else
        Break
      EndIf
    Next
    If Digits = ""
      ProcedureReturn 0
    EndIf
    ProcedureReturn Val(Digits)
  EndProcedure

  Procedure.i CompareVersions(LeftVersion.s, RightVersion.s)
    Protected Index.i
    Protected LeftPart.i
    Protected RightPart.i
    For Index = 1 To 4
      LeftPart = VersionPart(LeftVersion, Index)
      RightPart = VersionPart(RightVersion, Index)
      If LeftPart < RightPart
        ProcedureReturn -1
      ElseIf LeftPart > RightPart
        ProcedureReturn 1
      EndIf
    Next
    ProcedureReturn 0
  EndProcedure

  Procedure.i IsSafeInteger(Text.s)
    Protected Index.i
    If Text = ""
      ProcedureReturn #False
    EndIf
    For Index = 1 To Len(Text)
      If Mid(Text, Index, 1) < "0" Or Mid(Text, Index, 1) > "9"
        ProcedureReturn #False
      EndIf
    Next
    ProcedureReturn #True
  EndProcedure

  Procedure.s PercentEncodeUriPath(Path.s)
    Protected Result.s
    Protected Character.s
    Protected Code.i
    Protected Index.i
    Path = ReplaceString(Path, "\", "/")
    For Index = 1 To Len(Path)
      Character = Mid(Path, Index, 1)
      Code = Asc(Character)
      Select Character
        Case " ", "#", "?", "%"
          If Code < 128
            Result + "%" + RSet(Hex(Code, #PB_Byte), 2, "0")
          Else
            ; Non-ASCII path characters remain Unicode. SQLite accepts UTF-8 URI text.
            Result + Character
          EndIf
        Default
          Result + Character
      EndSelect
    Next
    ProcedureReturn Result
  EndProcedure

  Procedure.s SqliteReadOnlyUri(Path.s)
    Protected FullPath.s = Path
    If GetPathPart(Path) = ""
      FullPath = GetCurrentDirectory() + Path
    EndIf
    FullPath = ReplaceString(FullPath, "\", "/")
    If Mid(FullPath, 2, 1) = ":"
      ProcedureReturn "file:///" + PercentEncodeUriPath(FullPath) + "?mode=ro"
    EndIf
    ProcedureReturn "file:" + PercentEncodeUriPath(FullPath) + "?mode=ro"
  EndProcedure

  Procedure.s TruncateText(Text.s, Maximum.i = 240)
    Text = ReplaceString(Text, #CR$, " ")
    Text = ReplaceString(Text, #LF$, " ")
    If Len(Text) > Maximum
      ProcedureReturn Left(Text, Maximum - 1) + "…"
    EndIf
    ProcedureReturn Text
  EndProcedure
EndModule
