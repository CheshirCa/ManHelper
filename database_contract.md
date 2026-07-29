Ниже — готовый блок, который стоит передать в промпт для Windows-версии.

---

## Контракт SQLite-базы ManBase Builder

Windows-клиент должен работать с SQLite-базой, созданной Linux ManBase Builder. База рассматривается как переносимый read-only файл. Не изменять её структуру, meta, FTS или содержимое.

### Совместимость

Перед открытием проверить таблицу `meta`:

```text
database_format = 1
schema_version = 1
text_encoding = UTF-8
unicode_normalization = NFC
fts_version = FTS5 unicode61
minimum_client_version = 0.1.0
```

Дополнительно прочитать:

```text
builder_name
builder_version
created_at
updated_at
profile_id
content_checksum
capabilities
```

Не открывать базу с более новой неподдерживаемой `schema_version`. Не полагаться на расширение файла — проверять структуру и meta.

SQLite-библиотека Windows-клиента должна поддерживать FTS5.

### Проверка базы

При подключении выполнить:

```sql
PRAGMA foreign_keys = ON;
PRAGMA integrity_check;
PRAGMA foreign_key_check;
```

Ожидаемый результат:

```text
integrity_check = ok
foreign_key_check = пустой набор
```

Checksum рассчитывается как SHA-256 от последовательности строк для всех страниц по `id`:

```text
{id}:{content_hash}\n
```

Страницы обходятся запросом:

```sql
SELECT id, content_hash
FROM pages
ORDER BY id;
```

Строки кодируются в UTF-8. Полученный lowercase hex digest сравнивается с `meta.content_checksum`.

Важно: текущий checksum защищает набор `pages.content_hash`, но не является криптографической подписью всего SQLite-файла.

### Профиль системы

Текущий профиль определяется через:

```sql
SELECT value FROM meta WHERE key = 'profile_id';
```

Значение хранится как текст, его нужно преобразовать в integer и найти в `profiles.id`.

Linux-пути (`source_path`, `executable_path`) показывать как справочные строки. Не преобразовывать их в Windows-пути и не пытаться открывать локально.

### Идентичность страницы

Уникальная страница определяется комбинацией:

```text
profile_id
name
section
language
locale
```

`locale` может быть `NULL`. Для сравнения считать `NULL` эквивалентом пустого значения:

```sql
COALESCE(locale, '')
```

Одинаковое имя в разных разделах — разные страницы. Например, `printf(1)` и `printf(3)` должны отображаться отдельно.

Рекомендуемый пользовательский идентификатор:

```text
name(section)
```

При нескольких языках дополнительно показывать locale или language.

### Тексты и кодировки

Все строки уже преобразованы в Unicode и нормализованы в NFC. Windows ANSI code page использовать нельзя.

Поля декодирования:

```text
source_encoding
decode_status
decode_error_count
contains_replacement_chars
```

Возможные `decode_status`:

```text
exact
fallback
replaced
```

`contains_replacement_chars=1` означает наличие U+FFFD.

`plain_text` может быть `NULL`, если renderer отсутствовал или завершился ошибкой. `roff_content` также может быть `NULL`, если база собиралась с `--exclude-roff`.

Windows-клиент не должен исполнять или интерпретировать roff как код. Для основного просмотра использовать `plain_text` и `sections.content`.

### Секции страницы

Секции находятся в таблице `sections` и сортируются только по:

```sql
ORDER BY section_order
```

Поля:

```text
original_name
normalized_name
content
```

Не сортировать секции по названию. Повторяющиеся секции допустимы. Неизвестные секции сохраняются как `OTHER`.

Нормализованные значения:

```text
NAME
SYNOPSIS
DESCRIPTION
OPTIONS
COMMANDS
EXAMPLES
FILES
ENVIRONMENT
EXIT_STATUS
RETURN_VALUE
ERRORS
NOTES
BUGS
SECURITY
WARNINGS
SEE_ALSO
AUTHORS
COPYRIGHT
OTHER
```

`summary` и `SYNOPSIS` могут отсутствовать. Это нормальная ситуация, а не повреждение базы.

### Aliases

Alias не обязательно имеет собственную строку в `pages`.

Таблица `aliases.page_id` указывает на конечную целевую страницу. Поэтому поиск alias выполняется через join:

