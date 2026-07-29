# ManHelper

ManHelper — офлайн-помощник для Windows, работающий с PuTTY и KiTTY. Программа
находит Linux-команду в скопированном из терминала тексте и показывает
соответствующую man-страницу из SQLite-базы, открытой только для чтения. В этом
же репозитории находятся Linux-сборщик базы и Windows-валидатор.

[English version](README.md)

## Состав проекта

- [`windows/manhelper`](windows/manhelper) — Windows-приложение в области
  уведомлений;
- [`linux/manbase-builder`](linux/manbase-builder) — Linux CLI для создания
  переносимой базы man-страниц;
- [`windows/validator`](windows/validator) — консольный и графический
  валидаторы базы для Windows;
- [`database_contract.md`](database_contract.md) — контракт формата SQLite;
- [`release-assets`](release-assets) — файлы, подготовленные для публикации
  через GitHub Releases.

## Документация

- [Установка и использование ManHelper (русский)](docs/windows/README_RU.md)
- [ManHelper installation and usage (English)](docs/windows/README_EN.md)
- [Установка и использование ManBase Builder (русский)](docs/linux/README_RU.md)
- [ManBase Builder installation and usage (English)](docs/linux/README_EN.md)

## Как связаны части проекта

ManBase Builder сканирует установленные man-страницы в Linux и создаёт один
переносимый SQLite-файл. ManHelper открывает эту базу в Windows только для
чтения и выполняет поиск по точному имени, псевдонимам и индексу FTS5.
ManBase Validator позволяет проверить базу в Windows перед распространением
или использованием.

ManHelper не исполняет скопированные команды, не имитирует `Ctrl+C` и не
изменяет системную базу man-страниц.

## Релизы

Подготовленный Windows ZIP находится в `release-assets` и предназначен для
загрузки как файл GitHub Release. Несжатая база превышает обычный лимит GitHub
в 100 МиБ на один файл, поэтому её нельзя коммитить в репозиторий как обычный
файл.

## Лицензия

Только некоммерческое использование. См. [LICENSE](LICENSE).

Copyright (C) CheshirCa 2026 — https://t.me/cheshircanest
