//
//  LibraryTransitionModifier.swift
//  TrackList
//
//  Задаёт асимметричную анимацию переходов между папками фонотеки.
//
//  Created by Pavel Fomin on 01.11.2025.
//

import SwiftUI

struct LibraryTransitionModifier: ViewModifier {
    
    func body(content: Content) -> some View {content
    
        .onAppear { print("🌀 LibraryTransition вставка") }
            .onDisappear { print("💨 LibraryTransition удаление") }

            // Разные края сохраняют направление при входе в destination и возврате из него.
            .transition(
                .asymmetric(
                    insertion:
                        .move(edge: .trailing)
                        .combined(with: .opacity.animation(.easeOut(duration: 0.28)))
                        .combined(with: .scale(scale: 1.03, anchor: .trailing)),

                    removal:
                        .move(edge: .leading)
                        .combined(with: .opacity.animation(.easeIn(duration: 0.28)))
                        .combined(with: .scale(scale: 0.97, anchor: .leading))
                )
            )

            .animation(
                .timingCurve(
                    0.22, 0.8, 0.3, 1,
                    duration: 0.42
                ),
                value: true
            )
    }
}


extension View {
    func libraryTransition() -> some View {
        modifier(LibraryTransitionModifier())
    }
}
