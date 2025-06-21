//
//  TLTagLibFile.swift
//  TrackList
//
//  Обёртка над C API TagLib для чтения аудиотегов из Swift
//  Используется внутри MetadataParser, возвращает данные в формате TrackMetadata
//
//  Created by Pavel Fomin on 21.06.2025.
//

import Foundation

// Обёртка над C++ API TagLib для чтения тегов
public class TLTagLibFile {
    
    // Путь к аудиофайлу
    private let filePath: String
    
    // Инициализация с использованием URL аудиофайла
    public init(fileURL: URL) {
        self.filePath = fileURL.path
    }
    
    // MARK: - Структура для хранения считанных тегов

    // Теги, считанные напрямую из TagLib (внутренний формат)
    public struct ParsedMetadata {
        public let title: String?
        public let artist: String?
        public let album: String?
        public let genre: String?
        public let comment: String?
        public let artworkData: Data?
    }
    
    // MARK: - Основной метод чтения тегов

    // Возвращает сырые метаданные из TagLib
    public func readMetadata() -> ParsedMetadata? {
        
        // Вызываем C-функцию из обёртки (TLTagLibFile.m)
        guard let result = _readMetadata(filePath) else {
               return nil
        }

        // Оборачиваем в структуру Swift
        return ParsedMetadata(
            title: result.title,
            artist: result.artist,
            album: result.album,
            genre: result.genre,
            comment: result.comment,
            artworkData: result.artworkData
        )
    }
    
    // MARK: - Преобразование в TrackMetadata
    
    // Возвращает метаданные в формате TrackMetadata
    func readMetadata(duration: TimeInterval?) -> TrackMetadata {
        
        // Если TagLib не смог прочитать теги — возвращаем пустую структуру
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

        // Формируем TrackMetadata (с длительностью)
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
