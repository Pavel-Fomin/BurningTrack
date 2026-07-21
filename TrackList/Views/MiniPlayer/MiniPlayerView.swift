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
    let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    @ObservedObject var playerViewModel: PlayerViewModel
    /// Менеджер общих настроек используется только для сохранения состояния интерфейса.
    private let settingsManager: AppSettingsManager
    /// Обработчик передаёт действия мини-плеера в сценарий представления.
    private let actionHandler: MiniPlayerActionHandler

    /// Состояние раскрытия относится к интерфейсу, а не к состоянию плеера.
    @State private var isExpanded: Bool

    init(
        playerViewModel: PlayerViewModel,
        settingsManager: AppSettingsManager? = nil,
        actionHandler: MiniPlayerActionHandler? = nil
    ) {
        self.playerViewModel = playerViewModel

        let resolvedSettingsManager = settingsManager ?? AppSettingsManager.shared
        self.settingsManager = resolvedSettingsManager
        self.actionHandler = actionHandler ?? MiniPlayerActionHandler(
            playerViewModel: playerViewModel,
            sheetActionCoordinator: SheetActionCoordinator.shared
        )
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

    /// Данные для общей разметки мини-плеера, вычисленные из единого состояния.
    private struct DisplayContent {
        let artwork: UIImage?
        let title: String
        let artist: String
        let currentTime: TimeInterval
        let duration: TimeInterval
        let isPlaying: Bool
    }

    /// Переводит состояние ViewModel в данные для общей разметки мини-плеера.
    private var displayContent: DisplayContent {
        switch playerViewModel.miniPlayerState {
        case .empty:
            return DisplayContent(
                artwork: nil,
                title: "Nothing Playing",
                artist: "",
                currentTime: 0,
                duration: 0,
                isPlaying: false
            )

        case let .playing(staticState, progressState),
             let .paused(staticState, progressState):
            return DisplayContent(
                artwork: staticState.artwork,
                title: staticState.title,
                artist: PlayerPresentationText.miniPlayerArtist(for: staticState.artist),
                currentTime: progressState.currentTime,
                duration: progressState.duration,
                isPlaying: progressState.isPlaying
            )

        case let .loading(staticState):
            return DisplayContent(
                artwork: staticState?.artwork,
                title: staticState?.title ?? "Loading Track",
                artist: staticState.map {
                    PlayerPresentationText.miniPlayerArtist(for: $0.artist)
                } ?? "",
                currentTime: 0,
                duration: 0,
                isPlaying: false
            )

        case .error:
            return DisplayContent(
                artwork: nil,
                title: "Playback Error",
                artist: "",
                currentTime: 0,
                duration: 0,
                isPlaying: false
            )
        }
    }

    var body: some View {
        let content = displayContent
        let hasTrack = playerViewModel.currentTrackDisplayable != nil
        let playbackMode = playerViewModel.playbackMode

        return VStack(spacing: 0) {
            dragIndicator

            MiniPlayerHeaderView(
                artwork: content.artwork,
                title: content.title,
                artist: content.artist,
                isPlaying: content.isPlaying,
                // Пустое состояние не конкурирует визуально с содержимым трека.
                titleColorOverride: hasTrack ? nil : .secondary,
                onPrevious: {
                    guard hasTrack else { return }
                    playerViewModel.playPreviousTrack()
                },
                onPlayPause: {
                    guard hasTrack else { return }
                    playerViewModel.togglePlayPause()
                },
                onNext: {
                    guard hasTrack else { return }
                    playerViewModel.playNextTrack()
                }
            )

            MiniPlayerProgressView(
                currentTime: content.currentTime,
                duration: content.duration,
                onSeek: { time in
                    guard hasTrack else { return }
                    playerViewModel.seek(to: time)
                }
            )

            hitTestBlocker

            if isExpanded {
                MiniPlayerExpandedContent(
                    // Кнопка всегда остаётся в разметке и отключается без доступного действия.
                    showInLibraryAction: actionHandler.canShowCurrentTrackInLibrary ? {
                        actionHandler.handle(.showCurrentTrackInLibrary)
                    } : nil,
                    // В пустом состоянии режимы не должны менять состояние плеера.
                    shuffleAction: hasTrack ? {
                        playerViewModel.toggleShuffle()
                    } : nil,
                    repeatAction: hasTrack ? {
                        playerViewModel.toggleRepeatAll()
                    } : nil,
                    repeatOneAction: hasTrack ? {
                        playerViewModel.toggleRepeatOne()
                    } : nil,
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
    }
}
