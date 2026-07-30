//
//  TrackDisplayable.swift
//  TrackList
//
//  Универсальный протокол для отображения треков в списке
//
//  Created by Pavel Fomin on 05.07.2025.
//
import Foundation
// MARK: -  Протокол
protocol TrackDisplayable: Identifiable {
    /// Идентификатор конкретной display-модели; у строк очереди и треклиста это не обязательно trackId.
    var id: UUID { get }
    /// Логический идентификатор трека: для локального источника равен первичному ключу tracks.id в SQLite.
    var trackId: UUID { get }
    // Показываемое имя файла
    var fileName: String { get }
    // Метаданные
    var title: String? { get }
    var artist: String? { get }
    var duration: Double { get }
    // Флаг доступности
    var isAvailable: Bool { get }
}
