DeclareModule ValidatorLogging
  Declare SetLogFile(Path.s)
  Declare Write(Level.s, Message.s)
EndDeclareModule

Module ValidatorLogging
  Global LogPath.s

  Procedure SetLogFile(Path.s)
    LogPath = Path
  EndProcedure

  Procedure Write(Level.s, Message.s)
    Protected File.i
    If LogPath = ""
      ProcedureReturn
    EndIf
    File = OpenFile(#PB_Any, LogPath, #PB_File_Append | #PB_File_SharedRead)
    If File
      WriteStringN(File, FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date()) + " [" + Level + "] " + Message, #PB_UTF8)
      CloseFile(File)
    EndIf
  EndProcedure
EndModule
