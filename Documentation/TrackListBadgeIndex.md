# TrackListBadgeIndex

## Назначение

`TrackListBadgeIndex` фиксирует отдельный контур для отображения бейджей треклистов в фонотеке.

Бейдж треклиста показывает, в каких треклистах уже находится трек. Эти данные нужны строкам фонотеки, но они не являются частью первичной загрузки треков, runtime metadata или синхронизации папки.

Цель индекса:

- быстро отдавать названия треклистов по `trackId`;
- не перечитывать JSON при построении каждой строки;
- обновлять бейджи после изменений треклистов без перезагрузки треков;
- отделить membership треклистов от metadata, availability и sync.

## Проблема старой реализации

Старая реализация `DefaultTrackListBadgeProvider` считала бейджи напрямую из файлов:

```text
LibraryTracksViewModel
→ DefaultTrackListBadgeProvider.badges(for:)
→ tracklists.json
→ каждый tracklist_<id>.json
→ результат для UI
```

Такой подход смешивал отображение бейджей с файловым хранилищем треклистов.

Проблемы:

- provider повторно читал `tracklists.json`;
- provider проходил по всем `tracklist_<id>.json`;
- расчёт бейджей зависел от скорости файлового чтения;
- бейджи появлялись позже, если перед ними выполнялась синхронизация папки;
- UI не имел отдельного быстрого источника membership-данных;
- обновление бейджей было связано с refresh фонотеки сильнее, чем с изменением треклистов.

## Новая архитектура

В новой архитектуре чтение JSON остаётся в storage-слое треклистов, а UI получает бейджи через индекс.

```text
TrackList storage
→ TrackListBadgeIndex
→ TrackListBadgeProvider
→ LibraryTracksViewModel.trackListNamesById
→ TrackRowView
```

Ответственность разделена так:

- `TrackListManager` и `TrackListsManager` сохраняют треки и метаданные треклистов;
- `TrackListBadgeIndex` строит быстрый индекс membership по `trackId`;
- `TrackListBadgeProvider` отдаёт готовые данные из индекса;
- `LibraryTracksViewModel` обновляет только `trackListNamesById`;
- UI только отображает переданные названия треклистов.

## TrackListBadgeIndex

`TrackListBadgeIndex` является runtime-индексом membership треков в треклистах.

Индекс хранит данные в форме:

```text
trackId
→ [название треклиста]
```

или в расширенной внутренней форме:

```text
trackId
→ [trackListId]
trackListId
→ name
```

Внешний контракт для UI остаётся простым: по списку `trackId` вернуть названия треклистов.

Индекс строится из текущего состояния треклистов:

- списка meta из `tracklists.json`;
- содержимого `tracklist_<id>.json`;
- поля `track.trackId` у элементов треклиста.

Чтение JSON выполняется только во время построения или перестроения индекса. Оно не должно выполняться на каждый запрос бейджей из UI.

## TrackListBadgeProvider

`TrackListBadgeProvider` остаётся интерфейсом для `LibraryTracksViewModel`.

Его задача:

- принять `[UUID]` треков;
- вернуть `[UUID: [String]]`;
- не знать, где физически лежат JSON-файлы;
- не выполнять файловое чтение при каждом вызове.

`DefaultTrackListBadgeProvider` должен использовать `TrackListBadgeIndex`, а не читать `tracklists.json` и `tracklist_<id>.json` напрямую.

Это важно, потому что provider находится рядом с UI-потоком. Он должен быть быстрым адаптером, а не storage-reader.

## Обновление индекса

Индекс обновляется от событий треклистов.

Используются Notification:

- `.trackListsDidChange` — изменился список треклистов, meta или имя;
- `.trackListTracksDidChange` — изменились треки внутри конкретного треклиста.

Событие `.trackListsDidChange` важно для:

- создания треклиста;
- удаления треклиста;
- переименования треклиста;
- массового сохранения meta.

Событие `.trackListTracksDidChange` важно для:

- добавления треков в треклист;
- удаления треков из треклиста;
- очистки треклиста;
- сохранения содержимого конкретного `tracklist_<id>.json`.

Базовая последовательность:

```text
Изменение треклиста
→ Notification
→ TrackListBadgeIndex.rebuild()
→ LibraryTracksViewModel.reloadTrackListBadges()
→ обновление UI
```

Индекс должен учитывать, что при создании нового треклиста файл треков может быть сохранён до появления meta. Поэтому событие `.trackListTracksDidChange` не заменяет `.trackListsDidChange`; оба события нужны.

## Обновление UI

`LibraryTracksViewModel` не должен перезагружать треки ради бейджей.

При изменении треклистов обновляется только:

```text
trackListNamesById
```

`trackSections` не меняется.

Это сохраняет текущий список, порядок секций, позицию прокрутки и состояние строк. Обновляется только дополнительная информация строки.

UI-поток:

```text
Notification
→ LibraryTracksViewModel.reloadTrackListBadges()
→ trackListNamesById
→ LibraryTrackRowWrapper
→ TrackRowView
```

## Поток загрузки LibraryTracksViewModel

Открытие папки должно оставаться быстрым.

Первичный список треков строится отдельно от тяжёлых деталей:

```text
Открытие папки
→ быстрый список треков
→ бейджи из индекса
→ runtime metadata
→ availability/sync
```

Подробный поток:

```text
LibraryTracksViewModel.loadTracksIfNeeded()
→ refresh()
→ loadInitialTracks()
→ trackSections
→ первый показ списка
→ loadDetailsInBackground()
→ reloadTrackListBadges()
→ syncFolderIfNeeded(...)
→ updateAvailabilityInBackground()
```

Бейджи загружаются сразу после появления `trackSections`.

Синхронизация папки не должна блокировать отображение бейджей, потому что membership треклистов уже хранится в индексе и не зависит от обхода файловой системы.

Runtime metadata также не должна блокировать бейджи. Теги, обложки, длительность и availability относятся к деталям трека, а не к membership треклистов.

## Почему используется trackId

Индекс строится по `trackId`, потому что это стабильная идентичность музыкального трека в фонотеке.

В разных моделях могут быть разные UUID:

- `LibraryTrack.id` — идентификатор трека в фонотеке;
- `Track.trackId` — идентификатор исходного трека внутри элемента треклиста;
- `Track.listItemId` / `Track.id` — идентификатор конкретного вхождения в треклисте.

Для бейджей важен именно вопрос:

```text
В каких треклистах находится этот трек фонотеки?
```

Ответ должен строиться по `trackId`, а не по идентификатору строки или конкретного вхождения.

Если один и тот же трек добавлен в треклист несколько раз, бейдж всё равно показывает название треклиста один раз. Поэтому индекс должен группировать данные по `trackId` и дедуплицировать названия треклистов.

## Итог

`TrackListBadgeIndex` отделяет бейджи треклистов от файлового чтения и от загрузки фонотеки.

Финальная архитектура:

- storage-слой сохраняет JSON и публикует события;
- индекс перестраивает membership по событиям;
- provider отдаёт готовые данные из индекса;
- `LibraryTracksViewModel` обновляет только `trackListNamesById`;
- UI отображает бейджи без перезагрузки треков.

Ключевой принцип:

```text
Изменились треклисты
→ обновляем индекс и бейджи
→ не перезагружаем фонотеку
```
