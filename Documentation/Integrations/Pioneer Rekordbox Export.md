# Назначение

Этот документ фиксирует целевой формат записи USB-флешек Pioneer/AlphaTheta для дек и результат разбора образцов rekordbox export.

Цель интеграции — генерировать структуру `PIONEER` из плейлистов BurningTrack так, чтобы её понимал максимально широкий спектр CDJ/XDJ/AlphaTheta дек.
BurningTrack является источником истины: фича не читает и не синхронизирует чужие плейлисты rekordbox.

# Используемая технология

USB-экспорт для дек состоит из нескольких независимых форматов.

Форматы первого целевого этапа:

- `rekordbox/export.pdb` — legacy DeviceSQL-база rekordbox export.
- `rekordbox/exportExt.pdb` — DeviceSQL-база расширенных данных.
- `USBANLZ/**/ANLZ0000.DAT`, `.EXT`, `.2EX` — файлы анализа треков. В первой версии они нужны как совместимые контейнеры, а не как полноценный waveform/beat grid анализ.
- `MYSETTING.DAT`, `MYSETTING2.DAT`, `DJMMYSETTING.DAT`, `djprofile.nxs` — пользовательские настройки и профиль.

Форматы вне первого этапа:

- `rekordbox/exportLibrary.db`, `exportLibrary.db-wal`, `exportLibrary.db-shm` — Device Library Plus для новых устройств, зашифрованная SQLite/SQLCipher-база.
- `extracted/gcred.dat` — base64-данные, связанные с зашифрованной Device Library Plus базой.

В образце отсутствует папка `/Contents` с самими аудиофайлами, но пути к ним сохранены в `export.pdb` и `ANLZ`.

# Как подключена

Интеграция пока не подключена к коду приложения.

Текущее состояние — reverse-engineering карта форматов и целевой контракт для будущего writer.

# Границы первой версии

Первая версия создаёт USB-структуру для дек заново.
Существующая структура на целевом носителе не обновляется инкрементально и не сливается с уже записанными данными.

В scope первой версии входит:

- запись плейлистов BurningTrack в `export.pdb`;
- запись всех уникальных треков, входящих в экспортируемые плейлисты;
- сохранение порядка треков внутри плейлистов;
- копирование аудиофайлов в `PIONEER/Contents`;
- создание минимально валидных `ANLZ`-контейнеров для связки трека с анализ-файлами;
- создание минимальных настроек и профиля.

В scope первой версии не входит:

- импорт плейлистов rekordbox;
- совместимость с rekordbox Desktop как основная цель;
- Device Library Plus и запись `exportLibrary.db*`;
- инкрементальное обновление существующей флешки;
- полноценная генерация waveform, beat grid, hot cues и memory cues.

Waveform и анализ аудио являются следующим этапом после того, как деки начнут видеть плейлисты, порядок треков и сами аудиофайлы.

# Целевая совместимость

Цель — поддержать максимально широкий спектр дек через общий legacy rekordbox USB export.
Не предполагается, что все поколения дек используют полностью одинаковый формат.

Writer должен генерировать общий нижний слой (`export.pdb` и `ANLZ0000.DAT`) и расширенные файлы (`.EXT`, `.2EX`), которые новые деки могут использовать, а старые могут игнорировать.
Совместимость с конкретными моделями должна подтверждаться на реальном железе и golden-файлами, а не предположением о едином формате.

# Подтверждённая структура образца

## Корневая структура

```text
PIONEER/
├── rekordbox/
│   ├── export.pdb
│   ├── exportExt.pdb
│   ├── exportLibrary.db
│   ├── exportLibrary.db-shm
│   └── exportLibrary.db-wal
├── USBANLZ/
│   ├── P016/00021E44/
│   │   ├── ANLZ0000.DAT
│   │   ├── ANLZ0000.EXT
│   │   └── ANLZ0000.2EX
│   └── P021/00022D21/
│       ├── ANLZ0000.DAT
│       ├── ANLZ0000.EXT
│       └── ANLZ0000.2EX
├── MYSETTING.DAT
├── MYSETTING2.DAT
├── DJMMYSETTING.DAT
├── djprofile.nxs
└── extracted/gcred.dat
```

