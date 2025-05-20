//
//  AppError.swift
//  TrackList
//
//  Список всех возможных ошибок приложения
//
//  Created by Pavel Fomin on 20.05.2025.
//

import Foundation

enum AppError: Error, LocalizedError {
    case fileNotFound(URL)
    case bookmarkStale
    case unreadableFile(URL)
    case jsonCorrupted
    case exportFailed
    case importFailed
    case custom(message: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Файл не найден: \(url.path)"
        case .bookmarkStale:
            return "Bookmark устарел и не может быть восстановлен"
        case .unreadableFile(let url):
            return "Невозможно прочитать файл: \(url.path)"
        case .jsonCorrupted:
            return "JSON-файл повреждён"
        case .exportFailed:
            return "Ошибка при экспорте"
        case .importFailed:
            return "Ошибка при импорте"
        case .custom(let message):
            return message
        }
    }
}
