//
//  Track.swift
//  TrackList
//
//  Основная модель трека для воспроизведения. Создаётся из ImportedTrack, содержит url
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit
import AVFoundation

struct Track: Identifiable {
    let id: UUID
    let url: URL
    let artist: String
    let title: String
    let duration: TimeInterval
    let fileName: String
    let artwork: UIImage?

    // MARK: - Статический метод для загрузки метаданных
    static func load(from url: URL) async throws -> Self {
        let asset = AVURLAsset(url: url)

        var artist = "Неизвестен"
        var trackName = url.deletingPathExtension().lastPathComponent
        var duration: TimeInterval = 0

        do {
            let metadata = try await asset.load(.commonMetadata)

            for item in metadata {
                if item.commonKey?.rawValue == "artist" {
                    if let value = try? await item.load(.stringValue) {
                        artist = value
                    }
                }

                if item.commonKey?.rawValue == "title" {
                    if let value = try? await item.load(.stringValue) {
                        trackName = value
                    }
                }
            }

            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)

        } catch {
            print("Ошибка при чтении метаданных: \(error)")
        }

        return Self(
            id: UUID(),
            url: url,
            artist: artist,
            title: trackName,
            duration: duration,
            fileName: url.lastPathComponent,
            artwork: UIImage?(nil)
        )
    }
    // MARK: - Преобразование Track в ImportedTrack (для сохранения в JSON)
    func asImportedTrack() -> ImportedTrack {
        return ImportedTrack(
            id: self.id,
            fileName: self.fileName,
            filePath: self.url.path,
            orderPrefix: "", // необязательно, можно заполнить позже при экспорте
            title: self.title,
            artist: self.artist,
            album: nil,
            duration: self.duration,
            artworkBase64: self.artwork?.pngData()?.base64EncodedString(),
            bookmarkBase64: try? self.url.bookmarkData().base64EncodedString()
        )
    }
}

extension Track: Equatable {
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.url == rhs.url
    }
}