Пути `USBANLZ/P016/00021E44` и `USBANLZ/P021/00022D21` хранятся в `export.pdb` как `analyze_path`.
Для совместимости важна согласованность пути в базе и фактического файла анализа.
Алгоритм выбора имён папок rekordbox по двум образцам не доказан, поэтому будущий генератор должен использовать собственный детерминированный путь и записывать его во все связанные места.

## export.pdb

`export.pdb` — little-endian DeviceSQL-файл с фиксированными страницами по 4096 байт.

Первый блок содержит:

- размер страницы;
- количество таблиц;
- индекс следующей свободной страницы;
- sequence;
- список таблиц с типом, первой и последней страницей.

Страницы таблиц устроены как page header, heap с row-данными и индекс строк в конце страницы. Индекс строк идёт с конца страницы назад и содержит bitmap присутствующих строк. Удалённые или отсутствующие строки нельзя читать как валидные данные.

В образце:

| Таблица | Тип | Строк |
| --- | ---: | ---: |
| tracks | 0 | 2 |
| colors | 6 | 8 |
| columns | 16 | 27 |
| unknown_17 | 17 | 22 |
| unknown_18 | 18 | 17 |
| history | 19 | 1 |

Остальные основные справочники (`genres`, `artists`, `albums`, `labels`, `keys`, `artwork`, `playlist_tree`, `playlist_entries`) пустые.

Подтверждённые треки:

| id | title | filename | file_path | analyze_path | BPM | duration |
| ---: | --- | --- | --- | --- | ---: | ---: |
| 1 | Отрывок 1 | Отрывок 1.m4a | `/Contents/UnknownArtist/UnknownAlbum/Отрывок 1.m4a` | `/PIONEER/USBANLZ/P016/00021E44/ANLZ0000.DAT` | 124.21 | 5 |
| 2 | Отрезок 2 | Отрезок 2.m4a | `/Contents/UnknownArtist/UnknownAlbum/Отрезок 2.m4a` | `/PIONEER/USBANLZ/P021/00022D21/ANLZ0000.DAT` | 128.68 | 7 |

Числовой BPM хранится как BPM × 100.
Строки DeviceSQL бывают как минимум в трёх вариантах: short ASCII, long ASCII и long UTF-16LE.
Кириллические поля в образце записаны как UTF-16LE.

## exportExt.pdb

`exportExt.pdb` использует тот же DeviceSQL-контейнер, но другой набор типов страниц.

В образце:

| Таблица | Тип | Строк |
| --- | ---: | ---: |
| tags | 3 | 28 |
| tag_tracks | 4 | 0 |
| unknown_7 | 7 | 1 |

`tags` содержит стандартный My Tag справочник:

- `Genre`: Acid House, Deep House, Techno, Nu Disco, Electro House, Bass Music, Trap.
- `Components`: Synth, Vocal, Beat, Sub Bass, Percussion, Piano, Dark, Upper.
- `Situation`: Main Floor, Second Floor, Lounge, Mid Night, Morning, Build up, Peak Time, Build down.
- `Untitled Column`: My Comment.

`tag_tracks` пустая, поэтому в образце теги не привязаны к трекам.

## ANLZ

Все `ANLZ` файлы big-endian и начинаются с `PMAI`.
Заголовок образцов имеет длину 28 байт.
После заголовка идёт последовательность tagged sections:

```text
fourcc: 4 байта
len_header: 4 байта
len_tag: 4 байта
body: len_tag - 12 байт
```

`ANLZ0000.DAT` содержит базовые данные для старых устройств:

| Section | Назначение |
| --- | --- |
| `PPTH` | UTF-16BE путь к аудиофайлу |
| `PVBR` | VBR seek index |
| `PQTZ` | beat grid |
| `PWAV` | waveform preview |
| `PWV2` | tiny waveform |
| `PCOB` | hot cues и memory cues |

