//
//  ArtworkSizeClass.swift
//  TrackList
//
//  Канонические классы размеров подготовленных обложек.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import CoreGraphics

/// Ограничивает подсистему обложек двумя подготовленными вариантами одного источника.
enum ArtworkSizeClass: String, CaseIterable, Hashable, Sendable {
    /// Компактная обложка для строк и небольших карточек.
    case small
    /// Крупная обложка для плеера, Now Playing и крупных редакторов.
    case large

    /// Канонический размер изображения в пикселях, передаваемый ImageIO.
    var pixelSize: CGSize {
        switch self {
        case .small:
            CGSize(width: 96, height: 96)
        case .large:
            CGSize(width: 512, height: 512)
        }
    }

    /// Наибольшая сторона канонического квадратного thumbnail.
    var maxPixel: Int {
        Int(pixelSize.width)
    }
}
