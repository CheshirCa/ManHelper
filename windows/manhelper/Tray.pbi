XIncludeFile "Localization.pbi"

UsePNGImageDecoder()

DeclareModule Tray
  #MenuShow = 1
  #MenuExit = 2
  #MenuLibrary = 3
  #MenuSettings = 4
  Declare.i Initialize(Window.i, HotKeyDisplay.s)
  Declare.i IsReady()
  Declare Shutdown()
EndDeclareModule

Module Tray
  #Icon = 0
  #Image = 0
  #Menu = 0

  Procedure.i Initialize(Window.i, HotKeyDisplay.s)
    Shutdown()
    If CatchImage(#Image, ?TrayIconStart, ?TrayIconEnd - ?TrayIconStart) = 0
      ProcedureReturn #False
    EndIf
    If AddSysTrayIcon(#Icon, WindowID(Window), ImageID(#Image)) = 0
      FreeImage(#Image)
      ProcedureReturn #False
    EndIf
    SysTrayIconToolTip(#Icon, Localization::Text("tray_tooltip") + HotKeyDisplay)
    If CreatePopupMenu(#Menu)
      MenuItem(#MenuShow, Localization::Text("tray_show"))
      MenuItem(#MenuLibrary, Localization::Text("tray_library"))
      MenuItem(#MenuSettings, Localization::Text("tray_settings"))
      MenuBar()
      MenuItem(#MenuExit, Localization::Text("tray_exit"))
      SysTrayIconMenu(#Icon, MenuID(#Menu))
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i IsReady()
    ProcedureReturn Bool(IsSysTrayIcon(#Icon))
  EndProcedure

  Procedure Shutdown()
    If IsSysTrayIcon(#Icon)
      RemoveSysTrayIcon(#Icon)
    EndIf
    If IsMenu(#Menu)
      FreeMenu(#Menu)
    EndIf
    If IsImage(#Image)
      FreeImage(#Image)
    EndIf
  EndProcedure

  DataSection
    TrayIconStart:
    IncludeBinary "assets\manhelper-tray.png"
    TrayIconEnd:
  EndDataSection
EndModule
