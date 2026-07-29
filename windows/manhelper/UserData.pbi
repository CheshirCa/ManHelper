XIncludeFile "Models.pbi"
XIncludeFile "UserDatabase.pbi"

DeclareModule UserData
  Declare MakePageRef(*Page.Models::ManualPage, *Ref.Models::UserPageRef)
  Declare.i SaveNote(*Ref.Models::UserPageRef, Text.s)
  Declare.i LoadNote(*Ref.Models::UserPageRef, *Text.String)
  Declare.i DeleteNote(*Ref.Models::UserPageRef)
  Declare.i IsBookmarked(*Ref.Models::UserPageRef)
  Declare.i SetBookmarked(*Ref.Models::UserPageRef, State.i)
  Declare.i AddHistory(*Ref.Models::UserPageRef, Query.s)
  Declare.i SaveSetting(Key.s, Value.s)
  Declare.i LoadSetting(Key.s, *Value.String)
  Declare.i RegisterProfile(*Ref.Models::UserPageRef)
  Declare LoadBookmarks(List Items.Models::UserListItem())
  Declare LoadHistory(List Items.Models::UserListItem())
  Declare.i DeleteBookmark(PageKey.s)
  Declare.i DeleteHistory(Id.q)
  Declare.q CountRows(TableName.s)
EndDeclareModule

