//
//  PioneerDeckPlaylist.swift
//  TrackList
//
//  Модели плейлистов для USB-экспорта Pioneer/AlphaTheta.
//

import Foundation

/// Плейлист в legacy export-модели.
public struct PioneerDeckPlaylist: Equatable, Sendable {
    /// Числовой id плейлиста внутри export.pdb.
    public let id: UInt32

    /// Исходный UUID плейлиста BurningTrack.
    public let sourcePlaylistId: UUID

    /// Название плейлиста для отображения на деке.
    public let name: String

    /// Упорядоченные ссылки на треки.
    public let entries: [PioneerDeckPlaylistEntry]

    /// Создаёт плейлист для writer-слоя.
    public init(
        id: UInt32,
        sourcePlaylistId: UUID,
        name: String,
        entries: [PioneerDeckPlaylistEntry]
    ) {
        self.id = id
        self.sourcePlaylistId = sourcePlaylistId
        self.name = name
        self.entries = entries
    }
}

/// Строка плейлиста, сохраняющая порядок треков.
public struct PioneerDeckPlaylistEntry: Equatable, Sendable {
    /// Id трека из PioneerDeckExport.tracks.
    public let trackId: UInt32

    /// Позиция трека внутри плейлиста, начиная с 1.
    public let position: UInt32

    /// Создаёт ссылку плейлиста на трек.
    public init(trackId: UInt32, position: UInt32) {
        self.trackId = trackId
        self.position = position
    }
}
