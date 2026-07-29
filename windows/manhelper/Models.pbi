DeclareModule Models
  Structure Selection
    OriginalText.s
    NormalizedText.s
    WasTruncated.i
    List Warnings.s()
  EndStructure

  Structure TerminalWindow
    WindowHandle.i
    ProcessId.i
    ExecutablePath.s
    ExecutableName.s
    IsSupported.i
  EndStructure

  Structure AppSettings
    SupportedProcesses.s
    ClipboardLimit.i
    HotKeyModifiers.i
    HotKeyVirtualKey.i
    HotKeyDisplay.s
    DatabasePath.s
    InterfaceLanguage.s
    WebSearchTemplate.s
    BrowserUrlLimit.i
  EndStructure

  Enumeration TokenTypes
    #TokenWord
    #TokenOperator
  EndEnumeration

  Structure CommandToken
    Value.s
    Type.i
  EndStructure

  Structure ParsedCommand
    OriginalText.s
    NormalizedText.s
    PrimaryCommand.s
    List Commands.s()
    List Arguments.s()
    List Warnings.s()
  EndStructure

  Structure DatabaseCompatibility
    IsCompatible.i
    FtsAvailable.i
    ProfileId.i
    Message.s
    DatabaseFormat.s
    SchemaVersion.s
    MinimumClientVersion.s
  EndStructure

  Structure PageResult
    Id.q
    Name.s
    Section.s
    Summary.s
    Synopsis.s
    Language.s
    Locale.s
    Rank.d
    MatchKind.s
    PreferredSection.s
    InitialSearch.s
    WebQuery.s
  EndStructure

  Structure SearchResults
    Query.s
    UsedFts.i
    ErrorMessage.s
    List Pages.PageResult()
  EndStructure

  Structure ManualSection
    Order.i
    OriginalName.s
    NormalizedName.s
    Content.s
  EndStructure

  Structure ManualPage
    Id.q
    ProfileId.q
    Name.s
    Section.s
    Title.s
    Summary.s
    Language.s
    Locale.s
    PlainText.s
    RoffContent.s
    SourcePath.s
    ExecutablePath.s
    ProgramVersion.s
    Renderer.s
    ProfileKey.s
    List Sections.ManualSection()
  EndStructure

  Structure UserPageRef
    PageKey.s
    ProfileKey.s
    Name.s
    Section.s
    Language.s
    Locale.s
  EndStructure

  Structure UserListItem
    Id.q
    PageKey.s
    Name.s
    Section.s
    Query.s
    Timestamp.s
  EndStructure
EndDeclareModule

Module Models
EndModule
