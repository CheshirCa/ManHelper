XIncludeFile "Models.pbi"
XIncludeFile "Database.pbi"

DeclareModule PageRepository
  Declare.i IsDecorativeHeader(PageName.s, PageSection.s, OriginalName.s,
                               NormalizedName.s, Content.s)
  Declare.i LoadPage(PageId.q, *Page.Models::ManualPage)
EndDeclareModule

Module PageRepository
  Procedure.s CollapseWhitespace(Text.s)
    Text = ReplaceString(Text, #CR$, " ")
    Text = ReplaceString(Text, #LF$, " ")
    Text = ReplaceString(Text, #TAB$, " ")
    While FindString(Text, "  ")
      Text = ReplaceString(Text, "  ", " ")
    Wend
    ProcedureReturn Trim(Text)
  EndProcedure

  Procedure.i IsDecorativeHeader(PageName.s, PageSection.s, OriginalName.s,
                                 NormalizedName.s, Content.s)
    Protected Collapsed.s
    Protected Marker.s
    If Trim(OriginalName) <> "" Or UCase(Trim(NormalizedName)) <> "OTHER"
      ProcedureReturn #False
    EndIf
    If FindString(Content, #LF$) Or FindString(Content, #CR$)
      ProcedureReturn #False
    EndIf
    Collapsed = UCase(CollapseWhitespace(Content))
    Marker = UCase(Trim(PageName) + "(" + Trim(PageSection) + ")")
    If Marker = "" Or Len(Collapsed) <= Len(Marker) * 2
      ProcedureReturn #False
    EndIf
    ProcedureReturn Bool(Left(Collapsed, Len(Marker)) = Marker And
                         Right(Collapsed, Len(Marker)) = Marker)
  EndProcedure

  Procedure.i LoadPage(PageId.q, *Page.Models::ManualPage)
    Protected Found.i
    Protected Sql.s
    Protected SectionOrder.i
    Protected OriginalName.s
    Protected NormalizedName.s
    Protected Content.s

    ClearStructure(*Page, Models::ManualPage)
    InitializeStructure(*Page, Models::ManualPage)
    Sql = "SELECT p.id,p.profile_id,p.name,p.section,COALESCE(p.title,'')," +
          "COALESCE(p.summary,''),p.language,COALESCE(p.locale,'')," +
          "COALESCE(p.plain_text,''),COALESCE(p.roff_content,'')," +
          "COALESCE(p.source_path,''),COALESCE(p.executable_path,'')," +
          "COALESCE(p.program_version,''),COALESCE(p.renderer,'')," +
          "COALESCE(pr.profile_name,'') || '|' ||" +
          " COALESCE(pr.distribution_version,'') || '|' ||" +
          " COALESCE(pr.architecture,'')" +
          " FROM pages p JOIN profiles pr ON pr.id=p.profile_id" +
          " WHERE p.id=? LIMIT 1"
    If Database::Query(Sql)
      Database::BindString(0, Str(PageId))
      If Database::NextRow()
        *Page\Id = Database::ColumnQuad(0)
        *Page\ProfileId = Database::ColumnQuad(1)
        *Page\Name = Database::ColumnString(2)
        *Page\Section = Database::ColumnString(3)
        *Page\Title = Database::ColumnString(4)
        *Page\Summary = Database::ColumnString(5)
        *Page\Language = Database::ColumnString(6)
        *Page\Locale = Database::ColumnString(7)
        *Page\PlainText = Database::ColumnString(8)
        *Page\RoffContent = Database::ColumnString(9)
        *Page\SourcePath = Database::ColumnString(10)
        *Page\ExecutablePath = Database::ColumnString(11)
        *Page\ProgramVersion = Database::ColumnString(12)
        *Page\Renderer = Database::ColumnString(13)
        *Page\ProfileKey = Database::ColumnString(14)
        Found = #True
      EndIf
    EndIf
    Database::FinishQuery()
    If Found = #False
      ProcedureReturn #False
    EndIf

    Sql = "SELECT section_order,COALESCE(original_name,'')," +
          "normalized_name,content FROM sections" +
          " WHERE page_id=? AND length(trim(content))>0" +
          " ORDER BY section_order"
    If Database::Query(Sql)
      Database::BindString(0, Str(PageId))
      While Database::NextRow()
        SectionOrder = Database::ColumnQuad(0)
        OriginalName = Database::ColumnString(1)
        NormalizedName = Database::ColumnString(2)
        Content = Database::ColumnString(3)
        If IsDecorativeHeader(*Page\Name, *Page\Section, OriginalName,
                              NormalizedName, Content) = #False
          AddElement(*Page\Sections())
          *Page\Sections()\Order = SectionOrder
          *Page\Sections()\OriginalName = OriginalName
          *Page\Sections()\NormalizedName = NormalizedName
          *Page\Sections()\Content = Content
        EndIf
      Wend
    EndIf
    Database::FinishQuery()
    ProcedureReturn #True
  EndProcedure
EndModule
