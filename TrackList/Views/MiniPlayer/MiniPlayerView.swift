//
//  MiniPlayerView.swift
//  TrackList
//
//  Мини-плеер.
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct MiniPlayerView: View {
    let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    @ObservedObject var playerViewModel: PlayerViewModel
    /// Менеджер общих настроек используется только для сохранения состояния интерфейса.
    private let settingsManager: AppSettingsManager

    /// Состояние раскрытия относится к интерфейсу, а не к состоянию плеера.
    @State private var isExpanded: Bool

    init(
        playerViewModel: PlayerViewModel,
        settingsManager: AppSettingsManager? = nil
    ) {
        self.playerViewModel = playerViewModel

        let resolvedSettingsManager = settingsManager ?? AppSettingsManager.shared
        self.settingsManager = resolvedSettingsManager
        _isExpanded = State(
            initialValue: resolvedSettingsManager.settings.internalSettings.isMiniPlayerExpanded
        )
    }

    /// Изменяет состояние карточки и сохраняет его после фактического изменения интерфейса.
    private func setExpanded(_ newValue: Bool) {
        guard newValue != isExpanded else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded = newValue
        }

        settingsManager.setMiniPlayerExpanded(newValue)
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
        guard let track = playerViewModel.currentTrackDisplayable else { return AnyView(EmptyView()) }
        let staticState = playerViewModel.miniPlayerStaticState
        let title = staticState?.title ?? track.fileName
        let artist = staticState?.artist ?? ""
        let artwork = staticState?.artwork
        let currentTime = playerViewModel.miniPlayerCurrentTime
        let duration = playerViewModel.miniPlayerDuration
        let playbackMode = playerViewModel.playbackMode

        return AnyView(
            VStack(spacing: 0) {
                dragIndicator

                MiniPlayerHeaderView(
                    artwork: artwork,
                    title: title,
                    artist: artist,
                    isPlaying: playerViewModel.isPlaying,
                    onPrevious: {
                        playerViewModel.playPreviousTrack()
                    },
                    onPlayPause: {
                        playerViewModel.togglePlayPause()
                    },
                    onNext: {
                        playerViewModel.playNextTrack()
                    }
                )

                MiniPlayerProgressView(
                    currentTime: currentTime,
                    duration: duration,
                    onSeek: { time in
                        playerViewModel.seek(to: time)
                    }
                )

                hitTestBlocker

                if isExpanded {
                    MiniPlayerExpandedContent(
                        shuffleAction: {
                            playerViewModel.toggleShuffle()
                        },
                        repeatAction: {
                            playerViewModel.toggleRepeatAll()
                        },
                        repeatOneAction: {
                            playerViewModel.toggleRepeatOne()
                        },
                        airPlayAction: nil,
                        isShuffleEnabled: playbackMode.isShuffleEnabled,
                        isRepeatAllEnabled: playbackMode.repeatMode == .all,
                        isRepeatOneEnabled: playbackMode.repeatMode == .one
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
            // Одновременное распознавание не блокирует горизонтальный seek прогресс-бара.
            .simultaneousGesture(presentationGesture)
            .padding(.horizontal, 16)
        )
    }
}
