XIncludeFile "Version.pbi"
XIncludeFile "Models.pbi"
XIncludeFile "Localization.pbi"
XIncludeFile "Database.pbi"

DeclareModule DatabaseCompatibility
  Declare Check(*Compatibility.Models::DatabaseCompatibility)
EndDeclareModule

Module DatabaseCompatibility
  Procedure.i VersionPart(Version.s, Index.i)
    Protected Part.s = StringField(Version, Index, ".")
    Protected Digits.s
    Protected Position.i
    For Position = 1 To Len(Part)
      If Mid(Part, Position, 1) >= "0" And Mid(Part, Position, 1) <= "9"
        Digits + Mid(Part, Position, 1)
      Else
        Break
      EndIf
    Next
    ProcedureReturn Val(Digits)
  EndProcedure

  Procedure.i CompareVersions(LeftVersion.s, RightVersion.s)
    Protected Index.i
    For Index = 1 To 4
      If VersionPart(LeftVersion, Index) < VersionPart(RightVersion, Index)
        ProcedureReturn -1
      ElseIf VersionPart(LeftVersion, Index) > VersionPart(RightVersion, Index)
        ProcedureReturn 1
      EndIf
    Next
    ProcedureReturn 0
  EndProcedure

  Procedure Check(*Compatibility.Models::DatabaseCompatibility)
    NewMap Meta.s()
    Protected RequiredTables.s = "meta,profiles,pages,sections,aliases,command_info,page_fts"
    Protected Index.i
    Protected TableName.s
    Protected FtsRows.q

    ClearStructure(*Compatibility, Models::DatabaseCompatibility)
    If Database::IsOpen() = #False
      *Compatibility\Message = Localization::Text("database_open_failed")
      ProcedureReturn
    EndIf
    If Database::TableExists("meta") = #False
      *Compatibility\Message = Localization::Text("database_incompatible")
      ProcedureReturn
    EndIf
    If Database::Query("SELECT key,value FROM meta")
      While Database::NextRow()
        Meta(Database::ColumnString(0)) = Database::ColumnString(1)
      Wend
      Database::FinishQuery()
    Else
      *Compatibility\Message = Database::LastError()
      ProcedureReturn
    EndIf

    *Compatibility\DatabaseFormat = Meta("database_format")
    *Compatibility\SchemaVersion = Meta("schema_version")
    *Compatibility\MinimumClientVersion = Meta("minimum_client_version")
    *Compatibility\ProfileId = Val(Meta("profile_id"))

    If *Compatibility\DatabaseFormat <> "1" Or
       *Compatibility\SchemaVersion <> "1" Or
       Meta("text_encoding") <> "UTF-8" Or
       Meta("unicode_normalization") <> "NFC" Or
       CompareVersions(*Compatibility\MinimumClientVersion,
                       ManHelperVersion::#VERSION) > 0
      *Compatibility\Message = Localization::Text("database_incompatible")
      ProcedureReturn
    EndIf

    For Index = 1 To CountString(RequiredTables, ",") + 1
      TableName = StringField(RequiredTables, Index, ",")
      If Database::TableExists(TableName) = #False
        *Compatibility\Message = Localization::Text("database_incompatible") + " " + TableName
        ProcedureReturn
      EndIf
    Next

    If Database::QuerySingleQuad("SELECT COUNT(*) FROM page_fts", @FtsRows) And
       FtsRows > 0
      *Compatibility\FtsAvailable = #True
    Else
      *Compatibility\FtsAvailable = #False
      *Compatibility\Message = Localization::Text("database_fts_unavailable")
      ProcedureReturn
    EndIf
    *Compatibility\IsCompatible = #True
    *Compatibility\Message = Localization::Text("database_ready")
  EndProcedure
EndModule
