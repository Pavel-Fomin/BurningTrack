//
//  BatchArtworkCompressionOption.swift
//  TrackList
//
//  Вариант сжатия обложки при массовом редактировании тегов.
//
//  Created by Pavel Fomin on 11.06.2026.
//

import Foundation

/// Вариант сжатия обложки по максимальному размеру стороны.
enum BatchArtworkCompressionOption: CaseIterable, Equatable, Hashable {
    /// 256×256 px.
    case small
    /// 512×512 px.
    case medium
    /// 1024×1024 px.
    case large

    /// Максимальный размер стороны изображения в пикселях.
    var maxPixelSize: Int {
        switch self {
        case .small:
            return 256
        case .medium:
            return 512
        case .large:
            return 1024
        }
    }

}
