DeclareModule Database
  Declare.i OpenReadOnly(Path.s)
  Declare Close()
  Declare.i IsOpen()
  Declare.i Query(Sql.s)
  Declare.i BindString(Index.i, Value.s)
  Declare.i NextRow()
  Declare FinishQuery()
  Declare.s ColumnString(Index.i)
  Declare.q ColumnQuad(Index.i)
  Declare.d ColumnDouble(Index.i)
  Declare.i Columns()
  Declare.s LastError()
  Declare.i QuerySingleString(Sql.s, *Value.String)
  Declare.i QuerySingleQuad(Sql.s, *Value.Quad)
  Declare.i TableExists(Name.s)
EndDeclareModule

Module Database
  #SQLITE_OK = 0
  #SQLITE_ROW = 100
  #SQLITE_OPEN_READONLY = 1
  #SQLITE_TRANSIENT = -1

  ; See PB-002/PB-003. OpenDatabase() cannot guarantee mode=ro here and the
  ; bundled SQLite has no FTS5, so this adapter uses the project SQLite build.
  ImportC #PB_Compiler_FilePath + "..\validator\vendor\sqlite\sqlite3.lib"
    sqlite3_open_v2(Filename.p-utf8, *Database, Flags.i, Vfs.i)
    sqlite3_close_v2(*Database)
    sqlite3_prepare_v2(*Database, Sql.p-utf8, SqlBytes.i, *Statement, *Tail)
    sqlite3_step(*Statement)
    sqlite3_finalize(*Statement)
    sqlite3_bind_text(*Statement, Index.i, Value.p-utf8, Bytes.i, Destructor.i)
    sqlite3_column_text(*Statement, Index.i)
    sqlite3_column_int64.q(*Statement, Index.i)
    sqlite3_column_double.d(*Statement, Index.i)
    sqlite3_column_count(*Statement)
    sqlite3_errmsg(*Database)
  EndImport

  Global Db.i
  Global Statement.i

  Procedure.i IsOpen()
    ProcedureReturn Bool(Db <> 0)
  EndProcedure

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

  Procedure.i OpenReadOnly(Path.s)
    Close()
    If FileSize(Path) < 0
      ProcedureReturn #False
    EndIf
    If sqlite3_open_v2(Path, @Db, #SQLITE_OPEN_READONLY, 0) <> #SQLITE_OK
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
    ProcedureReturn Bool(sqlite3_bind_text(Statement, Index + 1, Value, -1,
                                           #SQLITE_TRANSIENT) = #SQLITE_OK)
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
    If Statement
      *Value = sqlite3_column_text(Statement, Index)
      If *Value
        ProcedureReturn PeekS(*Value, -1, #PB_UTF8)
      EndIf
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.q ColumnQuad(Index.i)
    If Statement
      ProcedureReturn sqlite3_column_int64(Statement, Index)
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure.d ColumnDouble(Index.i)
    If Statement
      ProcedureReturn sqlite3_column_double(Statement, Index)
    EndIf
    ProcedureReturn 0.0
  EndProcedure

  Procedure.i Columns()
    If Statement
      ProcedureReturn sqlite3_column_count(Statement)
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure.i QuerySingleString(Sql.s, *Value.String)
    If Query(Sql) And NextRow()
      *Value\s = ColumnString(0)
      FinishQuery()
      ProcedureReturn #True
    EndIf
    FinishQuery()
    ProcedureReturn #False
  EndProcedure

  Procedure.i QuerySingleQuad(Sql.s, *Value.Quad)
    If Query(Sql) And NextRow()
      *Value\q = ColumnQuad(0)
      FinishQuery()
      ProcedureReturn #True
    EndIf
    FinishQuery()
    ProcedureReturn #False
  EndProcedure

  Procedure.i TableExists(Name.s)
    Protected Count.q
    If Query("SELECT COUNT(*) FROM sqlite_schema WHERE type='table' AND name=?")
      BindString(0, Name)
      If NextRow()
        Count = ColumnQuad(0)
      EndIf
      FinishQuery()
    EndIf
    ProcedureReturn Bool(Count > 0)
  EndProcedure
EndModule
