//
//  SharedPresentationText.swift
//  TrackList
//
//  Локализованные подписи общих компонентов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Формирует параметризованные подписи, используемые несколькими общими компонентами.
enum SharedPresentationText {
    static var clearAccessibilityLabel: String {
        String(localized: "Clear")
    }

    static func operationProgress(
        processedCount: Int,
        totalCount: Int
    ) -> String {
        String.localizedStringWithFormat(
            String(localized: "%1$lld of %2$lld"),
            processedCount,
            totalCount
        )
    }

    static func tracklistMembership(_ names: String) -> String {
        String.localizedStringWithFormat(
            String(localized: "Already in: %@"),
            names
        )
    }

    /// Формирует вторичную строку статистики только на границе presentation-слоя.
    static func trackCollectionSummary(
        from summary: TrackCollectionSummary
    ) -> String {
        var parts = [trackCount(summary.trackCount)]

        if summary.hasCompleteDuration,
           let totalDuration = summary.totalDuration {
            parts.append(summaryDuration(totalDuration))
        }

        if summary.hasCompleteFileSize,
           let totalFileSize = summary.totalFileSize {
            parts.append(fileSize(totalFileSize))
        }

        return parts.joined(separator: " • ")
    }

    /// Формирует длительность трека через format-ключи String Catalog.
    static func duration(_ value: TimeInterval) -> String {
        guard value.isFinite, value > 0 else {
            return String(localized: "duration.unavailable")
        }

        let totalMinutes = Int(value) / 60
        let seconds = Int(value) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let days = hours / 24
        let remainingHours = hours % 24

        switch (days, hours) {
        case (let days, _) where days > 0:
            return String.localizedStringWithFormat(
                String(localized: "duration.days"),
                days,
                remainingHours,
                minutes
            )
        case (_, let hours) where hours > 0:
            return String.localizedStringWithFormat(
                String(localized: "duration.hours"),
                hours,
                minutes
            )
        default:
            return String.localizedStringWithFormat(
                String(localized: "duration.minutes"),
                minutes,
                seconds
            )
        }
    }

    /// Добавляет знак оставшегося времени к уже локализованной длительности.
    static func remainingDuration(_ value: TimeInterval) -> String {
        String.localizedStringWithFormat(
            String(localized: "duration.remaining"),
            duration(value)
        )
    }

    /// Форматирует количество треков через plural-варианты String Catalog.
    private static func trackCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "library.trackCount"),
            count
        )
    }

    /// Форматирует итоговую длительность в минутах либо часах и минутах.
    private static func summaryDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: max(0, value)) ?? ""
    }

    /// Форматирует размер файла в английской локали независимо от языка устройства.
    static func fileSize(_ value: Int64) -> String {
        let formatter = ByteCountFormatStyle(style: .file)
            .locale(Locale(identifier: "en_US"))

        return max(0, value).formatted(formatter)
    }
}
