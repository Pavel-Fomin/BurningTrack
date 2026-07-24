//
//  TimeFormatter.swift
//  TrackList
//
//  Вспомогательные функции для форматирования времени и дат
//
//  Created by Pavel Fomin on 29.04.2025.
//

import Foundation


// MARK: - Формирует подпись к треклисту на основе даты создания

// В этом году: "15 июн 14:20"
// В прошлом году: "15 июн 2024"
func formatTrackListLabel(from date: Date) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let year = calendar.component(.year, from: date)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")

        if currentYear == year {
            formatter.dateFormat = "d MMM HH:mm"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }

        return formatter.string(from: date)
    }


// MARK: - Возвращает название треклиста в формате: "06.11.25, 23:24"

func generateDefaultTrackListName() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "dd.MM.yy, HH:mm"
    return formatter.string(from: Date())
}
