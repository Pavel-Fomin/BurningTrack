//
//  ToastData.swift
//  TrackList
//
//  Универсальная модель для отображения тостов
//
//  Created by Pavel Fomin on 08.07.2025.
//

import Foundation

struct ToastData: Identifiable, Equatable {

    enum Style: Equatable {
        case track(title: String, artist: String)
        case trackList(name: String)
    }

    let id = UUID()
    let style: Style

    /// Лёгкий запрос обложки для асинхронной подписки тоста.
    let artworkRequest: ArtworkRequest?

    let message: String

    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.style == rhs.style && lhs.message == rhs.message
    }
}