```sql
SELECT
    a.alias,
    a.alias_type,
    a.alias_section,
    a.alias_language,
    p.*
FROM aliases AS a
JOIN pages AS p ON p.id = a.page_id
WHERE a.alias = ?;
```

Возможные основные типы:

```text
symlink
so
```

Одинаковый alias может существовать в разных section, language или locale. Нельзя выбирать результат только по имени.

### SEE ALSO и relations

Таблица `relations` хранит ссылки, извлечённые из SEE ALSO:

```text
source_page_id
target_name
target_section
relation_type = see_also
```

Целевая страница может отсутствовать в базе. Для `target_name` и `target_section` специально нет foreign key.

При переходе сначала искать точное совпадение имени и раздела в том же профиле, предпочтительно в той же locale/language. Если точного совпадения нет — показать ссылку как недоступную, а не переходить на случайную страницу.

### Поиск FTS5

FTS-таблица называется `page_fts` и индексирует:

```text
name
title
summary
plain_text
sections_content
```

`page_id` — неиндексируемое служебное поле.

Базовый поиск:

```sql
SELECT p.*, bm25(page_fts) AS rank
FROM page_fts
JOIN pages AS p ON p.id = page_fts.page_id
WHERE page_fts MATCH ?
ORDER BY rank;
```

Пользовательский запрос нельзя вставлять в SQL строковой конкатенацией. Передавать через параметр.

FTS5 использует `unicode61`, поэтому русский и английский текст поддерживаются, но морфологического анализа и русского стемминга нет. Например, разные падежи русского слова автоматически не считаются одним термином.

Ошибочный FTS-синтаксис пользователя — кавычки, незакрытые выражения, операторы — должен обрабатываться без аварии UI. Можно предложить безопасный literal-поиск с экранированием кавычек.

### Обычный поиск без FTS

Если Windows SQLite собран без FTS5, клиент может работать в ограниченном режиме через `pages` и `aliases`, но должен явно сообщить, что полнотекстовый поиск недоступен.

Пример точного поиска:

```sql
SELECT *
FROM pages
WHERE profile_id = ?
  AND name = ?
ORDER BY
    CAST(section AS INTEGER),
    section,
    language,
    COALESCE(locale, '');
```

Нельзя полагаться только на `CAST(section AS INTEGER)`, поскольку допустимы разделы `n` и `l`.

### Пакеты

`package_id` может быть `NULL`, особенно для `/usr/local` и пользовательских man-страниц.

Информация о пакете:

```sql
SELECT pkg.*
FROM pages AS p
LEFT JOIN packages AS pkg ON pkg.id = p.package_id
WHERE p.id = ?;
```

Отсутствие пакета не является ошибкой.

### Command info

`command_info` собирается только при включённом `--collect-help`, поэтому запись может отсутствовать.

Поля `version_text` и `help_text` являются данными для показа. Их нельзя исполнять, интерпретировать как команды или без экранирования вставлять в HTML/WebView.

`is_available` отражает состояние команды на Linux-машине во время сборки базы, а не на текущем Windows-компьютере.

### Ошибки сборки

`build_errors` содержит локальные ошибки отдельных страниц:

```text
source_path
stage
error_code
message
created_at
```

Наличие записей не означает, что вся база повреждена. При update история ошибок может накапливаться и содержать повторные записи.

Для определения пригодности базы использовать integrity, foreign keys, schema version и checksum.

### Безопасность Windows-клиента

Все тексты базы считать недоверенными данными:

- не исполнять команды и примеры;
- не открывать Linux-пути автоматически;
- не интерпретировать roff как код;
- экранировать текст перед вставкой в HTML/WebView;
- параметризовать SQL;
- ограничивать объём отображаемого текста;
- не загружать внешние URL без явного действия пользователя.

### Работа с файлом

Клиент должен открывать завершённый SQLite-файл в read-only режиме. Не копировать базу во время активной сборки или update.

Предпочтительный SQLite URI:

```text
file:path-to-database.sqlite?mode=ro
```

Желательно не включать immutable-режим до проверки, что файл действительно не изменяется другим процессом.

Тестовая база текущей разработки:

```text
/tmp/manbase.sqlite
```

Она находится на Linux VM и не входит в release-комплект. Для Windows нужно передать отдельную завершённую копию файла.
