EnableExplicit
XIncludeFile "..\Utils.pbi"
XIncludeFile "..\ValidatorModels.pbi"

OpenConsole("Validator unit tests")
Define Failures.i
Define Report.ValidatorModels::ValidationReport

Macro AssertEqual(Actual, Expected, Name)
  If (Actual) <> (Expected)
    PrintN("FAIL " + Name)
    Failures + 1
  Else
    PrintN("PASS " + Name)
  EndIf
EndMacro

AssertEqual(ValidatorUtils::CompareVersions("0.1.0", "0.1.0"), 0, "same version")
AssertEqual(ValidatorUtils::CompareVersions("0.2.0", "0.1.9"), 1, "newer version")
AssertEqual(ValidatorUtils::CompareVersions("0.1.0", "1.0.0"), -1, "older version")
AssertEqual(ValidatorUtils::IsSafeInteger("123"), #True, "safe integer")
AssertEqual(ValidatorUtils::IsSafeInteger("1x"), #False, "unsafe integer")

ValidatorModels::InitReport(@Report, "test.sqlite", "0.1.0")
AssertEqual(ValidatorModels::CalculateStatus(@Report), "VALID", "valid status")
ValidatorModels::AddIssue(@Report, ValidatorModels::#SeverityWarning, "W", "warning")
AssertEqual(ValidatorModels::CalculateStatus(@Report), "VALID_WITH_WARNINGS", "warning status")
ValidatorModels::AddIssue(@Report, ValidatorModels::#SeverityError, "E", "error")
AssertEqual(ValidatorModels::CalculateStatus(@Report), "INVALID", "invalid status")
ValidatorModels::AddIssue(@Report, ValidatorModels::#SeverityIncompatible, "I", "incompatible")
AssertEqual(ValidatorModels::CalculateStatus(@Report), "INCOMPATIBLE", "incompatible status")

End Failures
