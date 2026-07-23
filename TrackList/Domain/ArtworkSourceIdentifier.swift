//
//  ArtworkSourceIdentifier.swift
//  TrackList
//
//  Стабильная идентичность исходных данных обложки.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import CryptoKit
import Foundation

/// Однозначно описывает источник обложки без хранения её бинарных данных в ключах кэша.
struct ArtworkSourceIdentifier: Hashable, Sendable {
    /// Внутренние варианты источника исключают случайное создание UUID при каждом запросе.
    private enum Storage: Hashable, Sendable {
        /// SHA-256 raw-данных встроенной в файл обложки.
        case embeddedArtwork(String)
        /// Стабильный persistent identifier элемента системной медиатеки.
        case mediaLibrary(UUID)
        /// Идентификатор несохранённой пользовательской замены, созданный в состоянии редактирования.
        case transient(UUID)
    }

    /// Реальное значение идентичности скрыто от экранов, чтобы они не строили ключ из Data.
    private let storage: Storage

    /// Создаёт идентичность встроенной обложки по полному SHA-256 её байтов.
    /// Вызывается только в фоновой metadata-подготовке, а не при построении SwiftUI View.
    static func embeddedArtwork(data: Data) -> ArtworkSourceIdentifier {
        let digest = SHA256.hash(data: data)
        let value = digest.map { String(format: "%02x", $0) }.joined()
        return ArtworkSourceIdentifier(storage: .embeddedArtwork(value))
    }

    /// Создаёт идентичность обложки элемента MediaPlayer по его стабильному идентификатору.
    static func mediaLibrary(trackId: UUID) -> ArtworkSourceIdentifier {
        ArtworkSourceIdentifier(storage: .mediaLibrary(trackId))
    }

    /// Создаёт идентичность несохранённой пользовательской обложки из уже сохранённой ревизии UI-состояния.
    static func transient(revision: UUID) -> ArtworkSourceIdentifier {
        ArtworkSourceIdentifier(storage: .transient(revision))
    }
}

extension ArtworkSourceIdentifier: CustomStringConvertible {
    /// Короткое представление подходит для DEBUG-диагностики и не выводит бинарные данные.
    var description: String {
        switch storage {
        case .embeddedArtwork(let digest):
            return "embedded:\(digest.prefix(12))"
        case .mediaLibrary(let trackId):
            return "media:\(trackId.uuidString.prefix(8))"
        case .transient(let revision):
            return "transient:\(revision.uuidString.prefix(8))"
        }
    }
}
