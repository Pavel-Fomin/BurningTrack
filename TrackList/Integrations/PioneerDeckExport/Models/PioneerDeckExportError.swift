//
//  PioneerDeckExportError.swift
//  TrackList
//
//  Ошибки writer-слоя Pioneer/AlphaTheta USB Export.
//

import Foundation

/// Ошибки изолированного слоя экспорта на USB-носитель.
public enum PioneerDeckExportError: Error, Equatable, LocalizedError, Sendable {
    /// В модели повторяется числовой id трека.
    case duplicateTrackId

    /// В модели повторяется числовой id плейлиста.
    case duplicatePlaylistId

    /// Плейлист ссылается на трек, которого нет в export.tracks.
    case playlistEntryReferencesMissingTrack(playlistId: UInt32, trackId: UInt32)

    /// Для копирования аудио не передан исходный файл.
    case missingSourceFile(trackId: UInt32, fileName: String)

    /// Исходный аудиофайл отсутствует на диске.
    case sourceFileNotFound(String)

    /// USB-путь не может быть записан безопасно.
    case invalidUSBPath(String)

    /// В каноничном документе пока нет достаточной схемы для реального DeviceSQL.
    case unsupportedDeviceSQLLayout(String)

    /// Бинарный readback не распознал ожидаемую структуру.
    case invalidBinaryLayout(String)

    /// Низкоуровневая запись файла завершилась ошибкой.
    case fileWriteFailed(String)

    /// Локализованное описание ошибки для toast/logging слоя.
    public var errorDescription: String? {
        switch self {
        case .duplicateTrackId:
            return "В Pioneer Deck Export повторяется id трека."
        case .duplicatePlaylistId:
            return "В Pioneer Deck Export повторяется id плейлиста."
        case let .playlistEntryReferencesMissingTrack(playlistId, trackId):
            return "Плейлист \(playlistId) ссылается на отсутствующий трек \(trackId)."
        case let .missingSourceFile(trackId, fileName):
            return "Для трека \(trackId) не передан исходный файл: \(fileName)."
        case let .sourceFileNotFound(path):
            return "Исходный аудиофайл не найден: \(path)."
        case let .invalidUSBPath(path):
            return "Некорректный USB-путь Pioneer Export: \(path)."
        case let .unsupportedDeviceSQLLayout(reason):
            return "DeviceSQL layout пока не поддержан: \(reason)."
        case let .invalidBinaryLayout(reason):
            return "Некорректная бинарная структура: \(reason)."
        case let .fileWriteFailed(path):
            return "Не удалось записать файл Pioneer Export: \(path)."
        }
    }
}
