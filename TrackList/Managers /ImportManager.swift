//
//  ImportManager.swift
//  TrackList
//
//  Менеджер импорта треков:
//  — принимает URL-ы файлов
//  — парсит метаданные
//  — регистрирует треки в TrackRegistry
//  — возвращает массив trackId
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import UniformTypeIdentifiers
import UIKit
import AVFoundation

final class ImportManager {

    /// Импортирует аудиофайлы, парсит метаданные
    /// и регистрирует их в TrackRegistry.
    /// Возвращает массив trackId (UUID), которые нужно добавить в TrackList.
    func importTracks(from urls: [URL], to folderId: UUID) async -> [UUID] {

        var result: [UUID] = []

        for url in urls {
            
            // 1. Доступ к файлу
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Нет доступа: \(url.lastPathComponent)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                
                // 2. Метаданные
                let metadata = try? await MetadataParser.parseMetadata(from: url)
                
                // 3. Стабильный trackId (через UUID.v5 → быстрый)
                let trackId = await TrackRegistry.shared.trackId(for: url)
                
                // 4. Создаём bookmark (используется только внутри TrackRegistry)
                let bookmarkData = (try? url.bookmarkData()) ?? Data()
                let bookmarkBase64 = bookmarkData.base64EncodedString()
                
                // 5. Регистрируем в TrackRegistry
                await TrackRegistry.shared.register(
                    trackId: trackId,
                    bookmarkBase64: bookmarkBase64,
                    folderId: folderId,
                    fileName: url.lastPathComponent
                )
                
                print("📥 Импортирован: \(metadata?.title ?? url.lastPathComponent)")
                
                result.append(trackId)
                
            }
        }

        return result
    }
}
