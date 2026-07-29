XIncludeFile "ValidatorModels.pbi"
XIncludeFile "ValidatorDatabase.pbi"

DeclareModule ValidatorEncoding
  Declare Validate(*Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorEncoding
  Procedure.q Scalar(Sql.s, *Ok.Integer = 0)
    Protected Value.q
    Protected Result.i = ValidatorDatabase::QuerySingleQuad(Sql, @Value)
    If *Ok
      *Ok\i = Result
    EndIf
    ProcedureReturn Value
  EndProcedure

  Procedure CheckCount(*Report.ValidatorModels::ValidationReport, Code.s, Message.s, Sql.s, Severity.i)
    Protected Ok.i
    Protected Count.q = Scalar(Sql, @Ok)
    If Ok = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, Code + "_QUERY", "Проверка кодировки не выполнена.", ValidatorDatabase::LastError())
    ElseIf Count > 0
      ValidatorModels::AddIssue(*Report, Severity, Code, Message, "count=" + Str(Count))
    EndIf
  EndProcedure

  Procedure Validate(*Report.ValidatorModels::ValidationReport)
    Protected PageText.s = "COALESCE(name,'')||COALESCE(title,'')||COALESCE(summary,'')||COALESCE(plain_text,'')||COALESCE(roff_content,'')"
    Protected SectionText.s = "COALESCE(original_name,'')||COALESCE(normalized_name,'')||COALESCE(content,'')"
    Protected Cyrillic.q
    Protected Index.i
    Protected ControlExpression.s

    If FindMapElement(*Report\Meta(), "text_encoding") = 0 Or *Report\Meta("text_encoding") <> "UTF-8"
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "ENCODING_META", "meta.text_encoding должен быть UTF-8.")
    EndIf
    If FindMapElement(*Report\Meta(), "unicode_normalization") = 0 Or *Report\Meta("unicode_normalization") <> "NFC"
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "NORMALIZATION_META", "meta.unicode_normalization должен быть NFC.")
    EndIf

    CheckCount(*Report, "NUL_FOUND", "В текстовых данных найден U+0000.", "SELECT COUNT(*) FROM pages WHERE instr(" + PageText + ",char(0))>0", ValidatorModels::#SeverityError)
    CheckCount(*Report, "REPLACEMENT_CHAR_FOUND", "В текстовых данных найден U+FFFD.", "SELECT COUNT(*) FROM pages WHERE contains_replacement_chars<>0 OR instr(" + PageText + ",char(65533))>0", ValidatorModels::#SeverityError)

    For Index = 1 To 31
      If Index <> 9 And Index <> 10 And Index <> 13
        If ControlExpression <> ""
          ControlExpression + " OR "
        EndIf
        ControlExpression + "instr(" + PageText + ",char(" + Str(Index) + "))>0"
      EndIf
    Next
    CheckCount(*Report, "CONTROL_CHAR_FOUND", "Найдены подозрительные управляющие символы.", "SELECT COUNT(*) FROM pages WHERE " + ControlExpression, ValidatorModels::#SeverityWarning)

    CheckCount(*Report, "MOJIBAKE_SUSPECTED", "Найдены признаки mojibake; требуется ручная проверка.", "SELECT COUNT(*) FROM pages WHERE " + PageText + " LIKE '%РЎ%' OR " + PageText + " LIKE '%Ð%'", ValidatorModels::#SeverityWarning)
    CheckCount(*Report, "QUESTION_MARK_RUN", "Найдены серии из четырёх и более вопросительных знаков.", "SELECT COUNT(*) FROM pages WHERE instr(" + PageText + ",'????')>0", ValidatorModels::#SeverityWarning)
    CheckCount(*Report, "DECOMPOSED_UNICODE", "Найдены комбинируемые Unicode-символы; возможен не-NFC текст.", "SELECT COUNT(*) FROM pages WHERE instr(" + PageText + ",char(768))>0 OR instr(" + PageText + ",char(769))>0 OR instr(" + PageText + ",char(776))>0 OR instr(" + PageText + ",char(774))>0", ValidatorModels::#SeverityWarning)

    Cyrillic = Scalar("SELECT COUNT(*) FROM pages WHERE " + PageText + " GLOB '*[А-Яа-яЁё]*'")
    ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityInfo, "CYRILLIC_STATISTICS", "Страницы с кириллическими символами.", "count=" + Str(Cyrillic))
  EndProcedure
EndModule
