//
//  ArtworkManager.swift
//  TrackList
//
//  Менеджер обложек треков: сохранение, загрузка и удаление JPEG-файлов.
//  Путь: /Documents/artworks/artwork_<id>.jpg
//
//  Created by Pavel Fomin on 18.05.2025.
//

import UIKit

struct ArtworkManager {
    
    
// MARK: - Путь к папке с обложками

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
    
    
// MARK: - Сохранение

      /// Сохраняет изображение в формате JPEG с заданным ID (обычно UUID трека)
      /// - Parameters:
      ///  - image: Изображение обложки (UIImage)
      ///  - id: Уникальный идентификатор трека
    static func saveArtwork(_ image: UIImage, id: UUID) {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        
        // Конвертация в JPEG сжатие 0.7
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

    
// MARK: - Загрузка

    /// Загружает изображение обложки по ID
    /// - Parameter id: Уникальный идентификатор трека
    /// - Returns: UIImage или nil, если файл не найден или не читается
    static func loadArtwork(id: UUID) -> UIImage? {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")

        if !FileManager.default.fileExists(atPath: url.path) {
        
        }

        if let image = UIImage(contentsOfFile: url.path) {
            return image
        } else {
    
            return nil
        }
    }
    
    
// MARK: - Удаление

    /// Удаляет файл обложки по ID, если он существует
    /// - Parameter id: Уникальный идентификатор трека
    static func deleteArtwork(id: UUID) {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}
