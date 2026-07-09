//
//  LibraryTracksRootView.swift
//  TrackList
//
//  Корневой экран режима "Треки" с категориями и общим списком треков.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

struct LibraryTracksRootView: View {
    // MARK: - Входные данные

    /// Разделы музыкальной коллекции, которые отображаются над списком всех треков.
    let categories: [LibraryCollectionCategory]
    /// Передаёт выбор раздела коллекции в контейнер фонотеки.
    let onCategorySelected: (LibraryCollectionCategory) -> Void
    /// ViewModel плеера для воспроизведения строк и подсветки текущего трека.
    @ObservedObject var playerViewModel: PlayerViewModel
    /// Конфигурация нижней панели выбора в host фонотеки.
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var sheetManager: SheetManager

    // MARK: - ViewModel

    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500, debounceMs: 180)

    // MARK: - State

    /// Selection остаётся неактивным в корне, потому что toolbar корня уже занят режимами фонотеки.
    @State private var selection = OrderedSelection<UUID>()
    /// Отложенная команда прокрутки к текущему треку.
    @State private var scrollRequest: LibraryScrollRequest?

    // MARK: - Dependencies

    private let sheetCoordinator = LibraryTracksSheetCoordinator()

    // MARK: - Init

    init(
        categories: [LibraryCollectionCategory],
        playerViewModel: PlayerViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil),
        onCategorySelected: @escaping (LibraryCollectionCategory) -> Void
    ) {
        self.categories = categories
        self.playerViewModel = playerViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
        self.onCategorySelected = onCategorySelected
        self._tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(
                source: .allLibraryTracks,
                renameActionHandler: TrackFileRenameActionHandler(
                    playerManager: playerViewModel.fileOperationPlayerManager,
                    sheetManager: SheetManager.shared,
                    commandExecutor: AppCommandExecutor.shared,
                    toastManager: ToastManager.shared,
                    proposalBuilder: FileRenameProposalBuilder()
                )
            )
        )
    }

    // MARK: - Производное состояние

    /// Все видимые треки текущих секций для передачи в строки списком контекста.
    private var allVisibleTracks: [LibraryTrack] {
        tracksViewModel.trackSections.flatMap(\.tracks)
    }

    // MARK: - UI

    var body: some View {
        tracksRootList
            .refreshable {
                await tracksViewModel.refresh()
            }
            .task {
                await tracksViewModel.loadTracksIfNeeded()
            }
            .onChange(of: sheetManager.dismissCounter) { _, _ in
                handleSheetDismissCounterChange()
            }
            .onChange(of: tracksViewModel.trackSections) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playerViewModel.currentTrackDisplayable?.id) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onDisappear {
                selectionActionBarConfig = nil
            }
    }

    /// Общий список корня режима "Треки": сначала категории, затем все треки.
    private var tracksRootList: some View {
        ScrollViewReader { proxy in
            List {
                categoriesSection
                allTracksContent
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: scrollRequest) { _, request in
                handleScrollRequest(request, proxy: proxy)
            }
        }
    }

    /// Секция навигационных категорий коллекции.
    private var categoriesSection: some View {
        Section {
            ForEach(categories) { category in
                LibraryCollectionCategoryRowView(
                    category: category,
                    onCategorySelected: onCategorySelected
                )
            }
        }
    }

    /// Содержимое списка всех треков с состояниями загрузки и пустого списка.
    @ViewBuilder
    private var allTracksContent: some View {
        if tracksViewModel.isLoading && tracksViewModel.trackSections.isEmpty {
            Section("Все треки") {
                ProgressView("Загружаю треки")
            }
        } else if tracksViewModel.trackSections.isEmpty {
            Section("Все треки") {
                Text("Нет треков")
                    .foregroundStyle(.secondary)
            }
        } else {
            allTracksHeaderSection

            LibraryTrackSectionsListView(
                sections: tracksViewModel.trackSections,
                allTracks: allVisibleTracks,
                trackListNamesById: tracksViewModel.trackListNamesById,
                metadataProvider: tracksViewModel,
                playerViewModel: playerViewModel,
                isScrollingFast: scrollSpeed.isFast,
                revealedTrackID: nil,
                onRenameTrack: { trackId, strategy in
                    tracksViewModel.renameTrack(
                        trackId: trackId,
                        strategy: strategy
                    )
                },
                isSelecting: false,
                selection: $selection
            )
        }
    }

    /// Отдельный заголовок блока всех треков перед секциями, построенными общим компонентом.
    private var allTracksHeaderSection: some View {
        Section {
            EmptyView()
        } header: {
            Text("Все треки")
                .font(.headline)
        }
    }

    // MARK: - Вспомогательное

    /// Выполняет программную прокрутку по отложенному запросу.
    private func handleScrollRequest(
        _ request: LibraryScrollRequest?,
        proxy: ScrollViewProxy
    ) {
        guard let request else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(request.targetId, anchor: .center)
        }

        scrollRequest = nil
    }

    /// Обновляет список после закрытия глобального sheet.
    private func handleSheetDismissCounterChange() {
        guard sheetCoordinator.shouldRefreshAfterDismiss(
            lastDismissedSheetKind: sheetManager.lastDismissedSheetKind,
            isLoading: tracksViewModel.isLoading
        ) else {
            return
        }

        Task {
            await tracksViewModel.refresh()
        }
    }

    /// Обрабатывает возврат приложения в активную фазу.
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        requestActiveTrackScrollIfNeeded()
    }

    /// Запрашивает прокрутку к активному треку, если он есть в текущем списке.
    private func requestActiveTrackScrollIfNeeded() {
        guard scrollRequest == nil else { return }
        guard playerViewModel.currentContext == .library else { return }
        guard let currentTrackId = playerViewModel.currentTrackDisplayable?.id else { return }
        guard allVisibleTracks.contains(where: { $0.id == currentTrackId }) else { return }

        scrollRequest = .activeTrack(currentTrackId)
    }
}
