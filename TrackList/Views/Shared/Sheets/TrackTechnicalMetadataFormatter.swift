//
//  TrackTechnicalMetadataFormatter.swift
//  TrackList
//
//  Подготовка локализованной строки технических данных файла для Track Detail.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Foundation

/// Преобразует технические runtime-значения в готовый для отображения текст без чтения файла.
enum TrackTechnicalMetadataFormatter {

    /// Возвращает строку только из доступных компонентов или локализованное состояние недоступности.
    static func string(from metadata: TrackTechnicalMetadata) -> String {
        let components = [
            metadata.fileSizeBytes.map(fileSizeText),
            metadata.fileFormat,
            metadata.bitrateBitsPerSecond.map(bitrateText)
        ].compactMap { $0 }

        guard components.isEmpty == false else {
            return TrackDetailPresentationText.unavailableTechnicalValue
        }

        return components.joined(separator: " • ")
    }

    /// Использует системное форматирование размера файлов для текущей локали устройства.
    private static func fileSizeText(for fileSizeBytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: max(0, fileSizeBytes),
            countStyle: .file
        )
    }

    /// Округляет битрейт до целых килобит в секунду и локализует только его единицу.
    private static func bitrateText(for bitrateBitsPerSecond: Int) -> String {
        let kilobitsPerSecond = Int(
            (Double(max(0, bitrateBitsPerSecond)) / 1_000).rounded()
        )
        let unit = String(localized: "kbps")

        return "\(kilobitsPerSecond) \(unit)"
    }
}
