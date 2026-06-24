//
//  PioneerDeckExport.swift
//  TrackList
//
//  Корневая domain-модель USB-экспорта Pioneer/AlphaTheta.
//

import Foundation

/// Описывает полный набор данных, который BurningTrack отдаёт writer-слою.
public struct PioneerDeckExport: Equatable, Sendable {
    /// Плейлисты BurningTrack в порядке экспорта.
    public let playlists: [PioneerDeckPlaylist]

    /// Уникальные треки, на которые ссылаются плейлисты.
    public let tracks: [PioneerDeckTrack]

    /// Цветовой справочник для legacy export.pdb.
    public let colors: [PioneerDeckColor]

    /// Создаёт модель экспорта без зависимости от UI и менеджеров приложения.
    public init(
        playlists: [PioneerDeckPlaylist],
        tracks: [PioneerDeckTrack],
        colors: [PioneerDeckColor] = PioneerDeckColor.rekordboxDefaults
    ) {
        self.playlists = playlists
        self.tracks = tracks
        self.colors = colors
    }
}

public extension PioneerDeckExport {
    /// Проверяет инварианты модели перед бинарной записью.
    func validate() throws {
        let trackIds = tracks.map(\.id)
        guard Set(trackIds).count == trackIds.count else {
            throw PioneerDeckExportError.duplicateTrackId
        }

        let playlistIds = playlists.map(\.id)
        guard Set(playlistIds).count == playlistIds.count else {
            throw PioneerDeckExportError.duplicatePlaylistId
        }

        let knownTrackIds = Set(trackIds)
        for playlist in playlists {
            for entry in playlist.entries where !knownTrackIds.contains(entry.trackId) {
                throw PioneerDeckExportError.playlistEntryReferencesMissingTrack(
                    playlistId: playlist.id,
                    trackId: entry.trackId
                )
            }
        }
    }
}
