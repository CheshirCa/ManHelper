XIncludeFile "ValidatorModels.pbi"
XIncludeFile "ValidatorDatabase.pbi"

DeclareModule ValidatorFts
  Declare Validate(*Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorFts
  Procedure.q FtsCount(Query.s, *Ok.Integer)
    Protected Count.q
    *Ok\i = #False
    If ValidatorDatabase::Query("SELECT COUNT(*) FROM page_fts WHERE page_fts MATCH ?")
      ValidatorDatabase::BindString(0, Query)
      If ValidatorDatabase::NextRow()
        Count = ValidatorDatabase::ColumnQuad(0)
        *Ok\i = #True
      EndIf
      ValidatorDatabase::FinishQuery()
    EndIf
    ProcedureReturn Count
  EndProcedure

  Procedure Validate(*Report.ValidatorModels::ValidationReport)
    Protected Value.q
    Protected Ok.i
    Protected English.q
    Protected Orphans.q
    Protected Cyrillic.q

    If ValidatorDatabase::TableExists("page_fts") = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_MISSING", "FTS5-таблица page_fts отсутствует.")
      ProcedureReturn
    EndIf
    If ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM page_fts", @Value) = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_READ_FAILED", "Не удалось прочитать FTS5-индекс.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    *Report\FtsCount = Value
    If Value = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_EMPTY", "FTS5-индекс пуст.")
    EndIf

    English = FtsCount("systemctl", @Ok)
    If Ok = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_QUERY_FAILED", "FTS5-запрос завершился ошибкой.", ValidatorDatabase::LastError())
    ElseIf English = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityWarning, "FTS_SYSTEMCTL_NOT_FOUND", "Контрольный FTS-поиск systemctl не дал результатов.")
    EndIf

    If ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM page_fts f LEFT JOIN pages p ON p.id=f.page_id WHERE p.id IS NULL", @Orphans)
      If Orphans > 0
        ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_ORPHAN_ROWS", "FTS5 содержит ссылки на отсутствующие страницы.", "count=" + Str(Orphans))
      EndIf
    EndIf
    If *Report\FtsCount <> *Report\PagesCount
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_COUNT_MISMATCH", "Количество FTS-записей не совпадает с pages.", "pages=" + Str(*Report\PagesCount) + ", fts=" + Str(*Report\FtsCount))
    EndIf

    ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM pages WHERE COALESCE(plain_text,'') GLOB '*[А-Яа-яЁё]*'", @Cyrillic)
    If Cyrillic > 0
      ; A known literal verifies Unicode parameter transport even if this particular
      ; database has only character-table Cyrillic and no Russian prose.
      FtsCount("кириллица", @Ok)
      If Ok = #False
        ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "FTS_UNICODE_QUERY_FAILED", "Unicode FTS5-запрос завершился ошибкой.", ValidatorDatabase::LastError())
      Else
        ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityInfo, "FTS_UNICODE_QUERY_OK", "Unicode FTS5-запрос выполнен.")
      EndIf
    EndIf
  EndProcedure
EndModule
