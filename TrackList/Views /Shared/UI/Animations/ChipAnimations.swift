//
//  ChipAnimations.swift
//  TrackList
//
//  Анимации, используемые для чипов плейлистов (например, при входе в режим редактирования)
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

extension Animation {
    /// Пружинная анимация для перемещения чипов
    static let chipSpring = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7,
        blendDuration: 0.1
    )

    /// Базовая анимация при включении/выключении режима редактирования
    static let chipEditMode = Animation.default
}
