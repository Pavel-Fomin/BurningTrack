//
//  DatabaseModelMapping.swift
//  TrackList
//
//  Преобразования между SQLite row-моделями и моделями приложения.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Преобразует источник трека между persistence-слоем и текущими runtime-моделями.
enum TrackSourceDatabaseMapper {
    static func databaseSource(from source: TrackSource) -> DatabaseTrackSource {
        switch source {
        case .library:
            return .library
        case .imported:
            return .imported
        case .purchasedITunes:
            return .purchasedITunes
        }
    }

    static func trackSource(from source: DatabaseTrackSource) -> TrackSource {
        switch source {
        case .library:
            return .library
        case .imported:
            return .imported
        case .purchasedITunes:
            return .purchasedITunes
        }
    }
}

// Преобразует runtime-источник playback в поля единственной строки player_state.
enum PlaybackContextSourceDatabaseMapper {
    static func databaseType(from source: PlaybackContextSource) -> DatabasePlaybackContextType {
        switch source {
        case .playerQueue:
            return .playerQueue
        case .trackList:
            return .trackList
        case .libraryFolder:
            return .libraryFolder
        case .libraryRoot:
            return .libraryRoot
        case .libraryCollection:
            return .libraryCollection
        }
    }

    static func contextId(from source: PlaybackContextSource) -> UUID? {
        switch source {
        case .playerQueue:
            return nil
        case .trackList(let id):
            return id
        case .libraryFolder(let id):
            return id
        case .libraryRoot:
            return nil
        case .libraryCollection:
            return nil
        }
    }

    /// Возвращает сохранённую строку категории или nil для остальных источников.
    static func collectionCategory(from source: PlaybackContextSource) -> String? {
        guard case let .libraryCollection(category, _, _) = source else { return nil }
        return category.rawValue
    }

    /// Возвращает сохранённое значение категории или nil для остальных источников.
    static func collectionValue(from source: PlaybackContextSource) -> String? {
        guard case let .libraryCollection(_, rawValue, _) = source else { return nil }
        return rawValue
    }

    /// Возвращает сохранённый artist-ключ альбома или nil для остальных источников.
    static func collectionArtistKey(from source: PlaybackContextSource) -> String? {
        guard case let .libraryCollection(_, _, artistKey) = source else { return nil }
        return artistKey
    }

    static func playbackSource(
        from type: DatabasePlaybackContextType,
        contextId: UUID?,
        collectionCategory: String? = nil,
        collectionValue: String? = nil,
        collectionArtistKey: String? = nil
    ) -> PlaybackContextSource? {
        switch type {
        case .playerQueue:
            return .playerQueue
        case .trackList:
            guard let contextId else { return nil }
            return .trackList(id: contextId)
        case .libraryFolder:
            guard let contextId else { return nil }
            return .libraryFolder(id: contextId)
        case .libraryRoot:
            guard contextId == nil else { return nil }
            return .libraryRoot
        case .libraryCollection:
            // Для категории идентификатор не используется: источник определяется строковыми полями.
            guard contextId == nil,
                  let collectionCategory,
                  let category = LibraryCollectionCategory(rawValue: collectionCategory),
                  let collectionValue
            else {
                return nil
            }

            return .libraryCollection(
                category: category,
                rawValue: collectionValue,
                artistKey: collectionArtistKey
            )
        }
    }
}

// Преобразует метаданные треклиста между SQLite и бизнес-моделью.
enum TrackListMetaDatabaseMapper {
    static func databaseModel(from meta: TrackListMeta, updatedAt: Date) -> TrackListDatabaseModel {
        // sortOrder и isDeleted отсутствуют в бизнес-модели и заполняются значениями SQLite-слоя.
        TrackListDatabaseModel(
            id: meta.id,
            name: meta.name,
            createdAt: meta.createdAt,
            updatedAt: updatedAt,
            sortOrder: nil,
            isDeleted: false
        )
    }

    static func trackListMeta(from model: TrackListDatabaseModel) -> TrackListMeta {
        // Текущая бизнес-модель метаинформации не знает о soft-delete и порядке сортировки.
        TrackListMeta(
            id: model.id,
            name: model.name,
            createdAt: model.createdAt
        )
    }
}

