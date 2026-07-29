XIncludeFile "Models.pbi"
XIncludeFile "Database.pbi"
XIncludeFile "SearchRank.pbi"

DeclareModule SearchFts
  Declare Search(QueryText.s, ProfileId.i, *Results.Models::SearchResults)
EndDeclareModule

Module SearchFts
  Procedure.s LiteralQuery(QueryText.s)
    ProcedureReturn #DQUOTE$ +
                    ReplaceString(QueryText, #DQUOTE$, #DQUOTE$ + #DQUOTE$) +
                    #DQUOTE$
  EndProcedure

  Procedure Search(QueryText.s, ProfileId.i, *Results.Models::SearchResults)
    Protected Sql.s
    ClearList(*Results\Pages())
    *Results\Query = QueryText
    *Results\UsedFts = #True
    *Results\ErrorMessage = ""
    If Trim(QueryText) = ""
      ProcedureReturn
    EndIf

    Sql = "SELECT p.id,p.name,p.section,COALESCE(p.summary,'')," +
          "COALESCE((SELECT s.content FROM sections s" +
          " WHERE s.page_id=p.id AND s.normalized_name='SYNOPSIS'" +
          " ORDER BY s.section_order LIMIT 1),'')," +
          "p.language,COALESCE(p.locale,''),bm25(page_fts)" +
          " FROM page_fts JOIN pages p ON p.id=page_fts.page_id" +
          " WHERE page_fts MATCH ? AND p.profile_id=?" +
          " ORDER BY bm25(page_fts)," + SearchRank::SectionOrderSql("p.section") +
          " LIMIT 20"
    If Database::Query(Sql) = #False
      *Results\ErrorMessage = Database::LastError()
      ProcedureReturn
    EndIf
    Database::BindString(0, LiteralQuery(QueryText))
    Database::BindString(1, Str(ProfileId))
    While Database::NextRow()
      AddElement(*Results\Pages())
      *Results\Pages()\Id = Database::ColumnQuad(0)
      *Results\Pages()\Name = Database::ColumnString(1)
      *Results\Pages()\Section = Database::ColumnString(2)
      *Results\Pages()\Summary = Database::ColumnString(3)
      *Results\Pages()\Synopsis = Database::ColumnString(4)
      *Results\Pages()\Language = Database::ColumnString(5)
      *Results\Pages()\Locale = Database::ColumnString(6)
      *Results\Pages()\Rank = Database::ColumnDouble(7)
      *Results\Pages()\MatchKind = "fts"
    Wend
    Database::FinishQuery()
  EndProcedure
EndModule
