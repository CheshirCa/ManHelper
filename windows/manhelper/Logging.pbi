XIncludeFile "Utils.pbi"

DeclareModule Logging
  Declare Initialize()
  Declare Write(Level.s, Message.s)
EndDeclareModule

Module Logging
  Global LogPath.s

  Procedure Initialize()
    If FileSize(Utils::SettingsDirectory()) <> -2
      CreateDirectory(Utils::SettingsDirectory())
    EndIf
    LogPath = Utils::SettingsDirectory() + "manhelper.log"
  EndProcedure

  Procedure Write(Level.s, Message.s)
    Protected File.i
    If LogPath = ""
      ProcedureReturn
    EndIf
    File = OpenFile(#PB_Any, LogPath, #PB_File_Append | #PB_File_SharedRead)
    If File
      WriteStringN(File, FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date()) +
                         " [" + Level + "] " + Message, #PB_UTF8)
      CloseFile(File)
    EndIf
  EndProcedure
EndModule
