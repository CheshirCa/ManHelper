XIncludeFile "Models.pbi"

DeclareModule WindowDetect
  Declare.s ExecutablePathForProcessId(ProcessId.i)
  Declare.i IsSupportedProcess(ExecutableName.s, SupportedProcesses.s)
  Declare GetForegroundTerminal(*Terminal.Models::TerminalWindow, SupportedProcesses.s)
EndDeclareModule

Module WindowDetect
  #PROCESS_QUERY_LIMITED_INFORMATION = $1000

  ; PureBasic has no standard command that returns the executable backing the
  ; foreground window. The small WinAPI adapter is isolated in this module.
  Procedure.s ExecutablePathForProcessId(ProcessId.i)
    Protected ProcessHandle.i
    Protected Kernel.i
    Protected Capacity.i = 32767
    Protected Path.s = Space(Capacity)
    ProcessHandle = OpenProcess_(#PROCESS_QUERY_LIMITED_INFORMATION, #False, ProcessId)
    If ProcessHandle = 0
      ProcedureReturn ""
    EndIf
    Kernel = OpenLibrary(#PB_Any, "kernel32.dll")
    If Kernel = 0 Or
       CallFunction(Kernel, "QueryFullProcessImageNameW",
                    ProcessHandle, 0, @Path, @Capacity) = 0
      Path = ""
    Else
      Path = Left(Path, Capacity)
    EndIf
    If Kernel
      CloseLibrary(Kernel)
    EndIf
    CloseHandle_(ProcessHandle)
    ProcedureReturn Path
  EndProcedure

  Procedure.i IsSupportedProcess(ExecutableName.s, SupportedProcesses.s)
    Protected Index.i
    Protected Candidate.s
    ExecutableName = LCase(Trim(ExecutableName))
    For Index = 1 To CountString(SupportedProcesses, ",") + 1
      Candidate = LCase(Trim(StringField(SupportedProcesses, Index, ",")))
      If Candidate <> "" And Candidate = ExecutableName
        ProcedureReturn #True
      EndIf
    Next
    ProcedureReturn #False
  EndProcedure

  Procedure GetForegroundTerminal(*Terminal.Models::TerminalWindow, SupportedProcesses.s)
    ClearStructure(*Terminal, Models::TerminalWindow)
    *Terminal\WindowHandle = GetForegroundWindow_()
    If *Terminal\WindowHandle = 0
      ProcedureReturn
    EndIf
    GetWindowThreadProcessId_(*Terminal\WindowHandle, @*Terminal\ProcessId)
    If *Terminal\ProcessId = 0
      ProcedureReturn
    EndIf
    *Terminal\ExecutablePath = ExecutablePathForProcessId(*Terminal\ProcessId)
    *Terminal\ExecutableName = LCase(GetFilePart(*Terminal\ExecutablePath))
    *Terminal\IsSupported = IsSupportedProcess(*Terminal\ExecutableName, SupportedProcesses)
  EndProcedure
EndModule
