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
    /// Передаёт действия всего экрана в экранный action handler.
    let onAction: (PurchasedITunesMusicAction) -> Void
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PurchasedITunesToolbarMenuButton(
                    selectedSortMode: viewModel.sortMode,
                    onSortModeSelection: viewModel.selectSortMode,
                    isExportEnabled: exportableTracks.isEmpty == false,
                    onExport: exportAllTracks
                )
            }
        }
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

        case .loaded:
            tracksList(exportableTracks)
        }
    }

    /// Собирает общий набор адаптеров для списка, playback-контекста и экспорта.
    private var exportableTracks: [PurchasedITunesPlayableTrack] {
        guard case .loaded(let tracks) = viewModel.state else {
            return []
        }

        return tracks.map(PurchasedITunesPlayableTrack.init(track:))
    }

    /// Передаёт все доступные треки раздела в текущем отображаемом порядке.
    private func exportAllTracks() {
        guard exportableTracks.isEmpty == false else { return }
        onAction(.exportTracks(exportableTracks))
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
            .globalBottomScrollReserve()
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
            .onChange(of: tracks.map(\.trackId)) { _, _ in
                // После смены порядка сохраняем существующее поведение фокуса на текущем треке.
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

/// Нативная toolbar-кнопка показывает поддерживаемые действия раздела iTunes.
private struct PurchasedITunesToolbarMenuButton: UIViewRepresentable {
    /// Текущий режим нужен системе для checkmark активного направления.
    let selectedSortMode: PurchasedITunesTrackSortMode
    /// Передаёт пользовательский выбор обратно во ViewModel.
    let onSortModeSelection: (PurchasedITunesTrackSortMode) -> Void
    /// Определяет доступность обычного экспорта загруженного списка.
    let isExportEnabled: Bool
    /// Передаёт экспорт всех доступных треков экранному action handler.
    let onExport: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = String(
            localized: "Purchased in iTunes Actions"
        )
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.menu = makeMenu()
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = makeMenu()
    }

    /// Собирает системное меню, где subtitle и checkmark рисуются UIKit.
    private func makeMenu() -> UIMenu {
        let menu = UIMenu(
            children: [
                makeSortMenu(),
                makeExportAction()
            ]
        )

        // Разрешает системе показать title и subtitle для пункта "Сортировка".
        let displayPreferences = UIMenuDisplayPreferences()
        displayPreferences.maximumNumberOfTitleLines = 2
        menu.displayPreferences = displayPreferences

        return menu
    }

    /// Собирает обычный пункт экспорта по паттерну папок фонотеки.
    private func makeExportAction() -> UIAction {
        UIAction(
            title: String(localized: "Export"),
            image: UIImage(systemName: "externaldrive"),
            attributes: isExportEnabled ? [] : [.disabled]
        ) { _ in
            onExport()
        }
    }

    /// Группирует направления и показывает выбранный режим системной подписью.
    private func makeSortMenu() -> UIMenu {
        let menu = UIMenu(
            title: String(localized: "Sort"),
            image: UIImage(systemName: "arrow.up.arrow.down"),
            children: [
                makeDirectionalSortMenu(
                    title: String(localized: "Artist"),
                    firstTitle: String(localized: "A–Z"),
                    firstMode: .artistAsc,
                    secondTitle: String(localized: "Z–A"),
                    secondMode: .artistDesc
                ),
                makeDirectionalSortMenu(
                    title: String(localized: "Title"),
                    firstTitle: String(localized: "A–Z"),
                    firstMode: .titleAsc,
                    secondTitle: String(localized: "Z–A"),
                    secondMode: .titleDesc
                ),
                makeDirectionalSortMenu(
                    title: String(localized: "Album"),
                    firstTitle: String(localized: "A–Z"),
                    firstMode: .albumAsc,
                    secondTitle: String(localized: "Z–A"),
                    secondMode: .albumDesc
                ),
                makeDirectionalSortMenu(
                    title: String(localized: "Year"),
                    firstTitle: String(localized: "Newest First"),
                    firstMode: .yearDesc,
                    secondTitle: String(localized: "Oldest First"),
                    secondMode: .yearAsc
                ),
                makeDirectionalSortMenu(
                    title: String(localized: "Genre"),
                    firstTitle: String(localized: "A–Z"),
                    firstMode: .genreAsc,
                    secondTitle: String(localized: "Z–A"),
                    secondMode: .genreDesc
                ),
                makeDirectionalSortMenu(
                    title: String(localized: "Date Added"),
                    firstTitle: String(localized: "Newest First"),
                    firstMode: .dateAddedDesc,
                    secondTitle: String(localized: "Oldest First"),
                    secondMode: .dateAddedAsc
                )
            ]
        )
        menu.subtitle = LibraryPresentationText.purchasedITunesTrackSortModeTitle(
            for: selectedSortMode
        )
        return menu
    }

    /// Создаёт single-selection подменю с системным checkmark.
    private func makeDirectionalSortMenu(
        title: String,
        firstTitle: String,
        firstMode: PurchasedITunesTrackSortMode,
        secondTitle: String,
        secondMode: PurchasedITunesTrackSortMode
    ) -> UIMenu {
        UIMenu(
            title: title,
            options: .singleSelection,
            children: [
                makeSortAction(title: firstTitle, mode: firstMode),
                makeSortAction(title: secondTitle, mode: secondMode)
            ]
        )
    }

    /// Создаёт направление сортировки и отмечает выбранный режим.
    private func makeSortAction(
        title: String,
        mode: PurchasedITunesTrackSortMode
    ) -> UIAction {
        UIAction(
            title: title,
            state: selectedSortMode == mode ? .on : .off
        ) { _ in
            onSortModeSelection(mode)
        }
    }
}
