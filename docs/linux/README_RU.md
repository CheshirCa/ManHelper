# ManBase Builder: установка и использование

ManBase Builder 0.1.0 — консольная программа для Linux. Она сканирует
установленные man-страницы и создаёт переносимую Unicode SQLite-базу для
ManHelper. В базе сохраняются отрисованный текст, при необходимости исходный
roff, псевдонимы и секции страниц, а также индекс FTS5. Ошибки отдельных
страниц записываются в `build_errors` и не останавливают остальной импорт.

## Требования

- Debian, Ubuntu, Armbian или совместимый дистрибутив Linux;
- Python 3.11 или новее;
- один roff-обработчик: `mandoc`, `groff` или `man`;
- системный `zstd` или необязательный Python-пакет `zstandard` для `.zst`.

Самому Builder права root не нужны. В Debian-совместимой системе рекомендуемые
пакеты можно установить так:

```bash
sudo apt-get update
sudo apt-get install python3 python3-venv groff man-db zstd
```

`mandoc` необязателен; если он установлен, Builder выбирает его раньше `groff`
и `man`:

```bash
sudo apt-get install mandoc
```

## Установка

Из корня репозитория:

```bash
cd linux/manbase-builder
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install .
```

Проверка установки:

```bash
.venv/bin/manbase-builder --help
```

Для разработки и запуска тестов:

```bash
.venv/bin/python -m pip install -e '.[test]'
.venv/bin/python -m pytest
```

## Создание базы

```bash
.venv/bin/manbase-builder \
  --output debian13-amd64.sqlite \
  --profile-name "Debian 13 amd64"
```

Результат — один SQLite-файл. По умолчанию Builder самостоятельно находит
системные man-каталоги и сохраняет исходный roff.

Чтобы сканировать только заданные каталоги или локали, повторяйте `--manpath`
или `--locale`:

```bash
.venv/bin/manbase-builder \
  --output local.sqlite \
  --manpath /usr/local/share/man \
  --locale ru
```

Если указан хотя бы один `--manpath`, стандартные каталоги и команда `manpath`
не используются.

## Обновление, пересборка и проверка

Обновить существующую базу, заменить изменившиеся страницы и удалить
исчезнувшие:

```bash
.venv/bin/manbase-builder --output debian13-amd64.sqlite --update
```

Удалить существующий результат и собрать базу заново:

```bash
.venv/bin/manbase-builder --output debian13-amd64.sqlite --rebuild
```

Проверить существующую базу:

```bash
.venv/bin/manbase-builder --output debian13-amd64.sqlite --validate
```

Успешная проверка возвращает код `0`, неуспешная — `2`.

## Поддерживаемые параметры

```text
--output PATH                 обязательный путь выходной базы
--profile-name NAME           имя профиля новой базы
--manpath PATH                корень man-страниц; можно повторять
--locale LOCALE               фильтр локали/языка; можно повторять
--include-roff                сохранять исходный roff (по умолчанию)
--exclude-roff                не сохранять исходный roff
--collect-help                собирать version/help для команд секции 1
--no-collect-help             не опрашивать команды (по умолчанию)
--update                      обновить существующую базу
--rebuild                     удалить и заново собрать выходную базу
--validate                    проверить базу
--strict-encoding             отклонять запасное декодирование и замены
--max-page-size BYTES         лимит распакованной страницы; по умолчанию 16 МиБ
--renderer mandoc|groff|man   принудительно выбрать обработчик
--verbose                     подробный журнал
--quiet                       подавить обычный вывод
```

Для `--update` база уже должна существовать. `--collect-help` включается только
явно: подходящие команды секции 1 опрашиваются с закрытым stdin, ограничениями
по времени и размеру вывода и списком запретов. Примеры из man-страниц не
исполняются.

## Поиск в полученной базе

Через SQLite CLI:

```bash
sqlite3 debian13-amd64.sqlite \
  "SELECT name, section FROM page_fts WHERE page_fts MATCH 'journal';"
```

Индекс FTS5 с токенизатором `unicode61` включает имена, заголовки, краткие
описания, отрисованный текст и содержимое секций.

## Лицензия

Только некоммерческое использование. См. `LICENSE` в каталоге компонента.