Module UserData
  Procedure.s NowText()
    ProcedureReturn FormatDate("%yyyy-%mm-%ddT%hh:%ii:%ss", Date())
  EndProcedure

  Procedure MakePageRef(*Page.Models::ManualPage, *Ref.Models::UserPageRef)
    *Ref\ProfileKey = *Page\ProfileKey
    *Ref\Name = *Page\Name
    *Ref\Section = *Page\Section
    *Ref\Language = *Page\Language
    *Ref\Locale = *Page\Locale
    *Ref\PageKey = *Ref\ProfileKey + "|" + *Ref\Name + "|" + *Ref\Section +
                   "|" + *Ref\Language + "|" + *Ref\Locale
  EndProcedure

  Procedure BindPage(*Ref.Models::UserPageRef)
    UserDatabase::BindString(0, *Ref\PageKey)
    UserDatabase::BindString(1, *Ref\ProfileKey)
    UserDatabase::BindString(2, *Ref\Name)
    UserDatabase::BindString(3, *Ref\Section)
    UserDatabase::BindString(4, *Ref\Language)
    UserDatabase::BindString(5, *Ref\Locale)
  EndProcedure

  Procedure.i SaveNote(*Ref.Models::UserPageRef, Text.s)
    If Trim(Text) = ""
      ProcedureReturn DeleteNote(*Ref)
    EndIf
    If UserDatabase::Query("INSERT INTO notes(page_key,profile_key,page_name," +
                           "section,language,locale,note_text,updated_at)" +
                           " VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(page_key)" +
                           " DO UPDATE SET note_text=excluded.note_text," +
                           "updated_at=excluded.updated_at")
      BindPage(*Ref)
      UserDatabase::BindString(6, Text)
      UserDatabase::BindString(7, NowText())
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.i LoadNote(*Ref.Models::UserPageRef, *Text.String)
    *Text\s = ""
    If UserDatabase::Query("SELECT note_text FROM notes WHERE page_key=?")
      UserDatabase::BindString(0, *Ref\PageKey)
      If UserDatabase::NextRow()
        *Text\s = UserDatabase::ColumnString(0)
        UserDatabase::FinishQuery()
        ProcedureReturn #True
      EndIf
    EndIf
    UserDatabase::FinishQuery()
    ProcedureReturn #False
  EndProcedure

  Procedure.i DeleteNote(*Ref.Models::UserPageRef)
    If UserDatabase::Query("DELETE FROM notes WHERE page_key=?")
      UserDatabase::BindString(0, *Ref\PageKey)
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.i IsBookmarked(*Ref.Models::UserPageRef)
    Protected Found.i
    If UserDatabase::Query("SELECT 1 FROM bookmarks WHERE page_key=?")
      UserDatabase::BindString(0, *Ref\PageKey)
      Found = UserDatabase::NextRow()
    EndIf
    UserDatabase::FinishQuery()
    ProcedureReturn Found
  EndProcedure

  Procedure.i SetBookmarked(*Ref.Models::UserPageRef, State.i)
    If State
      If UserDatabase::Query("INSERT INTO bookmarks(page_key,profile_key," +
                             "page_name,section,language,locale,created_at)" +
                             " VALUES(?,?,?,?,?,?,?)" +
                             " ON CONFLICT(page_key) DO NOTHING")
        BindPage(*Ref)
        UserDatabase::BindString(6, NowText())
        ProcedureReturn UserDatabase::ExecutePrepared()
      EndIf
    ElseIf UserDatabase::Query("DELETE FROM bookmarks WHERE page_key=?")
      UserDatabase::BindString(0, *Ref\PageKey)
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.i AddHistory(*Ref.Models::UserPageRef, Query.s)
    If UserDatabase::Query("INSERT INTO history(page_key,query_text,page_name," +
                           "section,opened_at) VALUES(?,?,?,?,?)")
      UserDatabase::BindString(0, *Ref\PageKey)
      UserDatabase::BindString(1, Query)
      UserDatabase::BindString(2, *Ref\Name)
      UserDatabase::BindString(3, *Ref\Section)
      UserDatabase::BindString(4, NowText())
      If UserDatabase::ExecutePrepared()
        UserDatabase::Execute("DELETE FROM history WHERE id NOT IN" +
                              "(SELECT id FROM history ORDER BY id DESC LIMIT 1000)")
        ProcedureReturn #True
      EndIf
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.i SaveSetting(Key.s, Value.s)
    If UserDatabase::Query("INSERT INTO settings(setting_key,setting_value," +
                           "updated_at) VALUES(?,?,?) ON CONFLICT(setting_key)" +
                           " DO UPDATE SET setting_value=excluded.setting_value," +
                           "updated_at=excluded.updated_at")
      UserDatabase::BindString(0, Key)
      UserDatabase::BindString(1, Value)
      UserDatabase::BindString(2, NowText())
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.i LoadSetting(Key.s, *Value.String)
    If UserDatabase::Query("SELECT setting_value FROM settings WHERE setting_key=?")
      UserDatabase::BindString(0, Key)
      If UserDatabase::NextRow()
        *Value\s = UserDatabase::ColumnString(0)
        UserDatabase::FinishQuery()
        ProcedureReturn #True
      EndIf
    EndIf
    UserDatabase::FinishQuery()
    ProcedureReturn #False
  EndProcedure

  Procedure.i RegisterProfile(*Ref.Models::UserPageRef)
    If UserDatabase::Query("INSERT INTO profiles(profile_key,profile_name," +
                           "last_used_at) VALUES(?,?,?) ON CONFLICT(profile_key)" +
                           " DO UPDATE SET last_used_at=excluded.last_used_at")
      UserDatabase::BindString(0, *Ref\ProfileKey)
      UserDatabase::BindString(1, *Ref\ProfileKey)
      UserDatabase::BindString(2, NowText())
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure LoadBookmarks(List Items.Models::UserListItem())
    ClearList(Items())
    If UserDatabase::Query("SELECT page_key,page_name,section,created_at" +
                           " FROM bookmarks ORDER BY created_at DESC")
      While UserDatabase::NextRow()
        AddElement(Items())
        Items()\PageKey = UserDatabase::ColumnString(0)
        Items()\Name = UserDatabase::ColumnString(1)
        Items()\Section = UserDatabase::ColumnString(2)
        Items()\Timestamp = UserDatabase::ColumnString(3)
      Wend
    EndIf
    UserDatabase::FinishQuery()
  EndProcedure

  Procedure LoadHistory(List Items.Models::UserListItem())
    ClearList(Items())
    If UserDatabase::Query("SELECT id,page_key,page_name,section," +
                           "COALESCE(query_text,''),opened_at FROM history" +
                           " ORDER BY id DESC LIMIT 1000")
      While UserDatabase::NextRow()
        AddElement(Items())
        Items()\Id = UserDatabase::ColumnQuad(0)
        Items()\PageKey = UserDatabase::ColumnString(1)
        Items()\Name = UserDatabase::ColumnString(2)
        Items()\Section = UserDatabase::ColumnString(3)
        Items()\Query = UserDatabase::ColumnString(4)
        Items()\Timestamp = UserDatabase::ColumnString(5)
      Wend
    EndIf
    UserDatabase::FinishQuery()
  EndProcedure

  Procedure.i DeleteBookmark(PageKey.s)
    If UserDatabase::Query("DELETE FROM bookmarks WHERE page_key=?")
      UserDatabase::BindString(0, PageKey)
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.i DeleteHistory(Id.q)
    If UserDatabase::Query("DELETE FROM history WHERE id=?")
      UserDatabase::BindString(0, Str(Id))
      ProcedureReturn UserDatabase::ExecutePrepared()
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.q CountRows(TableName.s)
    Protected Count.q
    Select TableName
      Case "notes", "bookmarks", "history", "settings", "profiles",
           "search_providers"
      Default
        ProcedureReturn -1
    EndSelect
    If UserDatabase::Query("SELECT COUNT(*) FROM " + TableName) And
       UserDatabase::NextRow()
      Count = UserDatabase::ColumnQuad(0)
    EndIf
    UserDatabase::FinishQuery()
    ProcedureReturn Count
  EndProcedure
EndModule
