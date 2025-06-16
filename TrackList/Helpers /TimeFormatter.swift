//
//  TimeFormatter.swift
//  TrackList
//
//  Вспомогательные функции для форматирования времени и дат
//
//  Created by Pavel Fomin on 29.04.2025.
//

import Foundation

/// Форматирует длительность трека в строку:
/// до 1 часа:     "03:27"
/// от 1 часа:     "01h:12m"
/// от суток:      "1d:03h:12m"
/// если значение некорректно — возвращает "–:–"
func formatTimeSmart(_ duration: TimeInterval) -> String {
    guard duration.isFinite && duration > 0 else { return "–:–" }
    
    let totalMinutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    let days = hours / 24
    let remainingHours = hours % 24
    
    if days > 0 {
        return String(format: "%dd:%02dh:%02dm", days, remainingHours, minutes)
    } else if hours > 0 {
        return String(format: "%02dh:%02dm", hours, minutes)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }

 }

/// Формирует подпись к треклисту на основе даты создания:
/// В этом году: "15 июн 14:20"
/// В прошлом году: "15 июн 2024"
func formatTrackListLabel(from date: Date) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let year = calendar.component(.year, from: date)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")

        if currentYear == year {
            formatter.dateFormat = "d MMM HH:mm"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }

        return formatter.string(from: date)
    }

