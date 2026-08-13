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
    /// View передаёт только typed-намерения в стабильный handler screen store.
    let onAction: (PurchasedITunesTrackAction) -> Void

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
            isCurrent: state.isCurrent,
            isPlaying: state.isPlaying,
            isHighlighted: false,
            artworkRequest: state.artworkRequest,
            artworkBadgeState: state.artworkBadgeState,
            title: state.title,
            artist: state.artist,
            duration: state.duration,
            onRowTap: play,
            onUnavailableTap: {
                onAction(.unavailableTrackTapped(track: state.track))
            },
            showsFileFormat: false
        ) {
            purchasedITunesActionMenuContent
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Заглушка копирования ничего не пишет на диск.
            if isMenuActionAvailable(.copy) {
                Button {
                    onAction(.copy(track: state.track))
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(.gray)
            }

            // Отправляем намерение добавления в треклист обработчику действий.
            if isMenuActionAvailable(.addToTrackList) {
                Button {
                    onAction(.addToTrackList(track: state.track))
                } label: {
                    Label("Add to Tracklist", systemImage: "list.star")
                }
                .tint(.green)
            }

            // Отправляем намерение добавления в очередь плеера обработчику действий.
            if isMenuActionAvailable(.addToPlayer) {
                Button {
                    onAction(.addToPlayer(track: state.track))
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
                onAction(.details(track: state.track))
            } label: {
                Label("Track Info", systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.toggleFavorite) {
            TrackFavoriteMenuContent(
                isFavorite: state.isFavorite,
                onToggle: {
                    onAction(.toggleFavorite(track: state.track))
                }
            )
        }

        if isMenuActionAvailable(.share) {
            Button {
                onAction(.share(track: state.track))
            } label: {
                Label(
                    TrackSharePresentationText.actionTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if isMenuActionAvailable(.copy) {
            Button {
                onAction(.copy(track: state.track))
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }

        TrackAddDestinationMenuContent(
            canAddToPlayer: isMenuActionAvailable(.addToPlayer),
            canAddToTrackList: isMenuActionAvailable(.addToTrackList),
            addToTitle: String(localized: "Add to"),
            addToPlayerTitle: String(localized: "Add to Player"),
            addToTrackListTitle: String(localized: "Add to Tracklist"),
            onAddToPlayer: {
                onAction(.addToPlayer(track: state.track))
            },
            onAddToTrackList: {
                onAction(.addToTrackList(track: state.track))
            }
        )
    }

    /// Передаёт iTunes-трек в screen store, который добавляет актуальный отображаемый контекст.
    private func play() {
        onAction(.play(track: state.track))
    }
}