// Преобразует строку треклиста в текущую display-модель Track на основе сохранённого snapshot.
enum TrackListTrackDatabaseMapper {
    static func track(from model: TrackListTrackDatabaseModel) -> Track {
        Track(
            listItemId: model.id,
            trackId: model.trackId,
            title: model.titleSnapshot,
            artist: model.artistSnapshot,
            album: model.albumSnapshot,
            artworkData: nil,
            duration: model.durationSnapshot ?? 0,
            fileName: model.fileNameSnapshot ?? "",
            isAvailable: model.isAvailableSnapshot,
            source: TrackSourceDatabaseMapper.trackSource(from: model.sourceSnapshot),
            assetURL: model.assetURLSnapshot.flatMap(URL.init(string:))
        )
    }

    static func databaseModel(
        from track: Track,
        trackListId: UUID,
        position: Int,
        createdAt: Date
    ) -> TrackListTrackDatabaseModel {
        TrackListTrackDatabaseModel(
            id: track.listItemId,
            trackListId: trackListId,
            trackId: track.trackId,
            position: position,
            sourceSnapshot: TrackSourceDatabaseMapper.databaseSource(from: track.source),
            titleSnapshot: track.title,
            artistSnapshot: track.artist,
            albumSnapshot: track.album,
            durationSnapshot: track.duration,
            fileNameSnapshot: track.fileName,
            assetURLSnapshot: track.assetURL?.absoluteString,
            isAvailableSnapshot: track.isAvailable,
            createdAt: createdAt
        )
    }
}

// Преобразует строку очереди плеера в текущую display-модель PlayerTrack.
enum PlayerQueueDatabaseMapper {
    static func playerTrack(from model: PlayerQueueItemDatabaseModel) -> PlayerTrack {
        PlayerTrack(
            queueItemId: model.id,
            trackId: model.trackId,
            title: model.titleSnapshot,
            artist: model.artistSnapshot,
            album: model.albumSnapshot,
            artworkData: nil,
            duration: model.durationSnapshot ?? 0,
            fileName: model.fileNameSnapshot ?? "",
            isAvailable: model.isAvailableSnapshot,
            source: TrackSourceDatabaseMapper.trackSource(from: model.sourceSnapshot),
            assetURL: model.assetURLSnapshot.flatMap(URL.init(string:))
        )
    }

    static func databaseModel(
        from track: PlayerTrack,
        position: Int,
        createdAt: Date
    ) -> PlayerQueueItemDatabaseModel {
        PlayerQueueItemDatabaseModel(
            id: track.queueItemId,
            trackId: track.trackId,
            position: position,
            sourceSnapshot: TrackSourceDatabaseMapper.databaseSource(from: track.source),
            titleSnapshot: track.title,
            artistSnapshot: track.artist,
            albumSnapshot: track.album,
            durationSnapshot: track.duration,
            fileNameSnapshot: track.fileName,
            assetURLSnapshot: track.assetURL?.absoluteString,
            isAvailableSnapshot: track.isAvailable,
            createdAt: createdAt
        )
    }
}

// Преобразует runtime snapshot в строку SQLite metadata.
enum TrackMetadataDatabaseMapper {
    static func databaseModel(from snapshot: TrackRuntimeSnapshot) -> TrackMetadataDatabaseModel {
        TrackMetadataDatabaseModel(
            trackId: snapshot.trackId,
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            albumArtist: snapshot.albumArtist,
            label: snapshot.publisherOrLabel,
            genre: snapshot.genre,
            year: snapshot.year,
            trackNumber: snapshot.trackNumber,
            discNumber: snapshot.discNumber,
            bpm: snapshot.bpm.map(Double.init),
            keySignature: snapshot.musicalKey,
            comment: snapshot.comment,
            duration: snapshot.duration,
            bitrate: nil,
            sampleRate: nil,
            channelCount: nil,
            metadataUpdatedAt: snapshot.updatedAt
        )
    }
}
