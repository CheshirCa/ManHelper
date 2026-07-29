XIncludeFile "ValidatorModels.pbi"
XIncludeFile "ValidatorDatabase.pbi"
XIncludeFile "Version.pbi"
XIncludeFile "Utils.pbi"

DeclareModule ValidatorSchema
  Declare Validate(*Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorSchema
  Procedure LoadMeta(*Report.ValidatorModels::ValidationReport)
    If ValidatorDatabase::Query("SELECT key, value FROM meta ORDER BY key") = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "META_READ_FAILED", "Не удалось прочитать таблицу meta.", ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf
    While ValidatorDatabase::NextRow()
      *Report\Meta(ValidatorDatabase::ColumnString(0)) = ValidatorDatabase::ColumnString(1)
    Wend
    ValidatorDatabase::FinishQuery()
  EndProcedure

  Procedure CheckMeta(*Report.ValidatorModels::ValidationReport, Key.s, Expected.s, Incompatible.i = #True)
    Protected Severity.i = ValidatorModels::#SeverityError
    If FindMapElement(*Report\Meta(), Key) = 0
      ValidatorModels::AddIssue(*Report, Severity, "META_MISSING", "В meta отсутствует обязательный ключ.", Key)
      ProcedureReturn
    EndIf
    If *Report\Meta(Key) <> Expected
      If Incompatible
        Severity = ValidatorModels::#SeverityIncompatible
      EndIf
      ValidatorModels::AddIssue(*Report, Severity, "META_VALUE_UNSUPPORTED", "Неподдерживаемое значение meta." , Key + "=" + *Report\Meta(Key) + ", expected=" + Expected)
    EndIf
  EndProcedure

  Procedure CheckColumn(*Report.ValidatorModels::ValidationReport, TableName.s, ColumnName.s, ColumnType.s)
    Protected Found.i
    Protected ActualType.s
    If ValidatorDatabase::Query("PRAGMA table_info(" + TableName + ")")
      While ValidatorDatabase::NextRow()
        If LCase(ValidatorDatabase::ColumnString(1)) = LCase(ColumnName)
          Found = #True
          ActualType = UCase(ValidatorDatabase::ColumnString(2))
          Break
        EndIf
      Wend
      ValidatorDatabase::FinishQuery()
    Else
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "SCHEMA_PRAGMA_FAILED", "Не удалось прочитать описание таблицы.", TableName + ": " + ValidatorDatabase::LastError())
      ProcedureReturn
    EndIf

    If Found = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "SCHEMA_COLUMN_MISSING", "Отсутствует обязательное поле.", TableName + "." + ColumnName)
    ElseIf ColumnType <> "" And ActualType <> UCase(ColumnType)
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "SCHEMA_COLUMN_TYPE", "Поле имеет неверный тип.", TableName + "." + ColumnName + "=" + ActualType + ", expected=" + ColumnType)
    EndIf
  EndProcedure

  Procedure CheckTable(*Report.ValidatorModels::ValidationReport, TableName.s)
    If ValidatorDatabase::TableExists(TableName) = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "SCHEMA_TABLE_MISSING", "Отсутствует обязательная таблица.", TableName)
    EndIf
  EndProcedure

  Procedure CheckIndex(*Report.ValidatorModels::ValidationReport, IndexName.s)
    Protected Value.q
    If ValidatorDatabase::Query("SELECT COUNT(*) FROM sqlite_schema WHERE type='index' AND name=?")
      ValidatorDatabase::BindString(0, IndexName)
      If ValidatorDatabase::NextRow()
        Value = ValidatorDatabase::ColumnQuad(0)
      EndIf
      ValidatorDatabase::FinishQuery()
    EndIf
    If Value = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "SCHEMA_INDEX_MISSING", "Отсутствует обязательный индекс.", IndexName)
    EndIf
  EndProcedure

  Procedure Validate(*Report.ValidatorModels::ValidationReport)
    Protected MinimumClient.s
    Protected SchemaVersion.i

    If ValidatorDatabase::TableExists("meta") = #False
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "SCHEMA_TABLE_MISSING", "Отсутствует обязательная таблица.", "meta")
      ProcedureReturn
    EndIf

    LoadMeta(*Report)
    CheckMeta(*Report, "database_format", Str(ValidatorVersion::#SUPPORTED_DATABASE_FORMAT))
    CheckMeta(*Report, "schema_version", Str(ValidatorVersion::#SUPPORTED_SCHEMA_VERSION))
    CheckMeta(*Report, "text_encoding", "UTF-8", #False)
    CheckMeta(*Report, "unicode_normalization", "NFC", #False)
    CheckMeta(*Report, "fts_version", "FTS5 unicode61")

    If FindMapElement(*Report\Meta(), "minimum_client_version")
      MinimumClient = *Report\Meta("minimum_client_version")
      If ValidatorUtils::CompareVersions(MinimumClient, ValidatorVersion::#CLIENT_VERSION) > 0
        ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityIncompatible, "CLIENT_TOO_OLD", "Для базы требуется более новая версия клиента.", "required=" + MinimumClient + ", current=" + ValidatorVersion::#CLIENT_VERSION)
      EndIf
    Else
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "META_MISSING", "В meta отсутствует обязательный ключ.", "minimum_client_version")
    EndIf

    CheckTable(*Report, "profiles")
    CheckTable(*Report, "packages")
    CheckTable(*Report, "pages")
    CheckTable(*Report, "sections")
    CheckTable(*Report, "aliases")
    CheckTable(*Report, "relations")
    CheckTable(*Report, "command_info")
    CheckTable(*Report, "build_errors")
    CheckTable(*Report, "page_fts")

    CheckColumn(*Report, "meta", "key", "TEXT")
    CheckColumn(*Report, "meta", "value", "TEXT")
    CheckColumn(*Report, "profiles", "id", "INTEGER")
    CheckColumn(*Report, "profiles", "profile_name", "TEXT")
    CheckColumn(*Report, "profiles", "created_at", "TEXT")
    CheckColumn(*Report, "profiles", "builder_version", "TEXT")
    CheckColumn(*Report, "pages", "id", "INTEGER")
    CheckColumn(*Report, "pages", "profile_id", "INTEGER")
    CheckColumn(*Report, "pages", "name", "TEXT")
    CheckColumn(*Report, "pages", "section", "TEXT")
    CheckColumn(*Report, "pages", "language", "TEXT")
    CheckColumn(*Report, "pages", "locale", "TEXT")
    CheckColumn(*Report, "pages", "decode_status", "TEXT")
    CheckColumn(*Report, "pages", "plain_text", "TEXT")
    CheckColumn(*Report, "pages", "roff_content", "TEXT")
    CheckColumn(*Report, "pages", "content_hash", "TEXT")
    CheckColumn(*Report, "sections", "page_id", "INTEGER")
    CheckColumn(*Report, "sections", "section_order", "INTEGER")
    CheckColumn(*Report, "sections", "normalized_name", "TEXT")
    CheckColumn(*Report, "sections", "content", "TEXT")
    CheckColumn(*Report, "aliases", "page_id", "INTEGER")
    CheckColumn(*Report, "aliases", "alias", "TEXT")
    CheckColumn(*Report, "command_info", "page_id", "INTEGER")
    CheckColumn(*Report, "relations", "source_page_id", "INTEGER")

    CheckIndex(*Report, "pages_identity_idx")
    CheckIndex(*Report, "packages_identity_idx")
  EndProcedure
EndModule
