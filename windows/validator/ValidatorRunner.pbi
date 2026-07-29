XIncludeFile "Version.pbi"
XIncludeFile "ValidatorModels.pbi"
XIncludeFile "Utils.pbi"
XIncludeFile "ValidatorDatabase.pbi"
XIncludeFile "ValidatorSchema.pbi"
XIncludeFile "ValidatorIntegrity.pbi"
XIncludeFile "ValidatorEncoding.pbi"
XIncludeFile "ValidatorContent.pbi"
XIncludeFile "ValidatorFts.pbi"

DeclareModule ValidatorRunner
  Declare.i Run(DatabasePath.s, *Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorRunner
  Procedure.i Run(DatabasePath.s, *Report.ValidatorModels::ValidationReport)
    ValidatorModels::InitReport(*Report, DatabasePath, ValidatorVersion::#CLIENT_VERSION)

    If ValidatorDatabase::OpenReadOnly(*Report)
      ValidatorSchema::Validate(*Report)

      ; Deeper checks require the core schema. Missing tables are already
      ; represented by schema issues and must not crash later checks.
      If ValidatorDatabase::TableExists("pages") And ValidatorDatabase::TableExists("profiles")
        ValidatorIntegrity::Validate(*Report)
        ValidatorEncoding::Validate(*Report)
        ValidatorContent::Validate(*Report)
        ValidatorFts::Validate(*Report)
      EndIf
      ValidatorDatabase::Close()
    EndIf

    ValidatorDatabase::VerifyFileUnchanged(*Report)
    *Report\CompletedAt = ValidatorUtils::IsoTimestamp()
    *Report\Status = ValidatorModels::CalculateStatus(*Report)
    ProcedureReturn ValidatorModels::ExitCodeForStatus(*Report\Status)
  EndProcedure
EndModule
