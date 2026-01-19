//
//  ToastData.swift
//  TrackList
//
//  Универсальная модель для отображения тостов
//
//  Created by Pavel Fomin on 08.07.2025.
//

import SwiftUI

struct ToastData: Identifiable, Equatable {

    enum Style: Equatable {
        case track(title: String, artist: String)
        case trackList(name: String)
    }

    let id = UUID()
    let style: Style

    /// Готовое изображение для тоста.
    /// Формируется через ArtworkProvider (.toast)
    /// ToastView ничего не знает о размерах, данных и декодировании.
    let artworkImage: Image?

    let message: String

    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.style == rhs.style && lhs.message == rhs.message
    }
}
