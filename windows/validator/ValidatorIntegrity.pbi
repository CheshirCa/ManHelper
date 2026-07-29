XIncludeFile "ValidatorModels.pbi"
XIncludeFile "ValidatorDatabase.pbi"

DeclareModule ValidatorIntegrity
  Declare Validate(*Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorIntegrity
  Procedure AddIdsFromQuery(*Report.ValidatorModels::ValidationReport, Code.s, Message.s, Sql.s, Severity.i)
    Protected Count.i
    Protected Context.s
    If ValidatorDatabase::Query(Sql) = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, Code + "_QUERY", "Проверка не выполнена.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    While ValidatorDatabase::NextRow()
      Count + 1
      If Count <= 50
        If Context <> ""
          Context + ","
        EndIf
        Context + ValidatorDatabase::ColumnString(0)
      EndIf
    Wend
    ValidatorDatabase::FinishQuery()
    If Count > 0
      If Count > 50
        Context + ",…"
      EndIf
      ValidatorModels::AddIssue(*Report, Severity, Code, Message, "count=" + Str(Count) + "; ids=" + Context)
    EndIf
  EndProcedure

  Procedure CheckIntegrity(*Report.ValidatorModels::ValidationReport)
    Protected Result.s
    Protected Count.i
    If ValidatorDatabase::Query("PRAGMA integrity_check") = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "INTEGRITY_QUERY_FAILED", "PRAGMA integrity_check завершилась ошибкой.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    While ValidatorDatabase::NextRow()
      Result = ValidatorDatabase::ColumnString(0)
      If LCase(Result) <> "ok"
        Count + 1
        ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "INTEGRITY_FAILED", "SQLite integrity_check обнаружила повреждение.", Result)
      EndIf
    Wend
    ValidatorDatabase::FinishQuery()
  EndProcedure

  Procedure CheckForeignKeys(*Report.ValidatorModels::ValidationReport)
    Protected Count.i
    Protected Context.s
    If ValidatorDatabase::Query("PRAGMA foreign_key_check") = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FOREIGN_KEY_QUERY_FAILED", "PRAGMA foreign_key_check завершилась ошибкой.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    While ValidatorDatabase::NextRow()
      Count + 1
      If Count <= 50
        Context + ValidatorDatabase::ColumnString(0) + ":" + ValidatorDatabase::ColumnString(1) + " "
      EndIf
    Wend
    ValidatorDatabase::FinishQuery()
    If Count > 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FOREIGN_KEY_FAILED", "Нарушены внешние ключи.", "count=" + Str(Count) + "; rows=" + Context)
    EndIf
  EndProcedure

  Procedure CheckChecksum(*Report.ValidatorModels::ValidationReport)
    Protected Fingerprint.i
    Protected Line.s
    Protected *Utf8
    Protected Calculated.s
    Protected Expected.s

    If FindMapElement(*Report\Meta(), "content_checksum") = 0 Or *Report\Meta("content_checksum") = ""
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "CHECKSUM_MISSING", "В meta отсутствует content_checksum.")
      ProcedureReturn
    EndIf
    Expected = LCase(*Report\Meta("content_checksum"))

    UseSHA2Fingerprint()
    Fingerprint = StartFingerprint(#PB_Any, #PB_Cipher_SHA2, 256)
    If Fingerprint = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "CHECKSUM_INIT_FAILED", "Не удалось запустить SHA-256.")
      ProcedureReturn
    EndIf
    If ValidatorDatabase::Query("SELECT id, content_hash FROM pages ORDER BY id") = 0
      FinishFingerprint(Fingerprint)
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "CHECKSUM_QUERY_FAILED", "Не удалось прочитать данные для checksum.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    While ValidatorDatabase::NextRow()
      Line = ValidatorDatabase::ColumnString(0) + ":" + ValidatorDatabase::ColumnString(1) + #LF$
      *Utf8 = UTF8(Line)
      If *Utf8
        AddFingerprintBuffer(Fingerprint, *Utf8, MemorySize(*Utf8) - 1)
        FreeMemory(*Utf8)
      EndIf
    Wend
    ValidatorDatabase::FinishQuery()
    Calculated = LCase(FinishFingerprint(Fingerprint))
    If Calculated <> Expected
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "CHECKSUM_MISMATCH", "Контрольная сумма содержимого не совпадает.", "expected=" + Expected + ", actual=" + Calculated)
    EndIf
  EndProcedure

  Procedure Validate(*Report.ValidatorModels::ValidationReport)
    CheckIntegrity(*Report)
    CheckForeignKeys(*Report)
    AddIdsFromQuery(*Report, "DUPLICATE_PAGE", "Обнаружены дубликаты страниц.", "SELECT MIN(id) FROM pages GROUP BY profile_id,name,section,language,COALESCE(locale,'') HAVING COUNT(*)>1", ValidatorModels::#SeverityError)
    AddIdsFromQuery(*Report, "ORPHAN_SECTION", "Секции ссылаются на отсутствующие страницы.", "SELECT s.id FROM sections s LEFT JOIN pages p ON p.id=s.page_id WHERE p.id IS NULL", ValidatorModels::#SeverityError)
    AddIdsFromQuery(*Report, "ORPHAN_ALIAS", "Aliases ссылаются на отсутствующие страницы.", "SELECT a.id FROM aliases a LEFT JOIN pages p ON p.id=a.page_id WHERE p.id IS NULL", ValidatorModels::#SeverityError)
    AddIdsFromQuery(*Report, "ORPHAN_COMMAND_INFO", "command_info ссылается на отсутствующие страницы.", "SELECT c.id FROM command_info c LEFT JOIN pages p ON p.id=c.page_id WHERE p.id IS NULL", ValidatorModels::#SeverityError)
    AddIdsFromQuery(*Report, "ORPHAN_PAGE_PROFILE", "Страницы ссылаются на отсутствующий профиль.", "SELECT p.id FROM pages p LEFT JOIN profiles pr ON pr.id=p.profile_id WHERE pr.id IS NULL", ValidatorModels::#SeverityError)

    If FindMapElement(*Report\Meta(), "profile_id")
      If ValidatorDatabase::Query("SELECT COUNT(*) FROM profiles WHERE id=CAST(? AS INTEGER)")
        ValidatorDatabase::BindString(0, *Report\Meta("profile_id"))
        If ValidatorDatabase::NextRow()
          If ValidatorDatabase::ColumnQuad(0) = 0
            ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "PROFILE_MISSING", "Профиль из meta.profile_id отсутствует.", *Report\Meta("profile_id"))
          EndIf
        EndIf
        ValidatorDatabase::FinishQuery()
      EndIf
    EndIf
    CheckChecksum(*Report)
  EndProcedure
EndModule
