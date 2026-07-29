DeclareModule SearchRank
  Declare.s SectionOrderSql(ColumnName.s)
  Declare.i SectionPriority(Section.s)
EndDeclareModule

Module SearchRank
  Procedure.i SectionPriority(Section.s)
    Select Section
      Case "1": ProcedureReturn 1
      Case "8": ProcedureReturn 2
      Case "6": ProcedureReturn 3
      Case "5": ProcedureReturn 4
      Case "7": ProcedureReturn 5
      Case "2": ProcedureReturn 6
      Case "3": ProcedureReturn 7
      Case "4": ProcedureReturn 8
      Case "9": ProcedureReturn 9
    EndSelect
    ProcedureReturn 10
  EndProcedure

  Procedure.s SectionOrderSql(ColumnName.s)
    ProcedureReturn "CASE " + ColumnName +
                    " WHEN '1' THEN 1 WHEN '8' THEN 2 WHEN '6' THEN 3" +
                    " WHEN '5' THEN 4 WHEN '7' THEN 5 WHEN '2' THEN 6" +
                    " WHEN '3' THEN 7 WHEN '4' THEN 8 WHEN '9' THEN 9" +
                    " ELSE 10 END"
  EndProcedure
EndModule
