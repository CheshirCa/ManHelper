XIncludeFile "Version.pbi"

DeclareModule Localization
  Declare SetLanguage(Language.s)
  Declare.s GetLanguage()
  Declare.s Text(Key.s)
EndDeclareModule

Module Localization
  Global CurrentLanguage.s = "ru"

  Procedure SetLanguage(Language.s)
    If LCase(Left(Trim(Language), 2)) = "en"
      CurrentLanguage = "en"
    Else
      CurrentLanguage = "ru"
    EndIf
  EndProcedure

  Procedure.s GetLanguage()
    ProcedureReturn CurrentLanguage
  EndProcedure

  Procedure.s EnglishText(Key.s)
    Select Key
      Case "app_title": ProcedureReturn "ManHelper " + ManHelperVersion::#VERSION
      Case "tray_tooltip": ProcedureReturn "ManHelper — "
      Case "tray_show": ProcedureReturn "Show clipboard text"
      Case "tray_exit": ProcedureReturn "Exit"
      Case "tray_library": ProcedureReturn "Bookmarks and history"
      Case "tray_settings": ProcedureReturn "Settings"
      Case "tray_error": ProcedureReturn "Could not create the ManHelper notification-area icon."
      Case "hotkey_error": ProcedureReturn "Could not register the global hotkey. It may be in use by another application: "
      Case "popup_terminal": ProcedureReturn "Terminal: "
      Case "popup_tray_source": ProcedureReturn "tray"
      Case "popup_selection": ProcedureReturn "Selected"
      Case "popup_normalized": ProcedureReturn "Normalized text"
      Case "popup_command": ProcedureReturn "Command: "
      Case "popup_summary": ProcedureReturn "Summary"
      Case "popup_synopsis": ProcedureReturn "Synopsis"
      Case "popup_details": ProcedureReturn "Details"
      Case "popup_copy": ProcedureReturn "Copy"
      Case "popup_web": ProcedureReturn "Search the web"
      Case "popup_empty": ProcedureReturn "The clipboard does not contain text."
      Case "popup_truncated": ProcedureReturn "Text was limited to 4096 characters."
      Case "popup_controls_removed": ProcedureReturn "Control characters were removed."
      Case "popup_unsupported": ProcedureReturn "The active window does not belong to PuTTY or KiTTY."
      Case "database_not_configured": ProcedureReturn "The man database path is not configured."
      Case "database_open_failed": ProcedureReturn "Could not open the man database read-only."
      Case "database_incompatible": ProcedureReturn "The man database is incompatible with this ManHelper version."
      Case "database_ready": ProcedureReturn "The man database is connected."
      Case "database_no_results": ProcedureReturn "No matching man page was found."
      Case "database_fts_unavailable": ProcedureReturn "Full-text search is unavailable."
      Case "parser_unclosed_quote": ProcedureReturn "An unclosed quote was found; available text was parsed."
      Case "parser_trailing_escape": ProcedureReturn "The line ends with an escape character."
      Case "parser_command_missing": ProcedureReturn "Could not determine the primary command."
      Case "details_title": ProcedureReturn "Manual details"
      Case "details_command": ProcedureReturn "Pipeline command"
      Case "details_page": ProcedureReturn "Manual page"
      Case "details_view": ProcedureReturn "Content"
      Case "details_full_text": ProcedureReturn "Full plain text"
      Case "details_roff": ProcedureReturn "Source roff (not executed)"
      Case "details_previous": ProcedureReturn "Previous"
      Case "details_next": ProcedureReturn "Next"
      Case "details_search": ProcedureReturn "Find in text"
      Case "details_find_next": ProcedureReturn "Find next"
      Case "details_copy": ProcedureReturn "Copy displayed text"
      Case "details_web": ProcedureReturn "Search the web"
      Case "details_close": ProcedureReturn "Close"
      Case "details_note": ProcedureReturn "Note"
      Case "details_bookmark_add": ProcedureReturn "Add bookmark"
      Case "details_bookmark_remove": ProcedureReturn "Remove bookmark"
      Case "details_not_found": ProcedureReturn "Text not found."
      Case "details_found": ProcedureReturn "Match at position {position}."
      Case "details_load_failed": ProcedureReturn "Could not load the selected manual page."
      Case "browser_invalid_template": ProcedureReturn "The web search template must use HTTPS or HTTP and contain {query}."
      Case "browser_url_too_long": ProcedureReturn "The generated web address is too long."
      Case "browser_open_failed": ProcedureReturn "Could not open the system browser."
      Case "notes_title": ProcedureReturn "Page note"
      Case "notes_save": ProcedureReturn "Save"
      Case "notes_delete": ProcedureReturn "Delete"
      Case "notes_saved": ProcedureReturn "Note saved."
      Case "notes_deleted": ProcedureReturn "Note deleted."
      Case "user_database_error": ProcedureReturn "User data is unavailable."
      Case "library_title": ProcedureReturn "Bookmarks and history"
      Case "library_bookmarks": ProcedureReturn "Bookmarks"
      Case "library_history": ProcedureReturn "History"
      Case "library_page": ProcedureReturn "Page"
      Case "library_query": ProcedureReturn "Query"
      Case "library_date": ProcedureReturn "Date"
      Case "library_delete": ProcedureReturn "Delete selected"
      Case "library_refresh": ProcedureReturn "Refresh"
      Case "settings_title": ProcedureReturn "User settings"
      Case "settings_language": ProcedureReturn "Interface language (ru/en)"
      Case "settings_web_template": ProcedureReturn "Web search template"
      Case "settings_url_limit": ProcedureReturn "Maximum URL length"
      Case "settings_save": ProcedureReturn "Save"
      Case "settings_restart": ProcedureReturn "Settings saved. Restart ManHelper to apply all changes."
    EndSelect
    ProcedureReturn Key
  EndProcedure

  Procedure.s RussianText(Key.s)
    Select Key
      Case "app_title": ProcedureReturn "ManHelper " + ManHelperVersion::#VERSION
      Case "tray_tooltip": ProcedureReturn "ManHelper — "
      Case "tray_show": ProcedureReturn "Показать текст из буфера"
      Case "tray_exit": ProcedureReturn "Выход"
      Case "tray_library": ProcedureReturn "Закладки и история"
      Case "tray_settings": ProcedureReturn "Настройки"
      Case "tray_error": ProcedureReturn "Не удалось создать значок ManHelper в области уведомлений."
      Case "hotkey_error": ProcedureReturn "Не удалось зарегистрировать глобальную горячую клавишу. Возможно, сочетание занято другим приложением: "
      Case "popup_terminal": ProcedureReturn "Терминал: "
      Case "popup_tray_source": ProcedureReturn "панель задач"
      Case "popup_selection": ProcedureReturn "Выделено"
      Case "popup_normalized": ProcedureReturn "Нормализованный текст"
      Case "popup_command": ProcedureReturn "Команда: "
      Case "popup_summary": ProcedureReturn "Краткое описание"
      Case "popup_synopsis": ProcedureReturn "Синтаксис"
      Case "popup_details": ProcedureReturn "Подробнее"
      Case "popup_copy": ProcedureReturn "Копировать"
      Case "popup_web": ProcedureReturn "Искать в интернете"
      Case "popup_empty": ProcedureReturn "Буфер обмена не содержит текста."
      Case "popup_truncated": ProcedureReturn "Текст ограничен безопасным лимитом 4096 символов."
      Case "popup_controls_removed": ProcedureReturn "Управляющие символы удалены."
      Case "popup_unsupported": ProcedureReturn "Активное окно не принадлежит PuTTY или KiTTY."
      Case "database_not_configured": ProcedureReturn "Путь к man-базе не настроен."
      Case "database_open_failed": ProcedureReturn "Не удалось открыть man-базу только для чтения."
      Case "database_incompatible": ProcedureReturn "Man-база несовместима с этой версией ManHelper."
      Case "database_ready": ProcedureReturn "Man-база подключена."
      Case "database_no_results": ProcedureReturn "Подходящая man-страница не найдена."
      Case "database_fts_unavailable": ProcedureReturn "Полнотекстовый поиск недоступен."
      Case "parser_unclosed_quote": ProcedureReturn "Незакрытая кавычка; разбор выполнен по доступному тексту."
      Case "parser_trailing_escape": ProcedureReturn "Строка заканчивается символом экранирования."
      Case "parser_command_missing": ProcedureReturn "Не удалось определить основную команду."
      Case "details_title": ProcedureReturn "Подробная справка"
      Case "details_command": ProcedureReturn "Команда pipeline"
      Case "details_page": ProcedureReturn "Man-страница"
      Case "details_view": ProcedureReturn "Содержимое"
      Case "details_full_text": ProcedureReturn "Полный plain text"
      Case "details_roff": ProcedureReturn "Исходный roff (не исполняется)"
      Case "details_previous": ProcedureReturn "Назад"
      Case "details_next": ProcedureReturn "Вперёд"
      Case "details_search": ProcedureReturn "Найти в тексте"
      Case "details_find_next": ProcedureReturn "Найти далее"
      Case "details_copy": ProcedureReturn "Копировать показанный текст"
      Case "details_web": ProcedureReturn "Искать в интернете"
      Case "details_close": ProcedureReturn "Закрыть"
      Case "details_note": ProcedureReturn "Заметка"
      Case "details_bookmark_add": ProcedureReturn "Добавить закладку"
      Case "details_bookmark_remove": ProcedureReturn "Удалить закладку"
      Case "details_not_found": ProcedureReturn "Текст не найден."
      Case "details_found": ProcedureReturn "Совпадение с позиции {position}."
      Case "details_load_failed": ProcedureReturn "Не удалось загрузить выбранную man-страницу."
      Case "browser_invalid_template": ProcedureReturn "Шаблон веб-поиска должен использовать HTTPS или HTTP и содержать {query}."
      Case "browser_url_too_long": ProcedureReturn "Сформированный веб-адрес слишком длинный."
      Case "browser_open_failed": ProcedureReturn "Не удалось открыть системный браузер."
      Case "notes_title": ProcedureReturn "Заметка к странице"
      Case "notes_save": ProcedureReturn "Сохранить"
      Case "notes_delete": ProcedureReturn "Удалить"
      Case "notes_saved": ProcedureReturn "Заметка сохранена."
      Case "notes_deleted": ProcedureReturn "Заметка удалена."
      Case "user_database_error": ProcedureReturn "Пользовательские данные недоступны."
      Case "library_title": ProcedureReturn "Закладки и история"
      Case "library_bookmarks": ProcedureReturn "Закладки"
      Case "library_history": ProcedureReturn "История"
      Case "library_page": ProcedureReturn "Страница"
      Case "library_query": ProcedureReturn "Запрос"
      Case "library_date": ProcedureReturn "Дата"
      Case "library_delete": ProcedureReturn "Удалить выбранное"
      Case "library_refresh": ProcedureReturn "Обновить"
      Case "settings_title": ProcedureReturn "Пользовательские настройки"
      Case "settings_language": ProcedureReturn "Язык интерфейса (ru/en)"
      Case "settings_web_template": ProcedureReturn "Шаблон веб-поиска"
      Case "settings_url_limit": ProcedureReturn "Максимальная длина URL"
      Case "settings_save": ProcedureReturn "Сохранить"
      Case "settings_restart": ProcedureReturn "Настройки сохранены. Перезапустите ManHelper для полного применения."
    EndSelect
    ProcedureReturn Key
  EndProcedure

  Procedure.s Text(Key.s)
    If CurrentLanguage = "en"
      ProcedureReturn EnglishText(Key)
    EndIf
    ProcedureReturn RussianText(Key)
  EndProcedure
EndModule
