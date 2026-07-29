XIncludeFile "Models.pbi"

DeclareModule AppState
  Global Settings.Models::AppSettings
  Global Terminal.Models::TerminalWindow
  Global Selection.Models::Selection
  Global Parsed.Models::ParsedCommand
  Global Results.Models::SearchResults
  Global Compatibility.Models::DatabaseCompatibility
  Global DatabaseReady.i
  Global Running.i
EndDeclareModule

Module AppState
  Global Settings.Models::AppSettings
  Global Terminal.Models::TerminalWindow
  Global Selection.Models::Selection
  Global Parsed.Models::ParsedCommand
  Global Results.Models::SearchResults
  Global Compatibility.Models::DatabaseCompatibility
  Global DatabaseReady.i
  Global Running.i = #True
EndModule
