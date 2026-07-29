XIncludeFile "ValidatorModels.pbi"

DeclareModule ValidatorAppState
  Structure CliOptions
    DatabasePath.s
    ReportPath.s
    Format.s
    ShowHelp.i
    ShowVersion.i
  EndStructure

  Global Options.CliOptions
  Global Report.ValidatorModels::ValidationReport
  Global DatabaseHandle.i
EndDeclareModule

Module ValidatorAppState
  Global Options.CliOptions
  Global Report.ValidatorModels::ValidationReport
  Global DatabaseHandle.i = -1
EndModule
