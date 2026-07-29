XIncludeFile "ValidatorModels.pbi"
XIncludeFile "ValidatorDatabase.pbi"

DeclareModule ValidatorContent
  Declare Validate(*Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorContent
  Procedure CheckIds(*Report.ValidatorModels::ValidationReport, Code.s, Message.s, Sql.s, Severity.i)
    Protected Count.i
    Protected Context.s
    If ValidatorDatabase::Query(Sql) = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, Code + "_QUERY", "Проверка содержимого не выполнена.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    While ValidatorDatabase::NextRow()
      Count + 1
      If Count <= 30
        If Context <> ""
          Context + ", "
        EndIf
        Context + ValidatorDatabase::ColumnString(0)
        If ValidatorDatabase::Columns() > 1
          Context + ":" + ValidatorDatabase::ColumnString(1)
        EndIf
      EndIf
    Wend
    ValidatorDatabase::FinishQuery()
    If Count > 0
      ValidatorModels::AddIssue(*Report, Severity, Code, Message, "count=" + Str(Count) + "; pages=" + Context)
    EndIf
  EndProcedure

  Procedure Validate(*Report.ValidatorModels::ValidationReport)
    Protected Value.q
    ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM pages", @Value)
    *Report\PagesCount = Value
    ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM sections", @Value)
    *Report\SectionsCount = Value
    ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM aliases", @Value)
    *Report\AliasesCount = Value

    If *Report\PagesCount = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "PAGES_EMPTY", "Таблица pages пуста.")
    EndIf

    CheckIds(*Report, "PAGE_REQUIRED_FIELD_EMPTY", "У страницы пустое обязательное поле.", "SELECT id,name FROM pages WHERE trim(name)='' OR trim(section)='' OR trim(language)='' OR trim(decode_status)='' OR trim(content_hash)=''", ValidatorModels::#SeverityError)
    CheckIds(*Report, "PAGE_TEXT_EMPTY", "У страницы отсутствуют и plain_text, и roff_content.", "SELECT id,name FROM pages WHERE COALESCE(trim(plain_text),'')='' AND COALESCE(trim(roff_content),'')=''", ValidatorModels::#SeverityError)
    CheckIds(*Report, "PAGE_TOO_LARGE", "Размер страницы превышает разумный предел 16 MiB.", "SELECT id,name FROM pages WHERE length(COALESCE(plain_text,''))+length(COALESCE(roff_content,''))>16777216", ValidatorModels::#SeverityWarning)
    CheckIds(*Report, "SYNOPSIS_MISSING", "У страницы отсутствует секция SYNOPSIS.", "SELECT p.id,p.name FROM pages p WHERE NOT EXISTS(SELECT 1 FROM sections s WHERE s.page_id=p.id AND s.normalized_name='SYNOPSIS')", ValidatorModels::#SeverityWarning)
    CheckIds(*Report, "DECODE_STATUS_UNKNOWN", "Неизвестный decode_status.", "SELECT id,name FROM pages WHERE decode_status NOT IN ('exact','fallback','replaced')", ValidatorModels::#SeverityError)
    CheckIds(*Report, "DECODE_FALLBACK", "Некоторые страницы декодированы с fallback.", "SELECT id,name FROM pages WHERE decode_status='fallback'", ValidatorModels::#SeverityWarning)
    CheckIds(*Report, "SECTION_ORDER_INVALID", "Нарушен порядок или уникальность sections.", "SELECT MIN(s.id),p.name FROM sections s JOIN pages p ON p.id=s.page_id GROUP BY s.page_id,s.section_order HAVING COUNT(*)>1 OR s.section_order<0", ValidatorModels::#SeverityError)
    CheckIds(*Report, "ALIAS_FIELD_EMPTY", "У alias отсутствует обязательное значение.", "SELECT a.id,p.name FROM aliases a JOIN pages p ON p.id=a.page_id WHERE trim(a.alias)='' OR trim(a.alias_type)=''", ValidatorModels::#SeverityError)

    ValidatorDatabase::QuerySingleQuad("SELECT COUNT(*) FROM build_errors", @Value)
    If Value > 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityWarning, "BUILD_ERRORS_PRESENT", "База содержит локальные ошибки импорта.", "count=" + Str(Value))
    EndIf
  EndProcedure
EndModule
