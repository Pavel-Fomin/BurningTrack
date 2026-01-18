//
//  TLTagLibFile.swift
//  TrackList
//
//  Низкоуровневая Swift-обёртка над C API TagLib.
//  Предоставляет унифицированный доступ к аудиотегам файла
//  без привязки к конкретному сценарию использования.
//
//  Используется различными слоями приложения:
//  - RuntimeMetadataParser (минимальный runtime-набор тегов)
//  - TrackTagInspector (расширенный набор тегов для инспекции)
//
//  Не содержит UI-логики и не знает о потребителях данных.
//  Отдаёт «сырые» значения тегов в нейтральном формате.
//
//  Created by Pavel Fomin on 21.06.2025.
//

import Foundation

/// Обёртка над C API TagLib для чтения тегов аудиофайла.
/// Является общим low-level адаптером для всех read-сценариев.
public class TLTagLibFile {
    
    /// Путь к аудиофайлу на диске
    private let filePath: String
    
    /// Инициализация с использованием URL аудиофайла
    public init(fileURL: URL) {
        self.filePath = fileURL.path
    }
    
    // MARK: - Внутреннее представление тегов
    
    /// Нейтральная структура с тегами, считанными напрямую из TagLib.
    /// Не является runtime-моделью и не предназначена для прямого использования в UI.
    public struct ParsedMetadata {
        public let title: String?
        public let artist: String?
        public let album: String?
        public let genre: String?
        public let comment: String?
        public let artworkData: Data?
    }
    
    // MARK: - Чтение тегов из TagLib
    
    /// Считывает доступные теги из файла через TagLib.
    /// Возвращает «сырые» данные без форматирования и бизнес-логики.
    public func readMetadata() -> ParsedMetadata? {
        
        // Вызов C-функции из Objective-C обёртки (TLTagLibFile.m)
        guard let result = _readMetadata(filePath) else {
            return nil
        }

        // Преобразование в Swift-структуру
        return ParsedMetadata(
            title: result.title,
            artist: result.artist,
            album: result.album,
            genre: result.genre,
            comment: result.comment,
            artworkData: result.artworkData
        )
    }
    
    // MARK: - Runtime-адаптация
    
    /// Преобразует считанные теги в runtime-модель TrackMetadata.
    /// Используется runtime-парсером для списка и плеера.
    /// Не применяется для инспекции или редактирования тегов.
    func readMetadata(duration: TimeInterval?) -> TrackMetadata {
        
        // Если TagLib не смог прочитать теги — возвращаем пустую runtime-модель
        guard let parsed = readMetadata() else {
            return TrackMetadata(
                artist: nil,
                title: nil,
                album: nil,
                artworkData: nil,
                duration: duration,
                isCustomFormat: true
            )
        }

        // Формирование runtime-модели с учётом длительности
        return TrackMetadata(
            artist: parsed.artist,
            title: parsed.title,
            album: parsed.album,
            artworkData: parsed.artworkData,
            duration: duration,
            isCustomFormat: true
        )
    }
}
