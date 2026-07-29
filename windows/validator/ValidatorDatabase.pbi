XIncludeFile "ValidatorModels.pbi"

DeclareModule ValidatorDatabase
  Declare.i OpenReadOnly(*Report.ValidatorModels::ValidationReport)
  Declare Close()
  Declare.i Query(Sql.s)
  Declare.i BindString(Index.i, Value.s)
  Declare.i NextRow()
  Declare FinishQuery()
  Declare.s ColumnString(Index.i)
  Declare.q ColumnQuad(Index.i)
  Declare.i Columns()
  Declare.s LastError()
  Declare.i QuerySingleString(Sql.s, *Value.String)
  Declare.i QuerySingleQuad(Sql.s, *Value.Quad)
  Declare.i TableExists(Name.s)
  Declare VerifyFileUnchanged(*Report.ValidatorModels::ValidationReport)
EndDeclareModule

Module ValidatorDatabase
  #SQLITE_OK = 0
  #SQLITE_ROW = 100
  #SQLITE_DONE = 101
  #SQLITE_OPEN_READONLY = 1
  #SQLITE_TRANSIENT = -1

  ; PureBasic OpenDatabase() was considered first. Its Windows SQLite wrapper
  ; does not expose sqlite3_open_v2 flags and rejected mode=ro URI filenames in
  ; the installed compiler. The bundled static SQLite library is therefore used
  ; only inside this module to guarantee an actual read-only connection.
  ImportC #PB_Compiler_FilePath + "vendor\sqlite\sqlite3.lib"
    sqlite3_open_v2(Filename.p-utf8, *Database, Flags.i, Vfs.i)
    sqlite3_close_v2(*Database)
    sqlite3_prepare_v2(*Database, Sql.p-utf8, SqlBytes.i, *Statement, *Tail)
    sqlite3_step(*Statement)
    sqlite3_finalize(*Statement)
    sqlite3_bind_text(*Statement, Index.i, Value.p-utf8, Bytes.i, Destructor.i)
    sqlite3_column_text(*Statement, Index.i)
    sqlite3_column_int64.q(*Statement, Index.i)
    sqlite3_column_count(*Statement)
    sqlite3_errmsg(*Database)
  EndImport

  Global Db.i
  Global Statement.i

  Procedure.s LastError()
    Protected *Message
    If Db
      *Message = sqlite3_errmsg(Db)
      If *Message
        ProcedureReturn PeekS(*Message, -1, #PB_UTF8)
      EndIf
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.i OpenReadOnly(*Report.ValidatorModels::ValidationReport)
    Protected Result.i
    *Report\FileSizeBefore = FileSize(*Report\DatabasePath)
    *Report\FileDateBefore = GetFileDate(*Report\DatabasePath, #PB_Date_Modified)
    If *Report\FileSizeBefore < 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "DB_FILE_MISSING", "Файл базы данных не найден.", *Report\DatabasePath)
      ProcedureReturn #False
    EndIf

    Result = sqlite3_open_v2(*Report\DatabasePath, @Db, #SQLITE_OPEN_READONLY, 0)
    If Result <> #SQLITE_OK Or Db = 0
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "DB_OPEN_FAILED", "Не удалось открыть SQLite-базу в режиме read-only.", LastError())
      Close()
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure Close()
    FinishQuery()
    If Db
      sqlite3_close_v2(Db)
    EndIf
    Db = 0
  EndProcedure

  Procedure.i Query(Sql.s)
    FinishQuery()
    If Db = 0
      ProcedureReturn #False
    EndIf
    If sqlite3_prepare_v2(Db, Sql, -1, @Statement, 0) <> #SQLITE_OK
      Statement = 0
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i BindString(Index.i, Value.s)
    If Statement = 0
      ProcedureReturn #False
    EndIf
    ProcedureReturn Bool(sqlite3_bind_text(Statement, Index + 1, Value, -1, #SQLITE_TRANSIENT) = #SQLITE_OK)
  EndProcedure

  Procedure.i NextRow()
    If Statement And sqlite3_step(Statement) = #SQLITE_ROW
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure FinishQuery()
    If Statement
      sqlite3_finalize(Statement)
      Statement = 0
    EndIf
  EndProcedure

  Procedure.s ColumnString(Index.i)
    Protected *Value
    If Statement = 0
      ProcedureReturn ""
    EndIf
    *Value = sqlite3_column_text(Statement, Index)
    If *Value
      ProcedureReturn PeekS(*Value, -1, #PB_UTF8)
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.q ColumnQuad(Index.i)
    If Statement
      ProcedureReturn sqlite3_column_int64(Statement, Index)
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure.i Columns()
    If Statement
      ProcedureReturn sqlite3_column_count(Statement)
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure.i QuerySingleString(Sql.s, *Value.String)
    If Query(Sql) = 0
      ProcedureReturn #False
    EndIf
    If NextRow()
      *Value\s = ColumnString(0)
      FinishQuery()
      ProcedureReturn #True
    EndIf
    FinishQuery()
    ProcedureReturn #False
  EndProcedure

  Procedure.i QuerySingleQuad(Sql.s, *Value.Quad)
    If Query(Sql) = 0
      ProcedureReturn #False
    EndIf
    If NextRow()
      *Value\q = ColumnQuad(0)
      FinishQuery()
      ProcedureReturn #True
    EndIf
    FinishQuery()
    ProcedureReturn #False
  EndProcedure

  Procedure.i TableExists(Name.s)
    Protected Found.q
    If Query("SELECT COUNT(*) FROM sqlite_schema WHERE type='table' AND name=?")
      BindString(0, Name)
      If NextRow()
        Found = ColumnQuad(0)
      EndIf
      FinishQuery()
    EndIf
    ProcedureReturn Bool(Found > 0)
  EndProcedure

  Procedure VerifyFileUnchanged(*Report.ValidatorModels::ValidationReport)
    *Report\FileSizeAfter = FileSize(*Report\DatabasePath)
    *Report\FileDateAfter = GetFileDate(*Report\DatabasePath, #PB_Date_Modified)
    If *Report\FileSizeAfter <> *Report\FileSizeBefore Or *Report\FileDateAfter <> *Report\FileDateBefore
      ValidatorModels::AddIssue(*Report, ValidatorModels::#SeverityError, "DB_FILE_CHANGED", "Файл базы изменился во время проверки.", *Report\DatabasePath)
    EndIf
  EndProcedure
EndModule
