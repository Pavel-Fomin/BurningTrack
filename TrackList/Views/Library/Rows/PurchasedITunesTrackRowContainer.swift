//
//  PurchasedITunesTrackRowContainer.swift
//  TrackList
//
//  Контейнер строки трека iTunes.
//  Адаптер для TrackRowView без логики LibraryTrack и без копирования файла.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import SwiftUI

struct PurchasedITunesTrackRowContainer: View {

    // MARK: - Входные данные

    let state: PurchasedITunesTrackRowState
    let context: [PurchasedITunesPlayableTrack]
    @ObservedObject var playerViewModel: PlayerViewModel

    // MARK: - Обработчик действий

    /// Обработчик пользовательских действий строки iTunes.
    private var actionHandler: PurchasedITunesTrackActionHandler {
        PurchasedITunesTrackActionHandler(
            playerViewModel: playerViewModel
        )
    }

    // MARK: - Состояние

    /// Проверяет, является ли строка текущим iTunes-треком плеера.
    private var isCurrent: Bool {
        actionHandler.isCurrent(state.track)
    }

    /// Проверяет, играет ли текущий iTunes-трек.
    private var isPlaying: Bool {
        actionHandler.isPlaying(state.track)
    }

    /// Проверяет доступность пункта меню для раздела "Куплено в iTunes".
    private func isMenuActionAvailable(
        _ action: TrackMenuAction
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: .purchasedITunes,
            context: .purchasedITunes
        )
    }

    // MARK: - Интерфейс

    var body: some View {
        TrackRowView(
            track: state.track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: false,
            artworkRequest: state.artworkRequest,
            artworkBadgeState: state.artworkBadgeState,
            title: state.title,
            artist: state.artist,
            duration: state.duration,
            onRowTap: play,
            showsFileFormat: false
        ) {
            purchasedITunesActionMenuContent
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Заглушка копирования ничего не пишет на диск.
            if isMenuActionAvailable(.copy) {
                Button {
                    actionHandler.handle(.copy(track: state.track))
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(.gray)
            }

            // Отправляем намерение добавления в треклист обработчику действий.
            if isMenuActionAvailable(.addToTrackList) {
                Button {
                    actionHandler.handle(.addToTrackList(track: state.track))
                } label: {
                    Label("Add to Tracklist", systemImage: "list.star")
                }
                .tint(.green)
            }

            // Отправляем намерение добавления в очередь плеера обработчику действий.
            if isMenuActionAvailable(.addToPlayer) {
                Button {
                    actionHandler.handle(.addToPlayer(track: state.track))
                } label: {
                    Label("Add to Player", systemImage: "waveform")
                }
                .tint(.blue)
            }
        }
    }

    /// Меню действий iTunes-строки использует те же action и handler, что и свайпы.
    @ViewBuilder
    private var purchasedITunesActionMenuContent: some View {
        // Открытие карточки "О треке" остаётся намерением View и выполняется обработчиком.
        if isMenuActionAvailable(.details) {
            Button {
                actionHandler.handle(.details(track: state.track))
            } label: {
                Label("Track Info", systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.share) {
            Button {
                actionHandler.handle(.share(track: state.track))
            } label: {
                Label(
                    TrackSharePresentationText.actionTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if isMenuActionAvailable(.copy) {
            Button {
                actionHandler.handle(.copy(track: state.track))
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }

        if isMenuActionAvailable(.addToTrackList) {
            Button {
                actionHandler.handle(.addToTrackList(track: state.track))
            } label: {
                Label("Add to Tracklist", systemImage: "list.star")
            }
        }

        if isMenuActionAvailable(.addToPlayer) {
            Button {
                actionHandler.handle(.addToPlayer(track: state.track))
            } label: {
                Label("Add to Player", systemImage: "waveform")
            }
        }
    }

    /// Передаёт iTunes-трек в общий механизм воспроизведения вместе со всем контекстом списка.
    private func play() {
        actionHandler.handle(
            .play(
                track: state.track,
                context: context
            )
        )
    }
}