`ANLZ0000.EXT` содержит расширенные данные:

| Section | Назначение |
| --- | --- |
| `PPTH` | путь к аудиофайлу |
| `PWV3` | waveform scroll |
| `PCOB` | legacy cue списки |
| `PCO2` | extended cue списки |
| `PQT2` | extended beat grid |
| `PWV5` | color waveform scroll |
| `PWV4` | color waveform preview |

`ANLZ0000.2EX` содержит CDJ-3000/новые waveform-данные:

| Section | Назначение |
| --- | --- |
| `PPTH` | путь к аудиофайлу |
| `PWV7` | 3-band waveform scroll |
| `PWV6` | 3-band waveform preview |
| `PWVC` | metadata для цветной waveform |

Для первой версии writer может создавать минимальные `ANLZ`-файлы без полноценного анализа аудио.
Полноценное заполнение waveform и beat grid должно появиться после подтверждения базовой записи плейлистов на деках.

Подтверждённые параметры анализа:

| Трек | DAT beat count | DAT first beat | DAT last beat | EXT/PQT2 count | Wave scroll entries |
| --- | ---: | ---: | ---: | ---: | ---: |
| Отрывок 1 | 11 | 217 ms | 5047 ms | 11 | 794 |
| Отрезок 2 | 16 | 430 ms | 7424 ms | 16 | 1127 |

Cue-списки в образце пустые.
Для пустого `.DAT` cue-блока `PCOB` присутствует два раза: hot cues (`type = 1`) и memory cues (`type = 0`).
В `.EXT` дополнительно присутствуют пустые `PCO2` для тех же двух списков.

## exportLibrary.db

`exportLibrary.db` в образце не является открытой SQLite-базой: первый блок выглядит как зашифрованные данные, а `exportLibrary.db-wal` содержит обычную WAL-обвязку с зашифрованными страницами.

Это соответствует Device Library Plus: SQLite-база, зашифрованная SQLCipher.
Её генерация может понадобиться для отдельного слоя совместимости с новыми устройствами, но она не входит в первый этап.
Первый этап сознательно строится вокруг legacy `export.pdb` и `ANLZ`, потому что это воспроизводимый незашифрованный путь для USB-флешек дек.

`gcred.dat` — base64-строка длиной 66 байт, декодируется в 48 байт бинарных данных.
Назначение этих 48 байт в рамках образца не доказано.

## My Settings и профиль

`MYSETTING.DAT`, `MYSETTING2.DAT`, `DJMMYSETTING.DAT` имеют общий header:

- 4 байта длины строкового блока;
- 32 байта brand (`PIONEER` или `PioneerDJ`);
- 32 байта software (`rekordbox`);
- 32 байта version;
- 4 байта длины body;
- body фиксированной длины;
- 4 байта footer/checksum.

В образце:

| Файл | Brand | Version | Body |
| --- | --- | --- | ---: |
| `MYSETTING.DAT` | PIONEER | 0.001 | 40 байт |
| `MYSETTING2.DAT` | PIONEER | 0.001 | 40 байт |
| `DJMMYSETTING.DAT` | PioneerDJ | 1.000 | 52 байта |

`djprofile.nxs` — 160 байт.
Имя профиля `Pavel Fomin` находится со смещения `0x20`.

# Какие подсистемы используют

Будущий writer должен быть отделён от UI и текущего простого экспорта файлов.

Рекомендуемые зоны ответственности:

- Export feature — запускает пользовательский сценарий записи USB и отдаёт результат через существующий feedback-контракт.
- Domain/Integration слой — собирает модель Deck USB Export из треков и плейлистов BurningTrack.
- Binary writer слой — пишет DeviceSQL, ANLZ и настройки без зависимости от SwiftUI.
- ViewModel/ActionHandler — инициирует сценарий по MVVM-канону, но не знает бинарный формат.

# Минимальный генератор

Первым этапом нужно доказать запись плейлистов для дек:

