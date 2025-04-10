import Foundation
import AVFoundation

struct Track: Identifiable {
    let id = UUID()
    let url: URL
    let artist: String
    let trackName: String
    let duration: TimeInterval

    // Статический метод для загрузки метаданных
    static func load(from url: URL) async throws -> Track {
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

        return Track(url: url, artist: artist, trackName: trackName, duration: duration)
    }
}
