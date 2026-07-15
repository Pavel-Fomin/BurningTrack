//
//  MiniPlayerTransportControlsView.swift
//  TrackList
//
//  Общие основные кнопки управления мини-плеером.
//
//  Created by Pavel Fomin on 14.07.2026.
//

import SwiftUI

struct MiniPlayerTransportControlsView: View {

    // MARK: - Input

    let isPlaying: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    // MARK: - UI

    var body: some View {
        HStack(spacing: 0) {
            controlButton(
                systemName: "backward.end.fill",
                accessibilityLabel: "Предыдущий трек",
                action: onPrevious
            )

            controlButton(
                systemName: isPlaying ? "pause.fill" : "play.fill",
                accessibilityLabel: isPlaying ? "Пауза" : "Воспроизвести",
                action: onPlayPause
            )

            controlButton(
                systemName: "forward.end.fill",
                accessibilityLabel: "Следующий трек",
                action: onNext
            )
        }
    }

    // MARK: - Button

    /// Создаёт одинаковую зону нажатия для каждой основной кнопки.
    private func controlButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
