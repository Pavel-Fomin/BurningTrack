//
//  LibraryCollectionTracksView.swift
//  TrackList
//
//  Экран треков для выбранного значения раздела коллекции.
//
//  Created by Pavel Fomin on 09.07.2026.
//

import SwiftUI
import UIKit

struct LibraryCollectionTracksView: View {
    // MARK: - Входные данные

    /// Источник списка, соответствующий выбранному значению коллекции.
    let source: LibraryTrackListSource
    /// Готовый screen-local graph, собранный контейнером через factory.
    let screenStore: LibraryCollectionTracksScreenStore
    /// Конфигурация нижней панели массового выбора в общем host фонотеки.
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?
    /// Передаёт действия общего списка в отдельный обработчик экспорта.
    let onAllTracksAction: ((LibraryAllTracksAction) -> Void)?
    /// Передаёт действия выбранного значения коллекции отдельному обработчику экспорта.
    let onCollectionTracksAction: ((LibraryCollectionTracksAction) -> Void)?

    // MARK: - ViewModel

    /// View наблюдает готовые объекты graph, не создавая production-зависимости самостоятельно.
    @ObservedObject private var tracksViewModel: LibraryTracksViewModel
    @ObservedObject private var settingsManager: AppSettingsManager
    @ObservedObject private var playbackStateController: LibraryTrackPlaybackStateController
    /// Следит за подсветкой строки, которой управляет общий SheetHost.
    @ObservedObject private var sheetManager: SheetManager
    /// Локальный снимок сохраняет реактивность строк без наблюдения PlayerViewModel.
    @State private var favoriteTrackIds: Set<UUID>

    // MARK: - Координаторы

    private let selectionActionBarCoordinator = LibrarySelectionActionBarCoordinator()

    // MARK: - Состояние

    /// UI-политика сохраняет ручную позицию списка независимо от playback snapshot.
    @StateObject private var automaticScrollCoordinator = AutomaticListScrollCoordinator()

    // MARK: - Инициализация

