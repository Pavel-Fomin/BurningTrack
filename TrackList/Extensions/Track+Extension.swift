//
//  Track+Extension.swift
//  TrackList
//
//  Расширение для преобразования ImportedTrack в Track.
//  Используется при загрузке треклиста из JSON, чтобы передать данные в UI и плеер.
//  Здесь происходит декодирование base64-encoded обложки в UIImage.
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit

extension ImportedTrack {
    func asTrack() -> Track {
        let url: URL
        var isAvailable = false

        do {
            url = try resolvedURL()
            let accessGranted = url.startAccessingSecurityScopedResource()
            isAvailable = accessGranted && FileManager.default.fileExists(atPath: url.path)
            url.stopAccessingSecurityScopedResource()
        } catch {
            print("❌ Ошибка при разрешении bookmark для \(fileName): \(error)")
            url = URL(fileURLWithPath: filePath)
            isAvailable = false // 🔥 файл НЕ существует — ставим false
        }
        
        return Track(
            id: id,
            url: url,
            artist: artist ?? "Неизвестный артист",
            title: title ?? fileName,
            duration: duration,
            fileName: fileName,
            artwork: artworkId.flatMap { ArtworkManager.loadArtwork(id: $0) },
            isAvailable: isAvailable
        )
    }
}
