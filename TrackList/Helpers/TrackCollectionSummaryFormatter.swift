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

    /// Склоняет слово «трек» по правилам русского языка.
    private static func trackCountText(for count: Int) -> String {
        let remainderHundred = count % 100
        let remainderTen = count % 10

        let noun: String
        if (11...14).contains(remainderHundred) {
            noun = "треков"
        } else {
            switch remainderTen {
            case 1:
                noun = "трек"
            case 2...4:
                noun = "трека"
            default:
                noun = "треков"
            }
        }

        return "\(count) \(noun)"
    }

    /// Форматирует итоговую длительность в минутах либо часах и минутах.
    private static func durationText(for duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        guard hours > 0 else {
            return "\(minutes) мин"
        }

        return "\(hours) ч \(String(format: "%02d", minutes)) мин"
    }

    /// Использует системный форматтер размера файлов и локаль устройства.
    private static func fileSizeText(for size: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: max(0, size),
            countStyle: .file
        )
    }
}
