DeclareModule UserDatabase
  #SCHEMA_VERSION = 1
  Declare.i Initialize(Path.s)
  Declare Close()
  Declare.i IsOpen()
  Declare.s LastError()
  Declare.s LastBackupPath()
  Declare.i Query(Sql.s)
  Declare.i Execute(Sql.s)
  Declare.i ExecutePrepared()
  Declare.i BindString(Index.i, Value.s)
  Declare.i NextRow()
  Declare FinishQuery()
  Declare.s ColumnString(Index.i)
  Declare.q ColumnQuad(Index.i)
  Declare.i Changes()
EndDeclareModule

Module UserDatabase
  #SQLITE_OK = 0
  #SQLITE_ROW = 100
  #SQLITE_DONE = 101
  #SQLITE_OPEN_READWRITE = 2
  #SQLITE_OPEN_CREATE = 4
  #SQLITE_TRANSIENT = -1

  ImportC #PB_Compiler_FilePath + "..\validator\vendor\sqlite\sqlite3.lib"
    sqlite3_open_v2(Filename.p-utf8, *Database, Flags.i, Vfs.i)
    sqlite3_close_v2(*Database)
    sqlite3_prepare_v2(*Database, Sql.p-utf8, SqlBytes.i, *Statement, *Tail)
    sqlite3_step(*Statement)
    sqlite3_finalize(*Statement)
    sqlite3_bind_text(*Statement, Index.i, Value.p-utf8, Bytes.i, Destructor.i)
    sqlite3_column_text(*Statement, Index.i)
    sqlite3_column_int64.q(*Statement, Index.i)
    sqlite3_errmsg(*Database)
    sqlite3_changes(*Database)
  EndImport

  Global Db.i
  Global Statement.i
  Global ErrorMessage.s
  Global BackupPath.s

  Procedure.i OpenConnection(Path.s)
    If sqlite3_open_v2(Path, @Db, #SQLITE_OPEN_READWRITE | #SQLITE_OPEN_CREATE,
                       0) <> #SQLITE_OK
      ErrorMessage = LastError()
      Close()
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i IsOpen()
    ProcedureReturn Bool(Db <> 0)
  EndProcedure

  Procedure.s LastError()
    Protected *Message
    If ErrorMessage <> ""
      ProcedureReturn ErrorMessage
    EndIf
    If Db
      *Message = sqlite3_errmsg(Db)
      If *Message
        ProcedureReturn PeekS(*Message, -1, #PB_UTF8)
      EndIf
    EndIf
    ProcedureReturn ""
  EndProcedure

  Procedure.s LastBackupPath()
    ProcedureReturn BackupPath
  EndProcedure

  Procedure.i Query(Sql.s)
    FinishQuery()
    If Db = 0
      ProcedureReturn #False
    EndIf
    If sqlite3_prepare_v2(Db, Sql, -1, @Statement, 0) <> #SQLITE_OK
      ErrorMessage = LastError()
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
    ProcedureReturn Bool(Statement And sqlite3_step(Statement) = #SQLITE_ROW)
  EndProcedure

  Procedure FinishQuery()
    If Statement
      sqlite3_finalize(Statement)
      Statement = 0
    EndIf
  EndProcedure

  Procedure.i Execute(Sql.s)
    Protected Result.i
    If Query(Sql)
      Result = ExecutePrepared()
    EndIf
    ProcedureReturn Result
  EndProcedure

  Procedure.i ExecutePrepared()
    Protected Result.i
    If Statement
      Result = Bool(sqlite3_step(Statement) = #SQLITE_DONE)
      If Result = #False
        ErrorMessage = LastError()
      EndIf
    EndIf
    FinishQuery()
    ProcedureReturn Result
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

  Procedure.i Changes()
    If Db
      ProcedureReturn sqlite3_changes(Db)
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure Close()
    FinishQuery()
    If Db
      sqlite3_close_v2(Db)
    EndIf
    Db = 0
  EndProcedure

  Procedure.q SchemaVersion()
    Protected Version.q
    If Query("PRAGMA user_version") And NextRow()
      Version = ColumnQuad(0)
    EndIf
    FinishQuery()
    ProcedureReturn Version
  EndProcedure

  Procedure.s UniqueBackupPath(Path.s)
    Protected Result.s = Path + ".backup-" +
                         FormatDate("%yyyy%mm%dd-%hh%ii%ss", Date())
    Protected Index.i
    While FileSize(Result) >= 0
      Index + 1
      Result = Path + ".backup-" +
               FormatDate("%yyyy%mm%dd-%hh%ii%ss", Date()) + "-" + Str(Index)
    Wend
    ProcedureReturn Result
  EndProcedure

  Procedure.i MigrateToVersion1()
    Protected Schema.s
    Protected SeedSql.s
    Schema = "CREATE TABLE IF NOT EXISTS notes(" +
             "page_key TEXT PRIMARY KEY,profile_key TEXT NOT NULL," +
             "page_name TEXT NOT NULL,section TEXT NOT NULL,language TEXT," +
             "locale TEXT,note_text TEXT NOT NULL,updated_at TEXT NOT NULL);" +
             "CREATE TABLE IF NOT EXISTS bookmarks(" +
             "page_key TEXT PRIMARY KEY,profile_key TEXT NOT NULL," +
             "page_name TEXT NOT NULL,section TEXT NOT NULL,language TEXT," +
             "locale TEXT,created_at TEXT NOT NULL);" +
             "CREATE TABLE IF NOT EXISTS history(" +
             "id INTEGER PRIMARY KEY AUTOINCREMENT,page_key TEXT NOT NULL," +
             "query_text TEXT,page_name TEXT NOT NULL,section TEXT NOT NULL," +
             "opened_at TEXT NOT NULL);" +
             "CREATE INDEX IF NOT EXISTS history_opened_idx ON history(opened_at);" +
             "CREATE TABLE IF NOT EXISTS settings(" +
             "setting_key TEXT PRIMARY KEY,setting_value TEXT NOT NULL," +
             "updated_at TEXT NOT NULL);" +
             "CREATE TABLE IF NOT EXISTS profiles(" +
             "profile_key TEXT PRIMARY KEY,profile_name TEXT NOT NULL," +
             "last_used_at TEXT NOT NULL);" +
             "CREATE TABLE IF NOT EXISTS search_providers(" +
             "id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE," +
             "url_template TEXT NOT NULL,is_default INTEGER NOT NULL DEFAULT 0," +
             "created_at TEXT NOT NULL);"
    If Execute("BEGIN IMMEDIATE") = #False
      ProcedureReturn #False
    EndIf
    ; DDL is project-owned static text. All user values use bound parameters.
    While Schema <> ""
      If Execute(StringField(Schema, 1, ";")) = #False
        Execute("ROLLBACK")
        ProcedureReturn #False
      EndIf
      Schema = Mid(Schema, FindString(Schema, ";") + 1)
      If FindString(Schema, ";") = 0
        Break
      EndIf
    Wend
    SeedSql = "INSERT OR IGNORE INTO search_providers(name,url_template," +
              "is_default,created_at) VALUES('Google'," +
              "'https://www.google.com/search?q={query}',1,datetime('now'))"
    If Execute(SeedSql) = #False
      Execute("ROLLBACK")
      ProcedureReturn #False
    EndIf
    If Execute("PRAGMA user_version=1") = #False Or Execute("COMMIT") = #False
      Execute("ROLLBACK")
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i Initialize(Path.s)
    Protected Existed.i = Bool(FileSize(Path) >= 0)
    Protected Version.q
    ErrorMessage = ""
    BackupPath = ""
    Close()
    If CreateDirectory(GetPathPart(Path)) = 0 And FileSize(GetPathPart(Path)) <> -2
      ErrorMessage = "Could not create user database directory."
      ProcedureReturn #False
    EndIf
    If OpenConnection(Path) = #False
      ProcedureReturn #False
    EndIf
    Version = SchemaVersion()
    If Version > #SCHEMA_VERSION
      ErrorMessage = "User database schema is newer than this application."
      Close()
      ProcedureReturn #False
    EndIf
    If Version < #SCHEMA_VERSION
      Close()
      If Existed
        BackupPath = UniqueBackupPath(Path)
        If CopyFile(Path, BackupPath) = 0
          ErrorMessage = "Could not create user database backup."
          ProcedureReturn #False
        EndIf
      EndIf
      If OpenConnection(Path) = #False Or MigrateToVersion1() = #False
        Close()
        ProcedureReturn #False
      EndIf
    EndIf
    ProcedureReturn #True
  EndProcedure
EndModule
