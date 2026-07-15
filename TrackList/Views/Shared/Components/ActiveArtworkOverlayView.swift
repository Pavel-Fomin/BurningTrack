//
//  ActiveArtworkOverlayView.swift
//  TrackList
//
//  Общий индикатор текущего воспроизводимого элемента поверх обложки.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import SwiftUI

struct ActiveArtworkOverlayView: View {

    // MARK: - Входные данные

    /// Определяет, должна ли иконка показывать анимацию воспроизведения.
    let isPlaying: Bool

    // MARK: - UI

    var body: some View {
        ZStack {
            // Затемнение обеспечивает читаемость белой иконки на любой обложке.
            Color.black.opacity(0.26)

            Image(systemName: "waveform.mid")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                // При паузе иконка остаётся видимой, но прекращает анимацию.
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers.nonReversing,
                    options: .repeat(.continuous),
                    isActive: isPlaying
                )
        }
    }
}
