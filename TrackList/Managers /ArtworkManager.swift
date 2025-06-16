//
//  ArtworkManager.swift
//  TrackList
//
//  Менеджер обложек треков: сохранение, загрузка и удаление JPEG-файлов.
//  Используется для хранения изображений треков в папке /Documents/artworks
//
//  Created by Pavel Fomin on 18.05.2025.
//

import UIKit

struct ArtworkManager {
    /// URL до папки /Documents/artworks
    /// Создаётся при первом обращении, если ещё не существует
    static let artworksFolderURL: URL = {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let artworkFolder = documents.appendingPathComponent("artworks", isDirectory: true)

        if !fileManager.fileExists(atPath: artworkFolder.path) {
            do {
                try fileManager.createDirectory(at: artworkFolder, withIntermediateDirectories: true)
                print("📁 Создана папка для обложек: \(artworkFolder.path)")
            } catch {
                print("❌ Не удалось создать папку для обложек: \(error)")
            }
        }

        return artworkFolder
    }()
    
    /// Сохраняет изображение в формате JPEG с ID (используется UUID трека)
    /// - Путь: /Documents/artworks/artwork_<id>.jpg
    static func saveArtwork(_ image: UIImage, id: UUID) {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        
        /// Сжимаем изображение до JPEG
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            print("⚠️ Не удалось сжать JPEG")
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            print("💾 Сохранена JPEG-обложка: \(url.lastPathComponent)")
        } catch {
            print("❌ Ошибка при сохранении JPEG-обложки: \(error)")
        }
    }

    /// Загружает изображение по ID
    /// Возвращает UIImage или nil, если файл не найден
    static func loadArtwork(id: UUID) -> UIImage? {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        return UIImage(contentsOfFile: url.path)
    }
    
    /// Удаляет изображение по ID (если оно существует)
    static func deleteArtwork(id: UUID) {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}
