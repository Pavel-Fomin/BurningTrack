//
//  PioneerDeckExportFactory+TrackList.swift
//  TrackList
//
//  Adapter от текущих моделей BurningTrack к PioneerDeckExport.
//

import Foundation

extension PioneerDeckExportFactory {
    /// Собирает экспорт из текущих TrackList-моделей приложения.
    static func makeExport(from trackLists: [TrackList]) throws -> PioneerDeckExport {
        let sourcePlaylists = trackLists.map { trackList in
            PioneerDeckSourcePlaylist(
                sourcePlaylistId: trackList.id,
                name: trackList.name,
                tracks: trackList.tracks.map { track in
                    PioneerDeckSourceTrack(
                        sourceTrackId: track.trackId,
                        title: track.title,
                        artist: track.artist,
                        duration: track.duration,
                        fileName: track.fileName,
                        sourceFileURL: nil
                    )
                }
            )
        }

        return try makeExport(from: sourcePlaylists)
    }
}
