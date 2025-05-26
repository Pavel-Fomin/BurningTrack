//
//  ProgressBar.swift
//  TrackList
//
//  Created by Pavel Fomin on 12.05.2025.
//

import Foundation
//
//  ProgressBar.swift
//  TrackList
//
//  Кастомный прогресс-бар для миниплеера
//

import SwiftUI

struct ProgressBar: View {
    var progress: Double    // от 0 до 1
    var onSeek: (Double) -> Void
    var height: CGFloat = 4

    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)

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
    }
}
