//
//  PlayerTrack.swift
//  TrackList
//
//  Модел трека для плеера
//
//  Created by Pavel Fomin on 07.08.2025.
//

import Foundation
import AVFoundation
import UIKit

struct PlayerTrack: Identifiable, Equatable, Codable, TrackDisplayable {
    let id: UUID
    let url: URL
    let artist: String?
    let title: String?
    let duration: TimeInterval
    let fileName: String
    let isAvailable: Bool
    let bookmarkBase64: String
    
    var artwork: UIImage? { nil }
    
    static func == (lhs: PlayerTrack, rhs: PlayerTrack) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Проверяет доступность файла
    func refreshAvailability() -> PlayerTrack {
        var isAvailable = false
        
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if accessGranted {
            do {
                _ = try Data(contentsOf: url, options: [.mappedIfSafe])
                isAvailable = true
            } catch {
                print("🗑️ Файл не читается: \(error.localizedDescription)")
            }
        }
        
        return PlayerTrack(
            id: self.id,
            url: self.url,
            artist: self.artist,
            title: self.title,
            duration: self.duration,
            fileName: self.fileName,
            isAvailable: isAvailable,
            bookmarkBase64: self.bookmarkBase64
        )
    }
    
    /// Преобразует в ImportedTrack для экспорта
    func asImportedTrack() -> ImportedTrack {
        return ImportedTrack(
            id: id,
            fileName: fileName,
            filePath: url.path,
            orderPrefix: "",
            title: title,
            artist: artist,
            album: nil,
            duration: duration,
            bookmarkBase64: bookmarkBase64
        )
    }
    
    
    
    /// Загрузка трека из URL с помощью AVFoundation
    static func load(from url: URL, bookmarkBase64: String) async throws -> PlayerTrack {
        let asset = AVURLAsset(url: url)
        
        var artist: String? = "Неизвестен"
        var title: String? = url.deletingPathExtension().lastPathComponent
        var duration: TimeInterval = 0
        let available = FileManager.default.fileExists(atPath: url.path)
        
        do {
            let metadata = try await asset.load(.commonMetadata)
            
            for item in metadata {
                if item.commonKey?.rawValue == "artist",
                   let value = try? await item.load(.stringValue) {
                    artist = value
                }
                if item.commonKey?.rawValue == "title",
                   let value = try? await item.load(.stringValue) {
                    title = value
                }
            }
            
            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)
            
        } catch {
            print("Ошибка при чтении метаданных: \(error)")
        }
        
        return PlayerTrack(
            id: UUID(),
            url: url,
            artist: artist,
            title: title,
            duration: duration,
            fileName: url.lastPathComponent,
            isAvailable: available,
            bookmarkBase64: bookmarkBase64
        )
    }
}
