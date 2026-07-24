//
//  TrackTechnicalMetadata.swift
//  TrackList
//
//  Технические runtime-данные аудиофайла для представления в карточке трека.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Foundation

/// Хранит исходные технические значения файла без UI-форматирования и локализации.
struct TrackTechnicalMetadata: Equatable, Sendable {

    /// Фактический размер файла в байтах, если система его предоставила.
    let fileSizeBytes: Int64?
    /// Расширение файла в верхнем регистре, если его можно получить из URL.
    let fileFormat: String?
    /// Фактическая оценка битрейта аудиодорожки в битах в секунду.
    let bitrateBitsPerSecond: Int?
}
