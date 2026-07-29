XIncludeFile "Models.pbi"
XIncludeFile "Database.pbi"
XIncludeFile "SearchRank.pbi"

DeclareModule SearchExact
  Declare Search(QueryText.s, ProfileId.i, *Results.Models::SearchResults)
EndDeclareModule

Module SearchExact
  Procedure.i IsShellBuiltin(Name.s, ProfileId.i)
    Protected Synopsis.s
    Protected Items.s
    Protected Item.s
    Protected Index.i
    Protected Colon.i
    Protected Result.i
    If Database::Query("SELECT s.content FROM pages p JOIN sections s" +
                       " ON s.page_id=p.id WHERE p.profile_id=? AND" +
                       " p.name='bash-builtins' AND p.section='7' AND" +
                       " s.normalized_name='SYNOPSIS' LIMIT 1")
      Database::BindString(0, Str(ProfileId))
      If Database::NextRow()
        Synopsis = Database::ColumnString(0)
      EndIf
    EndIf
    Database::FinishQuery()
    Colon = FindString(Synopsis, ":")
    If Colon = 0
      ProcedureReturn #False
    EndIf
    Items = Mid(Synopsis, Colon + 1)
    Items = ReplaceString(Items, #CR$, " ")
    Items = ReplaceString(Items, #LF$, " ")
    For Index = 1 To CountString(Items, ",") + 1
      Item = LCase(Trim(StringField(Items, Index, ",")))
      While FindString(Item, "  ")
        Item = ReplaceString(Item, "  ", " ")
      Wend
      If Right(Item, 1) = "."
        Item = Left(Item, Len(Item) - 1)
      EndIf
      If Item = LCase(Name)
        Result = #True
        Break
      EndIf
    Next
    ProcedureReturn Result
  EndProcedure

  Procedure.s BuiltinDescription(Content.s, Name.s)
    Protected Index.i
    Protected Line.s
    Protected LowerName.s = LCase(Name)
    Protected NextCharacter.s
    Content = ReplaceString(Content, #CRLF$, #LF$)
    Content = ReplaceString(Content, #CR$, #LF$)
    For Index = 1 To CountString(Content, #LF$) + 1
      Line = Trim(StringField(Content, Index, #LF$))
      If LCase(Left(Line, Len(Name))) = LowerName And Len(Line) > Len(Name)
        NextCharacter = Mid(Line, Len(Name) + 1, 1)
        If NextCharacter = " " Or NextCharacter = "["
          ProcedureReturn Line
        EndIf
      EndIf
    Next
    ProcedureReturn Name
  EndProcedure

  Procedure.i AddShellBuiltin(Name.s, ProfileId.i,
                              *Results.Models::SearchResults)
    Protected Content.s
    Protected Description.s
    If IsShellBuiltin(Name, ProfileId) = #False
      ProcedureReturn #False
    EndIf
    If Database::Query("SELECT p.id,p.name,p.section,COALESCE(p.summary,'')," +
                       "p.language,COALESCE(p.locale,''),s.content" +
                       " FROM pages p JOIN sections s ON s.page_id=p.id" +
                       " WHERE p.profile_id=? AND p.name='bash' AND" +
                       " p.section='1' AND s.original_name=" +
                       "'SHELL BUILTIN COMMANDS' LIMIT 1")
      Database::BindString(0, Str(ProfileId))
      If Database::NextRow()
        AddElement(*Results\Pages())
        *Results\Pages()\Id = Database::ColumnQuad(0)
        *Results\Pages()\Name = Database::ColumnString(1)
        *Results\Pages()\Section = Database::ColumnString(2)
        *Results\Pages()\Summary = Database::ColumnString(3)
        *Results\Pages()\Language = Database::ColumnString(4)
        *Results\Pages()\Locale = Database::ColumnString(5)
        Content = Database::ColumnString(6)
        Description = BuiltinDescription(Content, Name)
        *Results\Pages()\Synopsis = Description
        *Results\Pages()\MatchKind = "shell_builtin"
        *Results\Pages()\PreferredSection = "SHELL BUILTIN COMMANDS"
        *Results\Pages()\InitialSearch = Description
        *Results\Pages()\WebQuery = Name
      EndIf
    EndIf
    Database::FinishQuery()
    ProcedureReturn Bool(ListSize(*Results\Pages()) > 0)
  EndProcedure

  Procedure AddRows(*Results.Models::SearchResults, MatchKind.s)
    While Database::NextRow()
      AddElement(*Results\Pages())
      *Results\Pages()\Id = Database::ColumnQuad(0)
      *Results\Pages()\Name = Database::ColumnString(1)
      *Results\Pages()\Section = Database::ColumnString(2)
      *Results\Pages()\Summary = Database::ColumnString(3)
      *Results\Pages()\Synopsis = Database::ColumnString(4)
      *Results\Pages()\Language = Database::ColumnString(5)
      *Results\Pages()\Locale = Database::ColumnString(6)
      *Results\Pages()\MatchKind = MatchKind
    Wend
    Database::FinishQuery()
  EndProcedure

  Procedure.s PageColumns()
    ProcedureReturn "p.id,p.name,p.section,COALESCE(p.summary,'')," +
                    "COALESCE((SELECT s.content FROM sections s" +
                    " WHERE s.page_id=p.id AND s.normalized_name='SYNOPSIS'" +
                    " ORDER BY s.section_order LIMIT 1),'')," +
                    "p.language,COALESCE(p.locale,'')"
  EndProcedure

  Procedure SplitSection(QueryText.s, *Name.String, *Section.String)
    Protected OpenParen.i = FindString(QueryText, "(")
    *Name\s = QueryText
    *Section\s = ""
    If OpenParen > 1 And Right(QueryText, 1) = ")"
      *Name\s = Left(QueryText, OpenParen - 1)
      *Section\s = Mid(QueryText, OpenParen + 1,
                       Len(QueryText) - OpenParen - 1)
    EndIf
  EndProcedure

  Procedure Search(QueryText.s, ProfileId.i, *Results.Models::SearchResults)
    Protected Name.String
    Protected Section.String
    Protected Sql.s

    ClearList(*Results\Pages())
    *Results\Query = QueryText
    *Results\UsedFts = #False
    *Results\ErrorMessage = ""
    SplitSection(QueryText, @Name, @Section)
    If Name\s = ""
      ProcedureReturn
    EndIf

    If Section\s <> ""
      Sql = "SELECT " + PageColumns() + " FROM pages p" +
            " WHERE p.profile_id=? AND p.name=? AND p.section=?" +
            " ORDER BY p.language,COALESCE(p.locale,'') LIMIT 20"
      If Database::Query(Sql)
        Database::BindString(0, Str(ProfileId))
        Database::BindString(1, Name\s)
        Database::BindString(2, Section\s)
        AddRows(*Results, "name_section")
      EndIf
      If ListSize(*Results\Pages()) > 0
        ProcedureReturn
      EndIf
    EndIf

    Sql = "SELECT " + PageColumns() + " FROM pages p" +
          " WHERE p.profile_id=? AND p.name=?" +
          " ORDER BY " + SearchRank::SectionOrderSql("p.section") +
          ",p.section,p.language,COALESCE(p.locale,'') LIMIT 20"
    If Database::Query(Sql)
      Database::BindString(0, Str(ProfileId))
      Database::BindString(1, Name\s)
      AddRows(*Results, "name")
    EndIf
    If ListSize(*Results\Pages()) > 0
      ProcedureReturn
    EndIf

    If AddShellBuiltin(Name\s, ProfileId, *Results)
      ProcedureReturn
    EndIf

    Sql = "SELECT " + PageColumns() + " FROM aliases a" +
          " JOIN pages p ON p.id=a.page_id" +
          " WHERE p.profile_id=? AND a.alias=?" +
          " ORDER BY " + SearchRank::SectionOrderSql("p.section") +
          ",p.section,p.language,COALESCE(p.locale,'') LIMIT 20"
    If Database::Query(Sql)
      Database::BindString(0, Str(ProfileId))
      Database::BindString(1, Name\s)
      AddRows(*Results, "alias")
    EndIf
    If ListSize(*Results\Pages()) > 0
      ProcedureReturn
    EndIf

    Sql = "SELECT " + PageColumns() + " FROM command_info c" +
          " JOIN pages p ON p.id=c.page_id" +
          " WHERE p.profile_id=? AND c.command_name=?" +
          " ORDER BY " + SearchRank::SectionOrderSql("p.section") +
          ",p.section,p.language,COALESCE(p.locale,'') LIMIT 20"
    If Database::Query(Sql)
      Database::BindString(0, Str(ProfileId))
      Database::BindString(1, Name\s)
      AddRows(*Results, "command_info")
    Else
      *Results\ErrorMessage = Database::LastError()
    EndIf
  EndProcedure
EndModule
