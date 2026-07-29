DeclareModule PopupPosition
  Structure Position
    X.i
    Y.i
  EndStructure
  Declare Calculate(*Position.Position, AnchorWindow.i, Width.i, Height.i)
EndDeclareModule

Module PopupPosition
  #MONITOR_DEFAULTTONEAREST = 2

  ; DesktopX()/DesktopWidth() were considered, but they expose the monitor
  ; bounds rather than the working rectangle that excludes the taskbar.
  Procedure Calculate(*Position.Position, AnchorWindow.i, Width.i, Height.i)
    Protected Monitor.i
    Protected Info.MONITORINFO
    Protected CursorX.i = DesktopMouseX()
    Protected CursorY.i = DesktopMouseY()
    Protected WorkLeft.i
    Protected WorkTop.i
    Protected WorkRight.i
    Protected WorkBottom.i

    Monitor = MonitorFromWindow_(AnchorWindow, #MONITOR_DEFAULTTONEAREST)
    Info\cbSize = SizeOf(MONITORINFO)
    If Monitor And GetMonitorInfo_(Monitor, @Info)
      WorkLeft = Info\rcWork\left
      WorkTop = Info\rcWork\top
      WorkRight = Info\rcWork\right
      WorkBottom = Info\rcWork\bottom
    Else
      ExamineDesktops()
      WorkLeft = DesktopX(0)
      WorkTop = DesktopY(0)
      WorkRight = WorkLeft + DesktopWidth(0)
      WorkBottom = WorkTop + DesktopHeight(0)
    EndIf

    *Position\X = CursorX + 18
    *Position\Y = CursorY + 22
    If *Position\X + Width > WorkRight
      *Position\X = WorkRight - Width
    EndIf
    If *Position\Y + Height > WorkBottom
      *Position\Y = WorkBottom - Height
    EndIf
    If *Position\X < WorkLeft
      *Position\X = WorkLeft
    EndIf
    If *Position\Y < WorkTop
      *Position\Y = WorkTop
    EndIf
  EndProcedure
EndModule
