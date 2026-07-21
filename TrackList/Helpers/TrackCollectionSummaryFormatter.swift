//
//  TrackCollectionSummaryFormatter.swift
//  TrackList
//
//  Форматирование статистики музыкальной коллекции для интерфейса.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует общую статистику коллекции в готовую вторичную строку интерфейса.
enum TrackCollectionSummaryFormatter {
    /// Возвращает строку с количеством треков и только полностью известными итогами.
    static func string(from summary: TrackCollectionSummary) -> String {
        var parts = [trackCountText(for: summary.trackCount)]

        if summary.hasCompleteDuration,
           let totalDuration = summary.totalDuration {
            parts.append(durationText(for: totalDuration))
        }

        if summary.hasCompleteFileSize,
           let totalFileSize = summary.totalFileSize {
            parts.append(fileSizeText(for: totalFileSize))
        }

        return parts.joined(separator: " • ")
    }

    /// Форматирует количество треков через plural-варианты String Catalog.
    private static func trackCountText(for count: Int) -> String {
        let format = String(localized: "library.trackCount")
        return String.localizedStringWithFormat(format, count)
    }

    /// Форматирует итоговую длительность в минутах либо часах и минутах.
    private static func durationText(for duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: max(0, duration)) ?? ""
    }

    /// Использует системный форматтер размера файлов и локаль устройства.
    private static func fileSizeText(for size: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: max(0, size),
            countStyle: .file
        )
    }
}
