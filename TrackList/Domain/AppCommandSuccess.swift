//
//  AppCommandSuccess.swift
//  TrackList
//
//  Типизированные результаты успешного выполнения команд приложения.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Подтверждает перемещение трека и передаёт итоговый snapshot без UI-данных.
struct MoveTrackSuccess {
    let trackId: UUID
    let destinationFolderId: UUID
    let destinationFolderName: String?
    let snapshot: TrackRuntimeSnapshot?
}

/// Подтверждает копирование купленного iTunes-трека в фонотеку.
struct CopyPurchasedITunesTrackSuccess {
    let sourceTrackId: UUID
    let copiedFileURL: URL
    let destinationFolderId: UUID
    let destinationFolderName: String?
}

/// Подтверждает переименование файла и передаёт итоговый snapshot трека.
struct RenameTrackSuccess {
    let trackId: UUID
    let finalFileName: String
    let snapshot: TrackRuntimeSnapshot?
}

/// Подтверждает добавление одного трека в треклист.
struct TrackAddedToTrackListSuccess {
    let addedTrack: Track
    let trackListId: UUID
    let trackListName: String
}

/// Подтверждает массовое добавление файловых треков в треклист.
struct TracksAddedToTrackListSuccess {
    let addedTrackIds: [UUID]
    let trackListId: UUID
    let trackListName: String
}

/// Подтверждает добавление купленных iTunes-треков в треклист.
struct PurchasedITunesTracksAddedToTrackListSuccess {
    let addedTracks: [Track]
    let trackListId: UUID
    let trackListName: String
}

/// Подтверждает создание треклиста.
struct TrackListCreatedSuccess {
    let trackListId: UUID
    let trackListName: String
}

/// Подтверждает переименование треклиста.
struct TrackListRenamedSuccess {
    let trackListId: UUID
    let trackListName: String
}

/// Подтверждает удаление конкретного вхождения трека из треклиста.
struct TrackRemovedFromTrackListSuccess {
    let removedTrack: Track
    let trackListId: UUID
}

/// Подтверждает добавление файлового трека в очередь плеера.
struct TrackAddedToPlayerSuccess {
    let addedTrack: PlayerTrack
    let snapshot: TrackRuntimeSnapshot?
}

/// Подтверждает добавление iTunes-трека в очередь плеера.
struct PurchasedITunesTrackAddedToPlayerSuccess {
    let addedTrack: PlayerTrack
}

/// Подтверждает массовое добавление файловых треков в очередь плеера.
struct TracksAddedToPlayerSuccess {
    let addedTracks: [TrackAddedToPlayerSuccess]
}

/// Подтверждает удаление конкретного вхождения трека из очереди плеера.
struct TrackRemovedFromPlayerSuccess {
    let removedTrack: PlayerTrack
}

/// Подтверждает очистку очереди плеера.
struct PlayerClearedSuccess {}

/// Подтверждает сохранение изменений файла, тегов или обложки трека.
struct TrackEditsSavedSuccess {
    let trackId: UUID
    let finalFileName: String
    let snapshot: TrackRuntimeSnapshot?
    let didUpdateTagsOrArtwork: Bool
}

/// Подтверждает отдельное сохранение тегов или обложки трека.
struct TrackTagsUpdatedSuccess {
    let trackId: UUID
    let snapshot: TrackRuntimeSnapshot?
}
