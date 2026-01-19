//
//  LibraryTransitionModifier.swift
//  TrackList
//
//  Анимация переходов между экранами фонотеки (папками)
//
//  Created by Pavel Fomin on 01.11.2025.
//

import SwiftUI

struct LibraryTransitionModifier: ViewModifier {
    
    func body(content: Content) -> some View {content
    
// MARK: - Отладочные логи (можно отключить)
        
        .onAppear { print("🌀 LibraryTransition вставка") }          /// экран появляется
            .onDisappear { print("💨 LibraryTransition удаление") }  /// экран уходит
            
// MARK: - Основная анимация перехода
        
            .transition(
                .asymmetric(
                    
                    //Появление нового экрана (анимация "вперёд")
                    insertion:
                        .move(edge: .trailing)                                        /// появляется справа
                        .combined(with: .opacity.animation(.easeOut(duration: 0.28))) /// плавное проявление
                        .combined(with: .scale(scale: 1.03, anchor: .trailing)),      /// лёгкое увеличение при входе
                        
                    // Удаление старого экрана (анимация "назад")
                    removal:
                        .move(edge: .leading)                                         /// уходит влево
                        .combined(with: .opacity.animation(.easeIn(duration: 0.28)))  /// плавное затухание
                        .combined(with: .scale(scale: 0.97, anchor: .leading))        /// лёгкое сжатие при уходе
                )
            )
            
        
// MARK: - Кривая и длительность анимации
        
            .animation(
                .timingCurve(
                    0.22, 0.8, 0.3, 1,   /// кривая: более «живая» и плавная, чем стандартный easeInOut
                    duration: 0.42       /// чуть длиннее — визуально совпадает с iOS 26
                ),
                value: true              /// анимация активна всегда (без привязки к конкретному состоянию)
            )
    }
}


// MARK: - Универсальный модификатор анимации перехода между экранами фонотеки

extension View {
    func libraryTransition() -> some View {
        modifier(LibraryTransitionModifier())
    }
}
