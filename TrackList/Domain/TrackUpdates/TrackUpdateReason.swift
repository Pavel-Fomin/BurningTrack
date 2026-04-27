//
//  TrackUpdateReason.swift
//  TrackList
//
//  Причина обновления runtime-состояния трека.
//  Используется в едином контракте обновления, чтобы подписчики понимали, какой тип изменения произошёл.
//
//  Created by PavelFomin on 24.04.2026.
//

import Foundation

enum TrackUpdateReason: Equatable {
    case metadataUpdated       /// Изменены теги (title, artist, album и т.д.)
    case artworkUpdated        /// Изменена обложка
    case fileRenamed           /// Переименование файла
    case availabilityUpdated   /// Изменилась доступность файла
    case reloaded              /// Принудительное пересчитывание snapshot
    case imported              /// Трек появился после импорта
    case fileMoved             /// Файл был перемещён в другую папку
}
