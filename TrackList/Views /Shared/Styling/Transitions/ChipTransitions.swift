//
//  ChipTransitions.swift
//  TrackList
//
//  Анимированные переходы для чипов (плейлистов)
//  Используются при добавлении, удалении и появлении/скрытии чипов в UI.
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

// MARK: - Кастомные переходы для анимации чипов
extension AnyTransition {
    
    /// Переход при вставке чипа: масштаб + прозрачность
    static var chipInsertion: AnyTransition {
        .scale.combined(with: .opacity)
    }

    /// Переход при удалении чипа: прозрачность + масштаб
    static var chipRemoval: AnyTransition {
        .opacity.combined(with: .scale)
    }

    /// Асимметричный переход: разные анимации для появления и исчезновения
    static var chipAppearDisappear: AnyTransition {
        .asymmetric(insertion: .chipInsertion, removal: .chipRemoval)
    }
}
