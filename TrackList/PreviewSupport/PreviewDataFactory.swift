//
//  PreviewDataFactory.swift
//  TrackList
//
//  Фабрика данных для изолированных Xcode Preview.
//
//  Created by Pavel Fomin on 13.06.2026.
//

import Foundation

/// Создаёт рабочие модели проекта без обращения к менеджерам и файловой системе.
enum PreviewDataFactory {

    /// Несколько треков для проверки обычного состояния списков.
    static func makeTracks() -> [Track] {
        [
            Track(
                trackId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Midnight Drive",
                artist: "Neon Coast",
                duration: 214,
                fileName: "midnight_drive.m4a",
                isAvailable: true
            ),
            Track(
                trackId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                title: "Northern Lights",
                artist: "Glass Harbor",
                duration: 187,
                fileName: "northern_lights.flac",
                isAvailable: true
            ),
            Track(
                trackId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "Quiet Morning",
                artist: "June Avenue",
                duration: 256,
                fileName: "quiet_morning.mp3",
                isAvailable: true
            )
        ]
    }

    /// Пустой набор треков для проверки empty-состояния экранов.
    static func makeEmptyTracks() -> [Track] {
        []
    }

    /// Трек без метаданных и обложки для проверки резервного отображения имени файла.
    static func makeTrackWithoutArtwork() -> Track {
        Track(
            trackId: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            title: nil,
            artist: nil,
            duration: 0,
            fileName: "track_without_metadata.wav",
            isAvailable: true
        )
    }

    /// Трек с длинными метаданными для проверки ограничений текстовой вёрстки.
    static func makeLongTextTrack() -> Track {
        Track(
            trackId: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            title: "A Very Long Track Title Created to Verify Truncation in a Compact Row Layout",
            artist: "An Artist with an Exceptionally Long Name for Testing the Available Width",
            duration: 3_726,
            fileName: "a_very_long_track_title_for_layout_testing.aiff",
            isAvailable: true
        )
    }
}
