//
//  TrackTagInspector.swift
//  TrackList
//
//  Читает теги из TagLib(только те, что парсим)
//  Используется для экрана "О треке" (TrackDetailSheet)
//
//  Created by Pavel Fomin on 14.10.2025.
//

import Foundation
import UIKit

// MARK: - Модель для отображения

struct TrackMetadataItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct TrackMetadataSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [TrackMetadataItem]
}

// MARK: - Чтение и форматирование тегов

@MainActor
final class TrackTagInspector {
    static let shared = TrackTagInspector()
    private init() {}
    
    /// Считывает метаданные из файла и подготавливает их для отображения в шите
    func readMetadata(from url: URL) -> [TrackMetadataSection] {
        let tagFile = TLTagLibFile(fileURL: url)
        guard let parsed = tagFile.readMetadata() else {
            print("⚠️ Не удалось прочитать теги для \(url.lastPathComponent)")
            return []
        }
        
        var general: [TrackMetadataItem] = []
        var additional: [TrackMetadataItem] = []
        
        if let title = parsed.title, !title.isEmpty {
            general.append(.init(title: "Название", value: title))
        }
        if let artist = parsed.artist, !artist.isEmpty {
            general.append(.init(title: "Исполнитель", value: artist))
        }
        if let album = parsed.album, !album.isEmpty {
            general.append(.init(title: "Альбом", value: album))
        }
        if let genre = parsed.genre, !genre.isEmpty {
            additional.append(.init(title: "Жанр", value: genre))
        }
        if let comment = parsed.comment, !comment.isEmpty {
            additional.append(.init(title: "Комментарий", value: comment))
        }

        var sections: [TrackMetadataSection] = []
        if !general.isEmpty {
            sections.append(.init(title: "Информация о треке", items: general))
        }
        if !additional.isEmpty {
            sections.append(.init(title: "Дополнительно", items: additional))
        }

        return sections
    }
}
