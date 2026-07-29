XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "Utils.pbi"

DeclareModule TextNormalize
  Declare Normalize(*Selection.Models::Selection, Maximum.i = 4096)
EndDeclareModule

Module TextNormalize
  Procedure Normalize(*Selection.Models::Selection, Maximum.i = 4096)
    Protected Source.s
    Protected Result.s
    Protected Character.s
    Protected Code.i
    Protected Index.i
    Protected RemovedControls.i

    ClearList(*Selection\Warnings())
    If Len(*Selection\OriginalText) > Maximum
      *Selection\OriginalText = Utils::SafeLeft(*Selection\OriginalText, Maximum)
      *Selection\WasTruncated = #True
      AddElement(*Selection\Warnings())
      *Selection\Warnings() = Localization::Text("popup_truncated")
    EndIf

    Source = ReplaceString(*Selection\OriginalText, #CRLF$, #LF$)
    Source = ReplaceString(Source, #CR$, #LF$)
    For Index = 1 To Len(Source)
      Character = Mid(Source, Index, 1)
      Code = Asc(Character)
      If Code = 0
        RemovedControls = #True
      ElseIf (Code < 32 And Code <> 9 And Code <> 10) Or Code = 127
        RemovedControls = #True
      Else
        Result + Character
      EndIf
    Next

    If Len(Result) > Maximum
      Result = Utils::SafeLeft(Result, Maximum)
      If *Selection\WasTruncated = #False
        *Selection\WasTruncated = #True
        AddElement(*Selection\Warnings())
        *Selection\Warnings() = Localization::Text("popup_truncated")
      EndIf
    EndIf
    If RemovedControls
      AddElement(*Selection\Warnings())
      *Selection\Warnings() = Localization::Text("popup_controls_removed")
    EndIf
    *Selection\NormalizedText = Result
  EndProcedure
EndModule
