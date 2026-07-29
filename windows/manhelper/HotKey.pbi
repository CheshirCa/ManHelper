DeclareModule HotKey
  #ID = $4D48
  Declare.i Register(WindowHandle.i, Modifiers.i, VirtualKey.i)
  Declare Unregister()
  Declare.i LastErrorCode()
EndDeclareModule

Module HotKey
  Global RegisteredWindow.i
  Global ErrorCode.i

  ; AddKeyboardShortcut() works only while an application window is active.
  ; RegisterHotKey is required for Ctrl+F1 while PuTTY/KiTTY owns focus.
  Procedure.i Register(WindowHandle.i, Modifiers.i, VirtualKey.i)
    If RegisteredWindow = WindowHandle And RegisteredWindow <> 0
      ProcedureReturn #True
    EndIf
    If RegisteredWindow
      UnregisterHotKey_(RegisteredWindow, #ID)
      RegisteredWindow = 0
    EndIf
    If RegisterHotKey_(WindowHandle, #ID, Modifiers, VirtualKey)
      RegisteredWindow = WindowHandle
      ErrorCode = 0
      ProcedureReturn #True
    EndIf
    ErrorCode = GetLastError_()
    ProcedureReturn #False
  EndProcedure

  Procedure Unregister()
    If RegisteredWindow
      UnregisterHotKey_(RegisteredWindow, #ID)
      RegisteredWindow = 0
    EndIf
  EndProcedure

  Procedure.i LastErrorCode()
    ProcedureReturn ErrorCode
  EndProcedure
EndModule