1. Собрать внутреннюю модель экспорта из плейлистов BurningTrack.
2. Скопировать все уникальные аудиофайлы в `PIONEER/Contents/<artist>/<album>/<filename>`.
3. Создать `rekordbox/export.pdb` с таблицами `tracks`, `playlist_tree`, `playlist_entries`, `colors` и обязательными служебными таблицами.
4. Создать `rekordbox/exportExt.pdb` в минимальном варианте. My Tag справочник можно записывать без привязок, если теги не экспортируются.
5. Для каждого трека создать `USBANLZ/<bucket>/<id>/ANLZ0000.DAT`, `.EXT`, `.2EX`.
6. В `PPTH` каждого `ANLZ` записать путь к аудиофайлу из `PIONEER/Contents`.
7. Записать пустые или минимальные cue-блоки, чтобы структура файлов соответствовала rekordbox export.
8. Создать `MYSETTING.DAT`, `MYSETTING2.DAT`, `DJMMYSETTING.DAT`, `djprofile.nxs` с дефолтами или пользовательскими настройками.

Критерий успеха первого этапа: деки видят носитель, плейлисты, порядок треков и могут загрузить аудиофайлы.

Следующие этапы:

1. Генерация waveform preview и scroll sections.
2. Генерация beat grid (`PQTZ`, `PQT2`).
3. Запись hot cues и memory cues.
4. Device Library Plus (`exportLibrary.db*`) как отдельный слой совместимости.

# Ограничения

- По двум образцам нельзя доказать алгоритм генерации папок `USBANLZ/Pxxx/<hex>`. Для совместимости достаточно, чтобы путь был детерминированным и одинаково записан в `export.pdb` и файловой структуре.
- В образце нет аудиофайлов из `/Contents`, поэтому byte-for-byte воспроизведение полного USB-носителя невозможно.
- В waveform-секциях хранятся результаты анализа аудио. Для первого этапа они не являются критерием успеха, но для профессионального результата генератор должен уметь строить waveform и beat grid.
- `exportLibrary.db*` зашифрован. Без отдельного SQLCipher-этапа его можно только копировать как уже готовый артефакт, но нельзя корректно синтезировать.
- Проверка интеграции должна идти unit-тестами и golden-файлами. Симуляторы для тестирования не используются.

# Правила обновления

- Любое изменение генератора должно иметь readback-тест: созданный файл должен читаться обратно в ту же модель.
- Для `PDB` проверять header, таблицы, page chain, row index bitmap и строки.
- Для `ANLZ` проверять `PMAI`, `len_file`, последовательность section, `len_header`, `len_tag` и связанные пути.
- Для `MYSETTING` проверять header, длину body и footer/checksum.
- Byte-for-byte сравнение использовать только для полностью детерминированных fixtures.

# Связанные документы

- [Export](../Features/Export.md)
- [Development Rules](../Developer/Development%20Rules.md)
- [Documentation Rules](../Developer/Documentation%20Rules.md)

# Источники

- [Deep Symmetry Crate Digger](https://github.com/Deep-Symmetry/crate-digger)
- [rekordbox_pdb.ksy](https://raw.githubusercontent.com/Deep-Symmetry/crate-digger/main/src/main/kaitai/rekordbox_pdb.ksy)
- [rekordbox_anlz.ksy](https://raw.githubusercontent.com/Deep-Symmetry/crate-digger/main/src/main/kaitai/rekordbox_anlz.ksy)
- [Pyrekordbox: Rekordbox 6 Database Format](https://pyrekordbox.readthedocs.io/en/latest/formats/db6.html)
- [Pyrekordbox: Analysis Files Format](https://pyrekordbox.readthedocs.io/en/latest/formats/anlz.html)
- [Pyrekordbox: My-Setting Files Format](https://pyrekordbox.readthedocs.io/en/latest/formats/mysetting.html)
- [Pyrekordbox: Device Library Plus Format](https://pyrekordbox.readthedocs.io/en/latest/formats/devicelib_plus.html)
