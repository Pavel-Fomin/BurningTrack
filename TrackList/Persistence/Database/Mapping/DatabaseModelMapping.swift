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
        case .purchasedITunes:
            return .purchasedITunes
        }
    }

    static func trackSource(from source: DatabaseTrackSource) -> TrackSource {
        switch source {
        case .library:
            return .library
        case .purchasedITunes:
            return .purchasedITunes
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
            fileName: model.fileNameSnapshot ?? "Unknown",
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
            fileName: model.fileNameSnapshot ?? "Unknown",
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
