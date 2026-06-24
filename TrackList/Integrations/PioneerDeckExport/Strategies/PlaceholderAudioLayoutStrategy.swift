//
//  PlaceholderAudioLayoutStrategy.swift
//  TrackList
//
//  Временная стратегия раскладки аудиофайлов Pioneer Deck Export.
//

import Foundation

/// Стратегия построения USB-пути аудиофайла внутри папки PIONEER.
public protocol PioneerAudioLayoutStrategy: Sendable {
    /// Возвращает путь, который будет записан в модель экспорта и PPTH.
    func audioUSBPath(artist: String, album: String?, fileName: String) -> String
}

/// Временная стратегия раскладки аудиофайлов.
///
/// Алгоритм реального Pioneer/AlphaTheta export layout пока не подтверждён реверсом.
/// Текущая реализация нужна только для построения тестовой структуры каталогов.
public struct PlaceholderAudioLayoutStrategy: PioneerAudioLayoutStrategy {
    /// Текущая временная директория аудиофайлов внутри PIONEER.
    private let placeholderAudioRoot = "Contents"

    /// Создаёт временную стратегию раскладки аудиофайлов.
    public init() {}

    /// Собирает placeholder-путь аудиофайла внутри папки PIONEER.
    public func audioUSBPath(artist: String, album: String?, fileName: String) -> String {
        let safeArtist = sanitizedPathComponent(artist.nilIfBlank ?? "UnknownArtist")
        let safeAlbum = sanitizedPathComponent(album?.nilIfBlank ?? "UnknownAlbum")
        let safeFileName = sanitizedPathComponent(fileName.nilIfBlank ?? "UnknownFile")
        return "/\(placeholderAudioRoot)/\(safeArtist)/\(safeAlbum)/\(safeFileName)"
    }

    /// Убирает символы, которые ломают переносимость USB-пути.
    private func sanitizedPathComponent(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let scalars = value.unicodeScalars.map { forbidden.contains($0) ? "_" : Character($0) }
        let sanitized = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "_" : sanitized
    }
}

private extension String {
    /// Возвращает nil для пустых и пробельных строк.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
