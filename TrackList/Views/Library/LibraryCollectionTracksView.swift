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
    /// Реактивное playback-состояние для строк и прокрутки к текущему треку.
    let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска и toggle для строк выбранной коллекции.
    let playbackController: any TrackPlaybackControlling
    /// Published-состояние «Избранного» для presentation state строк.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Проверка занятости файла для массового переименования.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Общий обработчик одиночного переименования файла.
    let renameActionHandler: TrackFileRenameActionHandler
    /// Единый обработчик «Избранного» передаётся в строки выбранной коллекции.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Конфигурация нижней панели массового выбора в общем host фонотеки.
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?
    /// Передаёт действия общего списка в отдельный обработчик экспорта.
    let onAllTracksAction: ((LibraryAllTracksAction) -> Void)?
    /// Передаёт действия выбранного значения коллекции отдельному обработчику экспорта.
    let onCollectionTracksAction: ((LibraryCollectionTracksAction) -> Void)?

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var sheetManager: SheetManager

    // MARK: - ViewModel

    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @State private var cloudAvailabilityController = LibraryCloudAvailabilityScreenController()
    @ObservedObject private var settingsManager = AppSettingsManager.shared
    @StateObject private var playbackStateController: LibraryTrackPlaybackStateController
    /// Локальный снимок сохраняет реактивность строк без наблюдения PlayerViewModel.
    @State private var favoriteTrackIds: Set<UUID>

    // MARK: - Coordinators

    private let selectionActionBarCoordinator = LibrarySelectionActionBarCoordinator()
    private let sheetCoordinator = LibraryTracksSheetCoordinator()

    // MARK: - State

    /// Отложенная команда прокрутки к текущему треку.
    @State private var scrollRequest: LibraryScrollRequest?

    // MARK: - Init

    init(
        source: LibraryTrackListSource,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        fileBusyChecker: any TrackFileBusyChecking,
        renameActionHandler: TrackFileRenameActionHandler,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil),
        selectionActionSender: Binding<(any LibraryTracksActionSending)?> = .constant(nil),
        onAllTracksAction: ((LibraryAllTracksAction) -> Void)? = nil,
        onCollectionTracksAction: ((LibraryCollectionTracksAction) -> Void)? = nil
    ) {
        self.source = source
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.fileBusyChecker = fileBusyChecker
        self.renameActionHandler = renameActionHandler
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        self.onAllTracksAction = onAllTracksAction
        self.onCollectionTracksAction = onCollectionTracksAction
        self._favoriteTrackIds = State(
            initialValue: favoriteTrackIdsProvider.favoriteTrackIds
        )
        self._playbackStateController = StateObject(
            wrappedValue: LibraryTrackPlaybackStateController(
                playbackStateProvider: playbackStateProvider
            )
        )
        let tracksViewModel = LibraryTracksViewModel(
            source: source,
            renameActionHandler: renameActionHandler,
            tracksProvider: FastLibraryTracksProvider(),
            badgeProvider: DefaultTrackListBadgeProvider(),
            eventProvider: NotificationLibraryTrackEventProvider(),
            runtimeController: LibraryTrackRuntimeController(),
            settingsManager: AppSettingsManager.shared,
            trackRegistry: TrackRegistry.shared,
            musicLibraryManager: MusicLibraryManager.shared,
            trackURLProvider: { trackId in
                await BookmarkResolver.url(forTrack: trackId)
            }
        )
        let presenter = LibraryTracksPresenter(
            output: tracksViewModel,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let actionHandler = LibraryTracksActionHandler(
            output: tracksViewModel,
            applyBatchFilenameRename: { [weak tracksViewModel, fileBusyChecker] in
                await tracksViewModel?.applyBatchFilenameRename(using: fileBusyChecker)
            }
        )
        tracksViewModel.configure(
            actionHandler: actionHandler,
            presenter: presenter
        )
        self._tracksViewModel = StateObject(wrappedValue: tracksViewModel)
    }

    // MARK: - Производное состояние

    /// Показывает, активен ли локальный режим выбора фонотеки.
    private var isSelecting: Bool {
        tracksViewModel.bulkSelection.isActive
    }

    /// Пробрасывает selection в список без переноса логики выбора в строки.
    private var selectionBinding: Binding<OrderedSelection<UUID>> {
        Binding(
            get: { tracksViewModel.bulkSelection.selection },
            set: { tracksViewModel.bulkSelection.selection = $0 }
        )
    }

    /// Все видимые треки текущих секций для передачи в строки списком контекста.
    private var allVisibleTracks: [LibraryTrack] {
        tracksViewModel.trackSections.flatMap(\.tracks)
    }

    /// Обрабатывает iCloud-действия на уровне экрана, а не жизненного цикла каждой строки.
    private var cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler {
        LibraryCloudAvailabilityActionHandler(
            controller: cloudAvailabilityController
        )
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

    // MARK: - UI

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
                await tracksViewModel.refresh()
            }
            .task {
                selectionActionSender = tracksViewModel
                await tracksViewModel.loadTracksIfNeeded()
            }
            .onChange(of: sheetManager.dismissCounter) { _, _ in
                handleSheetDismissCounterChange()
            }
            .onChange(of: tracksViewModel.bulkSelection.selectedCount) { _, _ in
                updateSelectionActionBarConfig()
            }
            .onChange(of: tracksViewModel.batchFilenameRenameFlow.isActive) { _, isActive in
                handleBatchFilenameRenameFlowActivityChange(isActive)
            }
            .onReceive(favoriteTrackIdsProvider.favoriteTrackIdsPublisher) { favoriteTrackIds in
                self.favoriteTrackIds = favoriteTrackIds
            }
            .onDisappear {
                cloudAvailabilityActionHandler.handle(.screenDidDisappear)
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
                areAllVisibleTracksSelected: tracksViewModel.areAllVisibleTracksSelected,
                onToggleSelectAll: handleToggleSelectAll,
                onBatchActionSelection: handleBatchActionSelection,
                onCancel: handleTapCancel
            )
        } else {
            /// Меню обычного режима.
            ToolbarItem(placement: .topBarTrailing) {
                LibraryTracksToolbarMenuButton(
                    selectedSortMode: tracksViewModel.sortMode,
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
        let presentationHandler = LibraryTrackPresentationHandler(
            metadataProvider: tracksViewModel
        )
        let commandHandler = LibraryTrackCommandHandler(
            sheetManager: sheetManager,
            playbackHandler: LibraryTrackPlaybackHandler(
                playbackStateProvider: playbackStateProvider,
                playbackController: playbackController,
                source: playbackSource
            ),
            presentationHandler: presentationHandler,
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            collectionNavigationHandler: .shared,
            trackShareActionHandler: .shared,
            commandExecutor: .shared,
            toastManager: .shared,
            sheetActionCoordinator: .shared,
            favoriteActionHandler: favoriteTrackActionHandler,
            onToggleSelection: { trackId in
                tracksViewModel.toggleSelection(for: trackId)
            },
            onRenameTrack: { trackId, strategy in
                tracksViewModel.renameTrack(trackId: trackId, strategy: strategy)
            }
        )

        return ScrollViewReader { proxy in
            List {
                LibraryTrackSectionsListView(
                    sections: tracksViewModel.trackSections,
                    allTracks: allVisibleTracks,
                    playbackSource: playbackSource,
                    currentCollectionCategory: source.collectionCategory,
                    trackListMembershipsById: tracksViewModel.trackListMembershipsById,
                    presentationHandler: presentationHandler,
                    cloudAvailabilityStateStore: cloudAvailabilityController.stateStore(for:),
                    cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
                    favoriteTrackIds: favoriteTrackIds,
                    commandHandler: commandHandler,
                    playbackStateController: playbackStateController,
                    revealedTrackID: nil,
                    highlightedTrackID: sheetManager.highlightedRowID,
                    shouldShowTags: settingsManager.settings.visible.metadata.isTagReadingEnabled,
                    shouldShowTrackListMembership: settingsManager.settings.visible.library.isTrackListMembershipVisible,
                    shouldShowFileFormat: settingsManager.settings.visible.library.isFileFormatVisible,
                    isSelecting: isSelecting,
                    selectedTrackIDs: tracksViewModel.bulkSelection.selection
                )

                if tracksViewModel.isLoading == false && tracksViewModel.trackSections.isEmpty {
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
            .onChange(of: scrollRequest) { _, request in
                handleScrollRequest(request, proxy: proxy)
            }
            .onChange(of: tracksViewModel.trackSections) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playbackStateController.currentDisplayableId) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playbackStateController.currentContext) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    /// Скелетон / лоадер поверх пустого списка во время загрузки.
    @ViewBuilder
    private var loadingOverlayView: some View {
        if tracksViewModel.isLoading && tracksViewModel.trackSections.isEmpty {
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
        cloudAvailabilityActionHandler.handle(.screenDidAppear)
        requestActiveTrackScrollIfNeeded()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает нажатие выбора в toolbar.
    private func handleTapSelect() {
        tracksViewModel.activateBulkSelection()
        updateSelectionActionBarConfig()
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
        tracksViewModel.toggleSelectAllVisibleTracks()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает выбор режима сортировки из toolbar menu.
    private func handleSortModeSelection(_ mode: LibraryTrackSortMode) {
        Task {
            await tracksViewModel.setSortMode(mode)
        }
    }

    /// Обрабатывает отмену режима выбора.
    private func handleTapCancel() {
        resetMultiselect()
    }

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

    /// Обрабатывает возврат приложения в активную фазу.
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        requestActiveTrackScrollIfNeeded()
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

    /// Открывает глобальный sheet при запуске flow массового переименования.
    private func handleBatchFilenameRenameFlowActivityChange(_ isActive: Bool) {
        guard sheetCoordinator.shouldPresentBatchFilenameRename(
            isActive: isActive
        ) else {
            return
        }

        sheetManager.presentBatchFilenameRename(
            flow: tracksViewModel.batchFilenameRenameFlow,
            onApply: {
                await tracksViewModel.applyBatchFilenameRename(
                    using: fileBusyChecker
                )
            }
        )
    }

    /// Синхронизирует конфигурацию нижней панели подтверждения для родительского host.
    private func updateSelectionActionBarConfig() {
        guard let state = selectionActionBarCoordinator.makeState(
            isSelecting: tracksViewModel.bulkSelection.isActive,
            pendingAction: tracksViewModel.bulkSelection.pendingAction,
            selectedCount: tracksViewModel.bulkSelection.selectedCount,
            hasSelection: tracksViewModel.bulkSelection.hasSelection
        ) else {
            selectionActionBarConfig = nil
            return
        }

        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(from: state)
    }

    /// Сбрасывает режим мультиселекта и очищает нижнюю панель.
    private func resetMultiselect() {
        tracksViewModel.resetBulkSelection()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает выбор batch-действия с учётом текущего режима и выбора.
    private func handleBatchActionSelection(_ action: BulkTrackAction) {
        tracksViewModel.selectBulkAction(action)
        updateSelectionActionBarConfig()
    }

    /// Применяет заранее выбранное batch-действие из нижней панели.
    private func applySelectedBatchAction() {
        tracksViewModel.applyPendingBulkAction()
        updateSelectionActionBarConfig()
    }

    /// Запрашивает прокрутку к активному треку, если он есть в текущем списке.
    private func requestActiveTrackScrollIfNeeded() {
        guard scrollRequest == nil else { return }
        guard playbackStateController.currentContext == .library else { return }
        guard let currentTrackId = playbackStateController.currentDisplayableId else { return }
        guard allVisibleTracks.contains(where: { $0.id == currentTrackId }) else { return }

        scrollRequest = .activeTrack(currentTrackId)
    }
}
