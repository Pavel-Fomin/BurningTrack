//
//  ArtworkPreparationRequest.swift
//  TrackList
//
//  Параметры подготовки обложки.
//
//  Created by Pavel Fomin on 12.06.2026.
//

import CoreGraphics
import Foundation

/// Параметры подготовки обложки.
struct ArtworkPreparationRequest {
    /// Исходные данные изображения.
    let imageData: Data
    /// Максимальный размер стороны изображения в пикселях.
    let maxPixelSize: Int
    /// Качество JPEG-компрессии.
    let compressionQuality: CGFloat
}
