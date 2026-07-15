//
//  LibraryCollectionTracksView.swift
//  TrackList
//
//  Экран треков для выбранного значения раздела коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI
import UIKit

struct LibraryCollectionTracksView: View {
    // MARK: - Входные данные

    /// Источник списка, соответствующий выбранному значению коллекции.
    let source: LibraryTrackListSource
    /// ViewModel плеера для воспроизведения и текущего состояния строки.
    @ObservedObject var playerViewModel: PlayerViewModel
    /// Конфигурация нижней панели массового выбора в общем host фонотеки.
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var sheetManager: SheetManager

    // MARK: - ViewModel

    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500, debounceMs: 180)

    // MARK: - Coordinators

    private let selectionActionBarCoordinator = LibrarySelectionActionBarCoordinator()
    private let sheetCoordinator = LibraryTracksSheetCoordinator()

    // MARK: - State

    /// Отложенная команда прокрутки к текущему треку.
    @State private var scrollRequest: LibraryScrollRequest?

    // MARK: - Init

    init(
        source: LibraryTrackListSource,
        playerViewModel: PlayerViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil)
    ) {
        self.source = source
        self.playerViewModel = playerViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
        self._tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(
                source: source,
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

    /// Возвращает постоянный источник текущего типизированного списка.
    private var playbackSource: PlaybackContextSource {
        source.playbackContextSource
    }

    // MARK: - UI

    var body: some View {
        contentView
            .navigationTitle(source.navigationTitle ?? "Треки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                navigationToolbarContent
            }
            .refreshable {
                await tracksViewModel.refresh()
            }
            .task {
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
            .onDisappear {
                selectionActionBarConfig = nil
            }
    }

    /// Контент справа отдаёт наружу только пользовательские намерения.
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: handleToggleSelectAll) {
                        Label(
                            tracksViewModel.areAllVisibleTracksSelected ? "Снять все" : "Выбрать все",
                            systemImage: tracksViewModel.areAllVisibleTracksSelected ? "circle" : "checkmark.circle"
                        )
                    }

                    Divider()

                    batchActionMenuItems
                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            /// Закрывает режим выбора и очищает текущий selection.
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: handleTapCancel) {
                    Image(systemName: "xmark")
                }
            }
        } else {
            /// Меню обычного режима.
            ToolbarItem(placement: .topBarTrailing) {
                LibraryTracksToolbarMenuButton(
                    selectedSortMode: tracksViewModel.sortMode,
                    availableSortModes: source.availableTrackSortModes,
                    onSelect: handleTapSelect,
                    onSortModeSelection: handleSortModeSelection,
                    onBatchActionSelection: handleBatchActionSelection
                )
            }
        }
    }

    /// Общие пункты batch-действий без выполнения самих действий.
    @ViewBuilder
    private var batchActionMenuItems: some View {
        Section("Добавить") {
            Button {
                handleBatchActionSelection(.addToPlayer)
            } label: {
                Label("В плеер", systemImage: "waveform")
            }

            Button {
                handleBatchActionSelection(.addToTrackList)
            } label: {
                Label("В треклист", systemImage: "list.star")
            }
        }

        Section("Изменить") {
            Button {
                handleBatchActionSelection(.renameFiles)
            } label: {
                Label("Имя файла", systemImage: "pencil")
            }

            Button {
                handleBatchActionSelection(.editTags)
            } label: {
                Label("Теги", systemImage: "tag")
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
        ScrollViewReader { proxy in
            List {
                LibraryTrackSectionsListView(
                    sections: tracksViewModel.trackSections,
                    allTracks: allVisibleTracks,
                    playbackSource: playbackSource,
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
                    isSelecting: isSelecting,
                    selection: selectionBinding
                )

                if tracksViewModel.isLoading == false && tracksViewModel.trackSections.isEmpty {
                    Section {
                        Text("Нет треков")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
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
            .onChange(of: playerViewModel.currentTrackDisplayable?.id) { _, _ in
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
                ProgressView("Загружаю треки")
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
        requestActiveTrackScrollIfNeeded()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает нажатие выбора в toolbar.
    private func handleTapSelect() {
        tracksViewModel.activateBulkSelection()
        updateSelectionActionBarConfig()
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
            playerManager: playerViewModel.fileOperationPlayerManager,
            onApply: {
                await tracksViewModel.applyBatchFilenameRename(
                    using: playerViewModel.fileOperationPlayerManager
                )
            }
        )
    }

    /// Синхронизирует конфигурацию нижней панели подтверждения для родительского host.
    private func updateSelectionActionBarConfig() {
        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(
            pendingAction: tracksViewModel.bulkSelection.pendingAction,
            selectedCount: tracksViewModel.bulkSelection.selectedCount,
            hasSelection: tracksViewModel.bulkSelection.hasSelection,
            onPrimaryTap: applySelectedBatchAction
        )
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
        guard playerViewModel.currentContext == .library else { return }
        guard let currentTrackId = playerViewModel.currentTrackDisplayable?.id else { return }
        guard allVisibleTracks.contains(where: { $0.id == currentTrackId }) else { return }

        scrollRequest = .activeTrack(currentTrackId)
    }
}
