//
//  TrackTagInspector.swift
//  TrackList
//
//  Читает теги из TagLib для экрана "О треке".
//  Возвращает нормализованную модель данных шита,
//  без привязки к UI и display-секциям.
//
//  Created by Pavel Fomin on 14.10.2025.
//

import Foundation
import UIKit

@MainActor
final class TrackTagInspector {
    static let shared = TrackTagInspector()
    private init() {}

    /// Считывает метаданные из файла и возвращает модель данных для шита.
    func readMetadata(from url: URL) -> TrackSheetMetadata? {
        let tagFile = TLTagLibFile(fileURL: url)

        guard let parsed = tagFile.readMetadata() else {
            print("⚠️ Не удалось прочитать теги для \(url.lastPathComponent)")
            return nil
        }

        return TrackSheetMetadata(
            title: parsed.title,
            artist: parsed.artist,
            album: parsed.album,
            albumArtist: nil,
            genre: parsed.genre,
            comment: parsed.comment,

            composer: nil,
            conductor: nil,
            lyricist: nil,
            remixer: nil,

            grouping: nil,
            bpm: nil,
            musicalKey: nil,

            trackNumber: nil,
            totalTracks: nil,
            discNumber: nil,
            totalDiscs: nil,

            year: parsed.year,
            date: nil,

            publisherOrLabel: parsed.publisher,
            copyright: nil,
            encodedBy: nil,
            isrc: nil
        )
    }
}
