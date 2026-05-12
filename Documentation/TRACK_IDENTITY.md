# Разделение row identity и file identity в TrackList

## Зачем сделан рефакторинг

Рефакторинг разделяет идентичность реального файла и идентичность конкретной строки в UI. До разделения один и тот же `id` использовался и как идентификатор файла, и как идентификатор строки списка. Это ломало сценарии, где один файл добавлен несколько раз.

Основные причины:

- баг с дублями одного трека: два вхождения одного файла не могли стабильно жить как две разные строки;
- SwiftUI duplicate ID warning: `ForEach` получал одинаковые идентификаторы для разных строк;
- склейка UI-состояния строк: selection, highlight, sheet identity и другое состояние могли переезжать между дублями;
- неправильное смешение файла и строки списка: операции над реальным файлом и операции над конкретным вхождением использовали один и тот же ключ.

После рефакторинга каждая строка получает собственный row id, а реальный файл сохраняет стабильный `trackId`.

## Основные понятия

- `trackId` — id реального файла из `TrackRegistry`.
- `queueItemId` — id конкретного вхождения в плеере.
- `listItemId` — id конкретного вхождения в треклисте.
- `id` в `TrackDisplayable` — row/display identity, то есть идентичность конкретной отображаемой строки.

## Контракты моделей

### PlayerTrack

- `PlayerTrack.id == queueItemId`.
- `PlayerTrack.trackId == file identity`.

`PlayerTrack.id` различает конкретные вхождения в очереди плеера. `PlayerTrack.trackId` указывает на реальный файл.

### Track

- `Track.id == listItemId`.
- `Track.trackId == file identity`.

`Track.id` различает конкретные строки треклиста. `Track.trackId` указывает на реальный файл.

### LibraryTrack

- `LibraryTrack.id == trackId`.
- `LibraryTrack.trackId == id`.

В библиотеке строка представляет сам файл, поэтому row identity и file identity совпадают.

## Когда использовать `.id`

`.id` используется только для row-facing логики, где нужно работать с конкретным отображаемым вхождением:

- `ForEach`;
- `isCurrent`;
- `playNextTrack`;
- `playPreviousTrack`;
- swipe/delete конкретной строки;
- reorder;
- selection;
- highlighted row;
- sheet identity.

Практическое правило: если действие должно отличать первый дубль файла от второго дубля того же файла, нужен `.id`.

## Когда использовать `.trackId`

`.trackId` используется для file-facing логики, где нужно работать с реальным файлом, его метаданными, runtime-состоянием или операциями над файлом:

- `BookmarkResolver`;
- `TrackRegistry`;
- `TrackRuntimeStore`;
- `TrackRuntimeSnapshotBuilder`;
- `ArtworkProvider`;
- `PlayerManager.currentTrackId`;
- `PlayerManager.isBusy`;
- export;
- move/rename;
- tag editing;
- Track Detail;
- Toast metadata;
- badge membership;
- navigation show in library.

Практическое правило: если действие должно найти файл, обложку, snapshot, bookmark, теги или metadata, нужен `.trackId`.

## Правила добавления

- Добавление в плеер всегда создаёт новый `queueItemId`.
- Добавление в треклист всегда создаёт новый `listItemId`.
- `trackId` всегда сохраняет id реального файла.
- `PlayerTrack -> Track` не переносит `queueItemId` как `listItemId`.
- `LibraryTrack -> Track/PlayerTrack` создаёт новый row id.

Эти правила гарантируют, что один и тот же файл можно добавить несколько раз, а каждое добавление будет отдельным UI-вхождением.

## Правила удаления

- Из плеера удалять по `queueItemId`.
- Из треклиста удалять по `listItemId`.
- После нахождения строки использовать её `trackId` для snapshot/toast/artwork.

Удаление по row id удаляет только конкретное вхождение. Удаление по `trackId` удалило бы все дубли одного файла, если это не является явно ожидаемым поведением.

## Persistence contract

- `player.json` хранит `queueItemId + trackId`.
- `tracklist_*.json` хранит `listItemId + trackId`.
- Legacy decode старого `id` трактует его как `trackId` и создаёт новый row id.

Persistence обязан сохранять и row identity, и file identity. Старый формат не имел отдельной row identity, поэтому при миграции старый `id` считается идентификатором файла, а row id создаётся заново.

## Highlight/current

- `highlightedRowID` хранит row identity.
- `currentTrackDisplayable.id` используется для конкретного вхождения.
- `currentTrackDisplayable.trackId` используется для файла.
- `PlayerManager.currentTrackId` хранит file identity.

Current/highlight состояние должно различать конкретное вхождение в списке. Runtime-состояние плеера и файла при этом должно продолжать ссылаться на file identity.

## Запрещённые паттерны

- Не использовать `track.id` в `BookmarkResolver`.
- Не использовать `track.id` в `TrackRegistry`.
- Не использовать `tracks.map { $0.id }` для сохранения `player.json`.
- Не удалять дубли через `removeAll { $0.trackId == ... }`, если нужно удалить одно вхождение.
- Не использовать `trackId` как SwiftUI row id в плеере/треклисте.

## Ручные тесты

Проверить после изменений identity:

- один файл дважды в плеере;
- один файл дважды в треклисте;
- play/pause каждого дубля;
- next/previous между дублями;
- удаление одного дубля;
- Track Detail;
- Move sheet;
- Show in Library;
- перезапуск приложения и проверка сохранённых дублей.