    init(
        source: LibraryTrackListSource,
        screenStore: LibraryCollectionTracksScreenStore,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil),
        selectionActionSender: Binding<(any LibraryTracksActionSending)?> = .constant(nil),
        onAllTracksAction: ((LibraryAllTracksAction) -> Void)? = nil,
        onCollectionTracksAction: ((LibraryCollectionTracksAction) -> Void)? = nil
    ) {
        self.source = source
        self.screenStore = screenStore
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        self.onAllTracksAction = onAllTracksAction
        self.onCollectionTracksAction = onCollectionTracksAction
        self._favoriteTrackIds = State(
            initialValue: screenStore.favoriteTrackIdsProvider.favoriteTrackIds
        )
        self.tracksViewModel = screenStore.tracksViewModel
        self.settingsManager = screenStore.settingsManager
        self.playbackStateController = screenStore.playbackStateController
        self.sheetManager = screenStore.sheetManager
    }

    // MARK: - Производное состояние

    /// Показывает, активен ли локальный режим выбора фонотеки.
    private var isSelecting: Bool {
        tracksViewModel.state.isSelecting
    }

    /// Все видимые треки текущих секций для передачи в строки списком контекста.
    private var allVisibleTracks: [LibraryTrack] {
        tracksViewModel.state.sections.flatMap(\.tracks)
    }

    /// Вычисление относится к представлению toolbar и использует готовый screen state без мутации selection.
    private var areAllVisibleTracksSelected: Bool {
        let visibleIDs = Set(allVisibleTracks.map(\.id))
        return visibleIDs.isEmpty == false
            && visibleIDs.isSubset(of: Set(tracksViewModel.state.selectedTrackIDs.ids))
    }

    /// Показывает экспорт внутри общего меню только для общего списка фонотеки.
    private var canExportAllTracks: Bool {
        source.isAllLibraryTracks && onAllTracksAction != nil
    }

    /// Разрешает экспорт только у выбранного значения коллекции.
    private var canExportCollectionTracks: Bool {
        source.isCollectionValue && onCollectionTracksAction != nil
    }

    /// Возвращает действие экспорта для типа текущего списка.
    private var exportAction: (() -> Void)? {
        if canExportAllTracks {
            return handleTapAllTracksExport
        }

        if canExportCollectionTracks {
            return handleTapCollectionTracksExport
        }

        return nil
    }

    /// Возвращает постоянный источник текущего типизированного списка.
    private var playbackSource: PlaybackContextSource {
        source.playbackContextSource
    }

    /// Готовые строки заголовка без сборки пользовательского текста во View.
    private var navigationTitlePresentation: LibraryNavigationTitlePresentation {
        LibraryPresentationText.sourceNavigationTitlePresentation(for: source)
    }

    // MARK: - Интерфейс

    var body: some View {
        contentView
            .navigationTitle(navigationTitlePresentation.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isSelecting)
            .toolbar {
                if source.isCollectionValue {
                    ToolbarItem(placement: .principal) {
                        collectionValueNavigationTitle
                    }
                }
                navigationToolbarContent
            }
            .refreshable {
                tracksViewModel.send(.refreshRequested)
            }
            .task {
                selectionActionSender = tracksViewModel
                tracksViewModel.send(.screenAppeared)
            }
            .onChange(of: tracksViewModel.state.selectionActionBarState) { _, newValue in
                updateSelectionActionBarConfig(from: newValue)
            }
            .onReceive(screenStore.favoriteTrackIdsProvider.favoriteTrackIdsPublisher) { favoriteTrackIds in
                self.favoriteTrackIds = favoriteTrackIds
            }
            .onDisappear {
                screenStore.cloudAvailabilityActionHandler.handle(.screenDidDisappear)
                selectionActionBarConfig = nil
                selectionActionSender = nil
            }
    }

    /// Отображает подготовленный составной заголовок только для выбранного значения коллекции.
    private var collectionValueNavigationTitle: some View {
        VStack(spacing: 0) {
            Text(navigationTitlePresentation.title)
                .font(.headline)
                .lineLimit(1)

            if let subtitle = navigationTitlePresentation.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Контент панели навигации отдаёт наружу только пользовательские намерения.
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
        if isSelecting {
            LibraryBulkSelectionToolbar(
                areAllVisibleTracksSelected: areAllVisibleTracksSelected,
                onToggleSelectAll: handleToggleSelectAll,
                onBatchActionSelection: handleBatchActionSelection,
                onCancel: handleTapCancel
            )
        } else {
            /// Меню обычного режима.
            ToolbarItem(placement: .topBarTrailing) {
                LibraryTracksToolbarMenuButton(
                    selectedSortMode: tracksViewModel.state.sortMode,
                    availableSortModes: source.availableTrackSortModes,
                    onSelect: handleTapSelect,
                    onSortModeSelection: handleSortModeSelection,
                    onBatchActionSelection: handleBatchActionSelection,
                    onExport: exportAction,
                    isExportEnabled: allVisibleTracks.isEmpty == false
                )
            }
        }
    }

    /// Основной контент экрана: список и слой загрузки.
    private var contentView: some View {
        ZStack {
            tracksListView

            loadingOverlayView
        }
    }

    /// Список треков с обработчиками прокрутки и lifecycle списка.
    private var tracksListView: some View {
        return ScrollViewReader { proxy in
            List {
                LibraryTrackSectionsListView(
                    sections: tracksViewModel.state.sections,
                    allTracks: allVisibleTracks,
                    playbackSource: playbackSource,
                    currentCollectionCategory: source.collectionCategory,
                    trackListMembershipsById: tracksViewModel.state.trackListMembershipsById,
                    presentationHandler: screenStore.presentationHandler,
                    cloudAvailabilityStateStore: screenStore.cloudAvailabilityController.stateStore(for:),
                    cloudAvailabilityActionHandler: screenStore.cloudAvailabilityActionHandler,
                    favoriteTrackIds: favoriteTrackIds,
                    commandHandler: screenStore.commandHandler,
                    playbackStateController: playbackStateController,
                    revealedTrackID: nil,
                    highlightedTrackID: sheetManager.highlightedRowID,
                    shouldShowTags: settingsManager.settings.visible.metadata.isTagReadingEnabled,
                    shouldShowTrackListMembership: settingsManager.settings.visible.library.isTrackListMembershipVisible,
                    shouldShowFileFormat: settingsManager.settings.visible.library.isFileFormatVisible,
                    isSelecting: isSelecting,
                    selectedTrackIDs: tracksViewModel.state.selectedTrackIDs
                )

                if tracksViewModel.state.isLoading == false && tracksViewModel.state.sections.isEmpty {
                    Section {
                        Text("No Tracks")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .globalBottomScrollReserve()
            .scrollContentBackground(.hidden)
            .onAppear {
                handleTracksListAppear()
            }
            .onChange(of: automaticScrollCoordinator.pendingScrollRequest) { _, request in
                handleScrollRequest(request, proxy: proxy)
            }
            .onChange(of: tracksViewModel.state.sections) { _, _ in
                requestExplicitPlaybackNavigationScrollIfNeeded(proxy: proxy)
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playbackStateController.currentDisplayableId) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playbackStateController.currentContext) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playbackStateController.automaticListScrollTrigger) { _, _ in
                requestExplicitPlaybackNavigationScrollIfNeeded(proxy: proxy)
            }
            .onScrollPhaseChange { _, newPhase in
                handleScrollRequest(
                    automaticScrollCoordinator.receiveScrollPhase(
                        ListScrollPhase(newPhase)
                    ),
                    proxy: proxy
                )
            }
        }
    }

    /// Скелетон / лоадер поверх пустого списка во время загрузки.
    @ViewBuilder
    private var loadingOverlayView: some View {
        if tracksViewModel.state.isLoading && tracksViewModel.state.sections.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading Tracks")
                    .progressViewStyle(.circular)
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground).opacity(0.9))
        }
    }

    // MARK: - Вспомогательное

    /// Синхронизирует состояние при появлении списка.
    private func handleTracksListAppear() {
        screenStore.cloudAvailabilityActionHandler.handle(.screenDidAppear)
        requestActiveTrackScrollIfNeeded(initialAppearance: true)
        restoreSelectionActionBarIfNeeded()
    }

    /// Обрабатывает нажатие выбора в toolbar.
    private func handleTapSelect() {
        // Вход в выбор без заранее выбранного batch-действия.
        tracksViewModel.send(.selectionStarted)
    }

    /// Передаёт треки в текущем отображаемом порядке обработчику общего списка.
    private func handleTapAllTracksExport() {
        guard canExportAllTracks, allVisibleTracks.isEmpty == false else { return }
        onAllTracksAction?(.exportTracks(allVisibleTracks))
    }

    /// Передаёт треки выбранного значения в текущем отображаемом порядке отдельному обработчику.
    private func handleTapCollectionTracksExport() {
        guard canExportCollectionTracks, allVisibleTracks.isEmpty == false else { return }
        onCollectionTracksAction?(.exportTracks(allVisibleTracks))
    }

    /// Обрабатывает массовое переключение выбора в toolbar.
    private func handleToggleSelectAll() {
        // Массовое переключение выбора остаётся во ViewModel.
        tracksViewModel.send(.selectAllToggled)
    }

    /// Обрабатывает выбор режима сортировки из toolbar menu.
    private func handleSortModeSelection(_ mode: LibraryTrackSortMode) {
        tracksViewModel.send(.sortModeSelected(mode))
    }

    /// Обрабатывает отмену режима выбора.
    private func handleTapCancel() {
        resetMultiselect()
    }

    /// Выполняет auto-scroll только после проверки identity строки в текущих секциях.
    private func handleScrollRequest(
        _ request: AutomaticListScrollCoordinator.Request?,
        proxy: ScrollViewProxy
    ) {
        guard let request else { return }
        guard allVisibleTracks.contains(where: { $0.id == request.targetId }) else {
            automaticScrollCoordinator.rejectScroll(request)
            return
        }
        guard automaticScrollCoordinator.beginScroll(request) else {
            return
        }

        if request.isAnimated {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(request.targetId, anchor: .center)
            }
        } else {
            proxy.scrollTo(request.targetId, anchor: .center)
        }

        automaticScrollCoordinator.finishProgrammaticScroll(
            isAnimated: request.isAnimated
        )
    }

    /// Синхронизирует готовое presentation-состояние нижней панели с общим host.
    private func updateSelectionActionBarConfig(
        from state: LibrarySelectionActionBarState?
    ) {
        guard let state else {
            selectionActionBarConfig = nil
            return
        }

        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(from: state)
    }

    /// Восстанавливает config только из уже активного selection, не записывая nil при remount списка.
    private func restoreSelectionActionBarIfNeeded() {
        guard let state = tracksViewModel.state.selectionActionBarState else {
            return
        }

        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(from: state)
    }

    /// Сбрасывает режим мультиселекта и очищает нижнюю панель.
    private func resetMultiselect() {
        tracksViewModel.send(.selectionCancelled)
    }

    /// Обрабатывает выбор batch-действия с учётом текущего режима и выбора.
    private func handleBatchActionSelection(_ action: BulkTrackAction) {
        tracksViewModel.send(.batchActionSelected(action))
    }

    /// Запрашивает прокрутку к активному треку, если он есть в текущем списке.
    private func requestActiveTrackScrollIfNeeded(
        initialAppearance: Bool = false
    ) {
        guard playbackStateController.currentContext == .library else { return }
        guard let currentTrackId = playbackStateController.currentDisplayableId else { return }
        let isTargetAvailable = allVisibleTracks.contains { $0.id == currentTrackId }

        if initialAppearance {
            automaticScrollCoordinator.requestInitialScrollIfNeeded(
                targetId: currentTrackId,
                isTargetAvailable: isTargetAvailable
            )
        } else {
            automaticScrollCoordinator.requestActiveTrackScrollIfNeeded(
                targetId: currentTrackId,
                isTargetAvailable: isTargetAvailable
            )
        }
    }

    /// Явная навигация MiniPlayer центрирует только строку текущего collection source.
    private func requestExplicitPlaybackNavigationScrollIfNeeded(
        proxy: ScrollViewProxy
    ) {
        guard let trigger = playbackStateController.automaticListScrollTrigger,
              trigger.targetContext == .library,
              trigger.targetDisplayableId == playbackStateController.currentDisplayableId else {
            return
        }

        // Явная команда materialize в текущем обновлении списка и не зависит от второго Published-callback.
        handleScrollRequest(
            automaticScrollCoordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
                triggerId: trigger.id,
                targetId: trigger.targetDisplayableId,
                isTargetAvailable: allVisibleTracks.contains {
                    $0.id == trigger.targetDisplayableId
                }
            ),
            proxy: proxy
        )
    }
}
