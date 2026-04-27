# Metadata Architecture

## Overview

Metadata трека в runtime обновляется через единый snapshot pipeline. UI, ViewModel и sheet больше не перечитывают теги напрямую из файла после save и не используют `TrackMetadataCacheManager` как публичный контракт.

Текущая цепочка:

`TagLib / low-level readers`
-> `TrackRuntimeSnapshotBuilder`
-> `TrackRuntimeSnapshot`
-> `TrackRuntimeStore`
-> `TrackUpdateCoordinator`
-> `Notification.Name.trackDidUpdate` / `TrackUpdateEvent`
-> `UI / ViewModels`

# Runtime metadata update architecture

## Source of truth

`TrackRuntimeSnapshot` — единый runtime source of truth для актуальных metadata трека после чтения файла.

Snapshot содержит:

- `fileName`
- `title` / `artist` / `album` / `genre` / `comment`
- расширенные поля sheet: `albumArtist`, `composer`, `conductor`, `lyricist`, `remixer`, `grouping`, `bpm`, `musicalKey`, `trackNumber`, `totalTracks`, `discNumber`, `totalDiscs`, `year`, `date`, `publisherOrLabel`, `copyright`, `encodedBy`, `isrc`
- `duration`
- `artworkData`
- `isAvailable`
- `updatedAt`

UI не читает metadata напрямую из файла. UI получает уже собранный `TrackRuntimeSnapshot` из `TrackRuntimeStore`, из `TrackUpdateEvent` или через `TrackRuntimeSnapshotBuilder` как часть runtime pipeline.

`UIImage` не хранится в snapshot. Snapshot хранит только raw `Data` в `artworkData`. `UIImage` создаётся через `ArtworkProvider` как производное представление для конкретного `ArtworkPurpose`.

## Update pipeline

После изменения тегов, artwork, rename или move используется единый post-update pipeline:

1. `AppCommandExecutor` выполняет пользовательскую команду.
2. Низкоуровневый writer или file manager меняет файл, путь или реестр.
3. `AppCommandExecutor` вызывает `TrackUpdateCoordinator`.
4. `TrackUpdateCoordinator` инвалидирует technical caches.
5. `TrackRuntimeSnapshotBuilder` перечитывает файл и собирает новый `TrackRuntimeSnapshot`.
6. `TrackRuntimeStore` сохраняет snapshot.
7. `TrackUpdateCoordinator` публикует `TrackUpdateEvent` через `.trackDidUpdate`.
8. `PlayerViewModel`, `TrackListViewModel`, `LibraryTracksViewModel` и `TrackDetailContainer` применяют snapshot.

## Removed legacy pipeline

Старая схема обновления metadata удалена и не является актуальной архитектурой:

- `.trackMetadataDidChange` больше не используется.
- `TrackTagInspector` удалён.
- Sheet больше не делает post-save reread.
- UI/ViewModel больше не вызывают `TrackMetadataCacheManager.shared.loadMetadata`.
- `metadataByTrackId`, `requestMetadataIfNeeded` и `reloadMetadata` удалены.
- `TrackMetadataCacheManager` больше не является UI-facing контрактом.

## File roles

`TrackRuntimeSnapshot.swift`
: Каноничная runtime-модель metadata трека. Хранит значения тегов, duration, `artworkData`, доступность и время сборки. Не содержит `UIImage`, UI-состояние или сериализацию.

`TrackUpdateEvent.swift`
: Payload единого события обновления трека. Несёт `trackId`, `reason`, `changedFields` и новый `TrackRuntimeSnapshot`.

`TrackUpdateReason.swift`
: Тип причины обновления: tags, artwork, rename, move, availability, reload, import.

`TrackChangedField.swift`
: Перечень полей snapshot, которые могли измениться. Нужен подписчикам, чтобы понимать затронутую область.

`TrackRuntimeSnapshotBuilder.swift`
: Единственное место runtime pipeline, которое перечитывает файл после update и собирает `TrackRuntimeSnapshot`. Использует low-level readers, `RuntimeMetadataParser` / technical metadata cache и bookmark pipeline. Не публикует события и не обновляет UI.

`TrackRuntimeStore.swift`
: Централизованное runtime-хранилище последних snapshot по `trackId`. Отдаёт snapshot без повторного чтения файла. Не читает файл и не публикует события.

`TrackUpdateCoordinator.swift`
: Post-update orchestration слой. Инвалидирует technical caches, запускает сборку snapshot, сохраняет его в `TrackRuntimeStore` и публикует `TrackUpdateEvent` через `.trackDidUpdate`. Сам не пишет теги и не содержит UI-логики.

`MetadataCacheManager.swift`
: Technical raw metadata cache. Используется как внутренний слой ускорения для runtime pipeline и builder. Не является source of truth и не является публичным контрактом для UI/ViewModel.

`RuntimeMetadataParser.swift`
: Низкоуровневый runtime reader, который получает duration через AVFoundation и теги/artwork через `TLTagLibFile`. Возвращает raw `TrackMetadata` для technical cache и snapshot builder.

`TLTagLibFile.swift`
: Low-level Swift-адаптер над TagLib reader. Читает сырые теги и artwork из файла. Не знает про UI, store, notification или сценарии обновления.

`ArtworkProvider.swift`
: Создаёт `UIImage` из `TrackRuntimeSnapshot.artworkData` как derived representation для конкретного назначения. Делает downsampling и image-cache по `trackId` + `ArtworkPurpose`. Не делает IO и не загружает metadata.

`TrackDetailContainer.swift`
: Контейнер sheet-сценария. Слушает `.trackDidUpdate`, принимает `TrackUpdateEvent` и применяет snapshot к состоянию sheet.

`TrackDetailSheet.swift`
: UI sheet, который отображает данные из `TrackRuntimeSnapshot`. Не выполняет отдельный post-save reread файла.

`PlayerViewModel.swift`
: Хранит и применяет runtime snapshot для текущего плеера, слушает `TrackUpdateEvent` и обновляет player UI / now playing state из snapshot.

`TrackListViewModel.swift`
: Хранит snapshot для строк конкретного треклиста, слушает `TrackUpdateEvent` и обновляет отображение metadata/artwork из snapshot.

`LibraryTracksViewModel.swift`
: Хранит snapshot для строк фонотеки, слушает `TrackUpdateEvent` и обновляет отображение metadata/artwork из snapshot.

## Rules

- После update файл перечитывает только snapshot builder / runtime pipeline.
- UI не вызывает TagLib напрямую.
- UI не вызывает `TrackMetadataCacheManager.shared.loadMetadata`.
- Sheet не делает отдельный reread после save.
- `artworkData` живёт в `TrackRuntimeSnapshot`.
- `UIImage` создаётся только как derived representation.
- Rename, move, tags и artwork идут через единый `TrackUpdateCoordinator`.
- Если нужно обновить metadata трека, публикуется `TrackUpdateEvent`, а не слабое notification с `trackId`.

## Invariants

- `TrackRuntimeSnapshot` — runtime source of truth для экранов.
- `TrackRuntimeStore` хранит последние snapshot, но не читает файлы сам.
- `TrackUpdateCoordinator` публикует только событие с готовым snapshot.
- Technical caches можно инвалидировать и пересобрать без изменения UI-контракта.
- Low-level TagLib readers остаются ниже runtime pipeline и не используются View/ViewModel напрямую.
