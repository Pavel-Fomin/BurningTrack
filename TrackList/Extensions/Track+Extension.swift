//
//  Track+Extension.swift
//  TrackList
//
//  Расширение модели ImportedTrack для преобразования в Track.
//  Используется при загрузке треклиста из JSON, чтобы подготовить данные для UI и плеера.
//  Также проверяет доступность файла и подгружает обложку по ID.
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit

extension ImportedTrack {
    /// Преобразует ImportedTrack (данные из JSON) в Track (модель для UI/плеера)
    func asTrack() -> Track {
        let url: URL
        var isAvailable = false

        do {
            /// Восстанавливаем защищённый доступ к файлу из bookmarkData
            url = try resolvedURL()
            let accessGranted = url.startAccessingSecurityScopedResource()
            
            /// Проверяем, существует ли физически файл по пути
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
            /// Загружаем изображение по ID, если оно есть
            artwork: artworkId.flatMap { ArtworkManager.loadArtwork(id: $0) },
            isAvailable: isAvailable
        )
    }
}
