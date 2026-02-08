//
//  ProgressBar.swift
//  TrackList
//
//  Кастомный прогресс-бар для миниплеера
//
//  Created by Pavel Fomin on 12.05.2025.
//

import SwiftUI

struct ProgressBar: View {
    /// Прогресс воспроизведения (от 0 до 1)
    var progress: Double
    
    /// Обработчик перемотки
    var onSeek: (Double) -> Void
    
    /// Высота прогресс-бара
    var height: CGFloat = 4

    /// Состояние перетаскивания
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                // Задний трек
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)

                // Передний трек (прогресс)
                Capsule()
                    .fill(Color.blue)
                    .frame(width: CGFloat(progress) * width, height: height)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onEnded { value in
                        let location = value.location.x
                        let ratio = min(max(location / width, 0), 1)
                        onSeek(ratio)
                    }
            )
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
    }
}
