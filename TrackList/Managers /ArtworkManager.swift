//
//  ArtworkManager.swift
//  TrackList
//
//  Хранит обложки треков
//
//  Created by Pavel Fomin on 18.05.2025.
//

import UIKit

struct ArtworkManager {
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

    static func saveArtwork(_ image: UIImage, id: UUID) {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")

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

    static func loadArtwork(id: UUID) -> UIImage? {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        return UIImage(contentsOfFile: url.path)
    }

    static func deleteArtwork(id: UUID) {
        let url = artworksFolderURL.appendingPathComponent("artwork_\(id.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }
}
