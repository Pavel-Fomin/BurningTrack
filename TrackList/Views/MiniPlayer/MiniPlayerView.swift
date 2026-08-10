//
//  MiniPlayerView.swift
//  TrackList
//
//  Мини-плеер.
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UIKit

struct MiniPlayerView: View {
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    /// Готовое presentation-состояние не раскрывает View playback- и domain-зависимости.
    let state: MiniPlayerScreenState
    /// Единственный выход внешних пользовательских намерений из чистой View.
    let onAction: (MiniPlayerAction) -> Void

    /// Состояние раскрытия относится к интерфейсу, а не к состоянию плеера.
    @State private var isExpanded: Bool

    init(
        state: MiniPlayerScreenState,
        onAction: @escaping (MiniPlayerAction) -> Void
    ) {
        self.state = state
        self.onAction = onAction
        _isExpanded = State(
            initialValue: state.initialIsExpanded
        )
    }

    /// Немедленно меняет локальное состояние карточки и отдельно передаёт persistence-действие.
    private func setExpanded(_ newValue: Bool) {
        guard newValue != isExpanded else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded = newValue
        }

        onAction(.setExpanded(newValue))
    }

    /// Визуальный индикатор сохраняет прозрачную зону, которая гасит жесты только в пустых местах карточки.
    private var dragIndicator: some View {
        Color.black.opacity(0.001)
            .frame(height: 8)
            .contentShape(Rectangle())
            .overlay {
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 35, height: 4)
                    // Поднимаем только сам индикатор внутри сохранённой зоны жеста.
                    .padding(.bottom, 4)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
            )
    }

    /// Почти прозрачная зона, которая гасит жесты только в пустых местах карточки.
    private var hitTestBlocker: some View {
        Color.black.opacity(0.001)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
            )
    }

    /// Жест раскрытия карточки, отделённый от основной компоновки.
    private var presentationGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let verticalDistance = value.translation.height
                let horizontalDistance = value.translation.width
                let threshold: CGFloat = 48

                // Карточка реагирует только на выраженное вертикальное движение.
                guard abs(verticalDistance) > abs(horizontalDistance),
                      abs(verticalDistance) >= threshold else {
                    return
                }

                let newExpansionState = verticalDistance < 0
                setExpanded(newExpansionState)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator

            MiniPlayerHeaderView(
                artworkRequest: state.artworkRequest,
                title: state.title,
                artist: state.artist,
                isPlaying: state.isPlaying,
                isFavorite: state.isFavorite,
                isFavoriteEnabled: state.isFavoriteEnabled,
                // Пустое состояние не конкурирует визуально с содержимым трека.
                titleColorOverride: state.isPlaybackEnabled ? nil : .secondary,
                onContentTap: {
                    guard state.isPlaybackEnabled else { return }
                    onAction(.playPause)
                },
                onContentSwipePrevious: {
                    guard state.isPlaybackEnabled else { return }
                    onAction(.playPrevious)
                },
                onContentSwipeNext: {
                    guard state.isPlaybackEnabled else { return }
                    onAction(.playNext)
                },
                onFavorite: {
                    guard state.isFavoriteEnabled else { return }
                    onAction(.toggleFavorite)
                }
            )

            MiniPlayerProgressView(
                currentTime: state.currentTime,
                duration: state.duration,
                waveformState: state.waveformState,
                onSeek: { time in
                    guard state.isPlaybackEnabled else { return }
                    onAction(.seek(time))
                }
            )

            hitTestBlocker

            if isExpanded {
                MiniPlayerExpandedContent(
                    // Кнопка всегда остаётся в разметке и отключается без доступного действия.
                    showInLibraryAction: state.canShowCurrentTrackInLibrary ? {
                        onAction(.showCurrentTrackInLibrary)
                    } : nil,
                    // В пустом состоянии режимы не должны менять состояние плеера.
                    shuffleAction: state.isPlaybackEnabled ? {
                        onAction(.toggleShuffle)
                    } : nil,
                    repeatAction: state.isPlaybackEnabled ? {
                        onAction(.toggleRepeatAll)
                    } : nil,
                    repeatOneAction: state.isPlaybackEnabled ? {
                        onAction(.toggleRepeatOne)
                    } : nil,
                    airPlayAction: nil,
                    isShuffleEnabled: state.isShuffleEnabled,
                    isRepeatAllEnabled: state.isRepeatAllEnabled,
                    isRepeatOneEnabled: state.isRepeatOneEnabled
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: shape)
        .clipShape(shape)
        .contentShape(shape)
        // Одновременное распознавание не блокирует горизонтальный seek waveform.
        .simultaneousGesture(presentationGesture)
        .padding(.horizontal, 16)
    }
}
