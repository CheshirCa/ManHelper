XIncludeFile "Models.pbi"
XIncludeFile "TextNormalize.pbi"

DeclareModule ClipboardReader
  Declare Capture(*Selection.Models::Selection, Maximum.i = 4096)
EndDeclareModule

Module ClipboardReader
  Procedure Capture(*Selection.Models::Selection, Maximum.i = 4096)
    ClearStructure(*Selection, Models::Selection)
    InitializeStructure(*Selection, Models::Selection)
    ; GetClipboardText() reads Unicode text and never changes clipboard content.
    *Selection\OriginalText = GetClipboardText()
    TextNormalize::Normalize(*Selection, Maximum)
  EndProcedure
EndModule
