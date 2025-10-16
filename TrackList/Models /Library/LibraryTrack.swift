//
//  LibraryTrack.swift
//  TrackList
//
//  Created by Pavel Fomin on 05.07.2025.
//

import Foundation
import UIKit

/// Представляет один трек из прикреплённой папки.
/// Используется для отображения, воспроизведения и экспорта
struct LibraryTrack: Identifiable, TrackDisplayable {
    var id: UUID { original.id }    /// Уникальный идентификатор (совпадает с original.id)
    let url: URL                    /// Исходный URL без восстановления доступа (может быть недоступен)
    let resolvedURL: URL            /// Восстановленный URL с правами доступа
    let isAvailable: Bool           /// Флаг доступности файла по пути resolvedURL
    let bookmarkBase64: String      /// Закодированный bookmarkData, используется для восстановления доступа
    var title: String?              /// Название трека (из тегов)
    let artist: String?             /// Исполнитель трека (из тегов)
    let duration: TimeInterval      /// Длительность трека в секундах
    let artwork: UIImage?           /// Обложка трека (если есть)
    let addedDate: Date             /// Дата добавления (creationDate или modificationDate)
    let original: ImportedTrack     /// Ссылка на исходный импортированный объект

    /// Имя файла без расширения (для отображения)
    var fileName: String {
        resolvedURL.deletingPathExtension().lastPathComponent
    }

}


// MARK: - Доступ к защищённому ресурсу (start/stopAccessing)

extension LibraryTrack {
    /// Начинает доступ к защищённому ресурсу, если необходимо.
    /// Возвращает `resolvedURL`, если доступ получен.
    func startAccessingIfNeeded() -> URL? {
        let success = resolvedURL.startAccessingSecurityScopedResource()
        if !success {
            print("❌ Не удалось начать доступ к \(resolvedURL.lastPathComponent)")
            return nil
        }
        return resolvedURL
    }
    
    /// Завершает доступ к защищённому ресурсу, если он был начат.
    func stopAccessingIfNeeded() {
        resolvedURL.stopAccessingSecurityScopedResource()
    }
}


// MARK: - Отображение данных (title, artist)

extension LibraryTrack {
    
    /// Заголовок для отображения (из title или имени файла)
    var displayTitle: String? {
        title ?? fileName
    }
    /// Исполнитель для отображения
    var displayArtist: String? {
        artist
    }
}


// MARK: - Сравнение треков

extension LibraryTrack: Equatable {
    
    /// Сравнение по id
    static func == (lhs: LibraryTrack, rhs: LibraryTrack) -> Bool {
        lhs.id == rhs.id
    }
}

