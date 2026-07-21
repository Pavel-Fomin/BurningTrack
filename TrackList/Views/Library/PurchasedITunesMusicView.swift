//
//  PurchasedITunesMusicView.swift
//  TrackList
//
//  Экран виртуального источника купленных треков iTunes.
//  Запрашивает доступ к системной медиатеке и показывает локальные треки без копирования.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import SwiftUI

struct PurchasedITunesMusicView: View {

    // MARK: - Входные данные

    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Модель представления

    /// Модель представления владеет запросом доступа и чтением системной медиатеки.
    @StateObject private var viewModel = PurchasedITunesMusicViewModel()

    // MARK: - Интерфейс

    var body: some View {
        content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Purchased in iTunes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView

        case .denied:
            messageView("Media Library Access Unavailable")

        case .empty:
            messageView("No local iTunes tracks available for copying.")

        case .loaded(let tracks):
            // Один раз собираем адаптеры для строки и контекста воспроизведения из одного списка медиатеки.
            tracksList(
                tracks.map { track in
                    PurchasedITunesPlayableTrack(track: track)
                }
            )
        }
    }

    /// Показывает состояние чтения системной медиатеки.
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text("Reading Media Library…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    /// Показывает короткое текстовое состояние экрана.
    private func messageView(
        _ message: String
    ) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    /// Показывает список локальных треков, найденных в системной медиатеке.
    private func tracksList(
        _ tracks: [PurchasedITunesPlayableTrack]
    ) -> some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    ForEach(tracks) { track in
                        PurchasedITunesTrackRowContainer(
                            track: track,
                            context: tracks,
                            playerViewModel: playerViewModel
                        )
                        .id(track.trackId)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                scrollToCurrentTrackIfNeeded(
                    using: proxy,
                    tracks: tracks,
                    animated: false
                )
            }
            .onChange(of: playerViewModel.currentTrackDisplayable?.trackId) { _, _ in
                scrollToCurrentTrackIfNeeded(
                    using: proxy,
                    tracks: tracks,
                    animated: true
                )
            }
            .onChange(of: playerViewModel.currentContext) { _, _ in
                scrollToCurrentTrackIfNeeded(
                    using: proxy,
                    tracks: tracks,
                    animated: true
                )
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                scrollToCurrentTrackIfNeeded(
                    using: proxy,
                    tracks: tracks,
                    animated: true
                )
            }
        }
    }

    /// Находит текущий iTunes-трек внутри отображаемого списка.
    private func currentPurchasedITunesTrackId(
        in tracks: [PurchasedITunesPlayableTrack]
    ) -> UUID? {
        guard playerViewModel.currentContext == .purchasedITunes,
              let currentTrackId = playerViewModel.currentTrackDisplayable?.trackId,
              tracks.contains(where: { $0.trackId == currentTrackId }) else {
            return nil
        }

        return currentTrackId
    }

    /// Прокручивает список к текущему iTunes-треку, если он есть на экране.
    private func scrollToCurrentTrackIfNeeded(
        using proxy: ScrollViewProxy,
        tracks: [PurchasedITunesPlayableTrack],
        animated: Bool
    ) {
        guard let targetTrackId = currentPurchasedITunesTrackId(
            in: tracks
        ) else {
            return
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(targetTrackId, anchor: .center)
            }
        } else {
            proxy.scrollTo(targetTrackId, anchor: .center)
        }
    }
}
