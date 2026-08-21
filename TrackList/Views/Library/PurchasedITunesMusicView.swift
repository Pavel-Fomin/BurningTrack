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

    /// Готовый снимок не раскрывает View provider-ы, handler-ы и domain-зависимости.
    let state: PurchasedITunesScreenState
    /// Одноразовый intent прокрутки к треку, полученный из общего сценария фонотеки.
    let revealRequest: LibraryRevealRequest?
    /// Подтверждает владельцу общего reveal-intent завершение обработки прокрутки.
    let onRevealHandled: (UUID) -> Void
    /// Передаёт действия всего экрана в экранный action handler.
    let onAction: (PurchasedITunesMusicAction) -> Void
    /// Передаёт действия строки стабильному handler-у из ScreenStore.
    let onTrackAction: (PurchasedITunesTrackAction) -> Void
    /// Общая UI-политика auto-scroll не объединяет iTunes identity с queue или track-list row identity.
    @StateObject private var automaticScrollCoordinator = AutomaticListScrollCoordinator()
    /// Последний reveal остаётся pending, пока список занят программной или ручной прокруткой.
    @State private var pendingRevealRequest: LibraryRevealRequest?

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
                    selectedSortMode: state.sortMode,
                    onSortModeSelection: {
                        onAction(.sortModeSelected($0))
                    },
                    isExportEnabled: state.canExport,
                    onExport: {
                        onAction(.exportTracks)
                    }
                )
            }
        }
        .task {
            onAction(.appeared)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.content {
        case .loading:
            loadingView

        case .denied:
            messageView(LibraryPresentationText.purchasedITunesAccessUnavailableMessage)

        case .empty:
            messageView(LibraryPresentationText.purchasedITunesEmptyMessage)

        case .loaded(let rows):
            tracksList(rows: rows, tracks: state.tracks)
        }
    }

    /// Показывает состояние чтения системной медиатеки.
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text(LibraryPresentationText.purchasedITunesLoadingMessage)
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
        rows: [PurchasedITunesTrackRowState],
        tracks: [PurchasedITunesPlayableTrack]
    ) -> some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    ForEach(rows, id: \.track.id) { rowState in
                        PurchasedITunesTrackRowContainer(
                            state: rowState,
                            onAction: onTrackAction
                        )
                        .id(rowState.track.id)
                    }
                }
            }
            .listStyle(.plain)
            .globalBottomScrollReserve()
            .scrollContentBackground(.hidden)
            .onAppear {
                receiveRevealRequest(revealRequest)
                revealTrackIfPossible(
                    using: proxy,
                    tracks: tracks
                )
                requestInitialScrollIfNeeded(rows: rows)
            }
            .onChange(of: revealRequest?.requestId) { _, _ in
                receiveRevealRequest(revealRequest)
                revealTrackIfPossible(
                    using: proxy,
                    tracks: tracks
                )
            }
            .onChange(of: currentTrackID(in: rows)) { _, _ in
                requestActiveTrackScrollIfNeeded(rows: rows)
            }
            .onChange(of: state.automaticListScrollTrigger) { _, trigger in
                requestExplicitPlaybackNavigationScrollIfNeeded(
                    trigger,
                    rows: rows,
                    using: proxy
                )
            }
            .onChange(of: tracks.map(\.trackId)) { _, _ in
                // Reveal остаётся выше auto-focus и получает первую попытку после смены данных.
                revealTrackIfPossible(
                    using: proxy,
                    tracks: tracks
                )
                requestExplicitPlaybackNavigationScrollIfNeeded(
                    state.automaticListScrollTrigger,
                    rows: rows,
                    using: proxy
                )
                requestActiveTrackScrollIfNeeded(rows: rows)
            }
            .onChange(of: automaticScrollCoordinator.pendingScrollRequest) { _, request in
                handleScrollRequest(
                    request,
                    using: proxy,
                    rows: rows
                )
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .idle,
                   pendingRevealRequest != nil {
                    // Reveal получает приоритет до materialization отложенного MiniPlayer intent.
                    automaticScrollCoordinator.discardExplicitPlaybackNavigationForReveal()
                }
                handleScrollRequest(
                    automaticScrollCoordinator.receiveScrollPhase(
                        ListScrollPhase(newPhase)
                    ),
                    using: proxy,
                    rows: rows
                )

                // Ожидающий reveal может стартовать только после завершения физической или программной прокрутки.
                guard newPhase == .idle else { return }
                revealTrackIfPossible(
                    using: proxy,
                    tracks: tracks
                )
            }
        }
    }

    /// Возвращает идентификатор строки, уже помеченной Presenter-ом как текущая.
    private func currentTrackID(
        in rows: [PurchasedITunesTrackRowState]
    ) -> UUID? {
        rows.first(where: \.isCurrent)?.track.id
    }

    /// Передаёт первый active track в UI-policy только после появления строк iTunes.
    private func requestInitialScrollIfNeeded(
        rows: [PurchasedITunesTrackRowState]
    ) {
        let targetTrackId = currentTrackID(in: rows)
        automaticScrollCoordinator.requestInitialScrollIfNeeded(
            targetId: targetTrackId,
            isTargetAvailable: rows.contains { $0.track.id == targetTrackId }
        )
    }

    /// Смена текущего iTunes-трека не возвращает список после ручного позиционирования.
    private func requestActiveTrackScrollIfNeeded(
        rows: [PurchasedITunesTrackRowState]
    ) {
        guard pendingRevealRequest == nil else {
            return
        }

        let targetTrackId = currentTrackID(in: rows)
        automaticScrollCoordinator.requestActiveTrackScrollIfNeeded(
            targetId: targetTrackId,
            isTargetAvailable: rows.contains { $0.track.id == targetTrackId }
        )
    }

    /// Явная навигация MiniPlayer центрирует только текущую строку iTunes и не опережает reveal.
    private func requestExplicitPlaybackNavigationScrollIfNeeded(
        _ trigger: AutomaticListScrollTrigger?,
        rows: [PurchasedITunesTrackRowState],
        using proxy: ScrollViewProxy
    ) {
        guard pendingRevealRequest == nil,
              let trigger,
              trigger.targetContext == .purchasedITunes,
              trigger.targetDisplayableId == currentTrackID(in: rows) else {
            return
        }

        // Явная команда materialize в текущем обновлении списка и не зависит от второго Published-callback.
        handleScrollRequest(
            automaticScrollCoordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
                triggerId: trigger.id,
                targetId: trigger.targetDisplayableId,
                isTargetAvailable: rows.contains {
                    $0.track.id == trigger.targetDisplayableId
                }
            ),
            using: proxy,
            rows: rows
        )
    }

    /// Materializes ровно один принятый auto-scroll после проверки готового row identity.
    private func handleScrollRequest(
        _ request: AutomaticListScrollCoordinator.Request?,
        using proxy: ScrollViewProxy,
        rows: [PurchasedITunesTrackRowState]
    ) {
        guard let request else { return }
        guard pendingRevealRequest == nil else {
            automaticScrollCoordinator.rejectScroll(request)
            return
        }
        guard rows.contains(where: { $0.track.id == request.targetId }) else {
            automaticScrollCoordinator.rejectScroll(request)
            return
        }
        guard automaticScrollCoordinator.beginScroll(request) else {
            return
        }

        if request.isAnimated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(request.targetId, anchor: .center)
            }
        } else {
            proxy.scrollTo(request.targetId, anchor: .center)
        }

        automaticScrollCoordinator.finishProgrammaticScroll(
            isAnimated: request.isAnimated
        )
    }

    /// Сохраняет только самый новый reveal intent до готовности списка к явной прокрутке.
    private func receiveRevealRequest(
        _ request: LibraryRevealRequest?
    ) {
        guard let request,
              request.destination == .purchasedITunes else {
            pendingRevealRequest = nil
            return
        }

        guard pendingRevealRequest?.requestId != request.requestId else {
            return
        }

        pendingRevealRequest = request
    }

    /// Прокручивает только актуальный reveal и не позволяет старому request завершить новый.
    private func revealTrackIfPossible(
        using proxy: ScrollViewProxy,
        tracks: [PurchasedITunesPlayableTrack]
    ) {
        guard let request = pendingRevealRequest else {
            return
        }

        guard tracks.contains(where: { $0.trackId == request.targetTrackId }) else {
            pendingRevealRequest = nil
            onRevealHandled(request.requestId)
            return
        }

        guard automaticScrollCoordinator.beginRevealScroll() else {
            return
        }
        guard pendingRevealRequest?.requestId == request.requestId else {
            automaticScrollCoordinator.cancelExplicitScrollReservation()
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(request.targetTrackId, anchor: .center)
        }

        pendingRevealRequest = nil
        onRevealHandled(request.requestId)
        automaticScrollCoordinator.finishProgrammaticScroll(isAnimated: true)
    }
}

/// Нативная toolbar-кнопка показывает поддерживаемые действия раздела iTunes.
private struct PurchasedITunesToolbarMenuButton: UIViewRepresentable {
    /// Текущий режим нужен системе для checkmark активного направления.
    let selectedSortMode: PurchasedITunesTrackSortMode
    /// Передаёт пользовательский выбор в ActionHandler feature.
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
