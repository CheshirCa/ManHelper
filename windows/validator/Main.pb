EnableExplicit

XIncludeFile "Version.pbi"
XIncludeFile "ValidatorModels.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "Utils.pbi"
XIncludeFile "Logging.pbi"
XIncludeFile "ValidatorAppState.pbi"
XIncludeFile "ValidatorCli.pbi"
XIncludeFile "ValidatorDatabase.pbi"
XIncludeFile "ValidatorSchema.pbi"
XIncludeFile "ValidatorIntegrity.pbi"
XIncludeFile "ValidatorEncoding.pbi"
XIncludeFile "ValidatorContent.pbi"
XIncludeFile "ValidatorFts.pbi"
XIncludeFile "ValidatorReport.pbi"
XIncludeFile "ValidatorRunner.pbi"

UseModule ValidatorAppState

OpenConsole("ManBase Validator")

Define Error.String
Define Output.s
Define ExitCode.i

If ValidatorCli::Parse(@Options, @Error) = #False
  ConsoleError(Error\s)
  ValidatorCli::PrintUsage()
  End 64
EndIf

If Options\ShowHelp
  ValidatorCli::PrintUsage()
  End 0
EndIf

If Options\ShowVersion
  PrintN("ManBase Validator " + ValidatorVersion::#CLIENT_VERSION)
  End 0
EndIf

ExitCode = ValidatorRunner::Run(Options\DatabasePath, @Report)

If Options\Format = "json"
  Output = ValidatorReport::AsJson(@Report)
Else
  Output = ValidatorReport::AsText(@Report)
EndIf
PrintN(Output)

If ValidatorReport::Save(@Report, Options\ReportPath, Options\Format) = #False
  ConsoleError("Не удалось записать отчёт: " + Options\ReportPath)
  End 74
EndIf

End ExitCode
