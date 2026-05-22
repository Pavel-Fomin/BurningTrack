//
//  LibraryTracksView.swift
//  TrackList
//
//  Отображает список треков из папки, сгруппированных по дате.
//
//  Created by Pavel Fomin on 09.08.2025.
//


import SwiftUI

// Типизирует причину программной прокрутки фонотеки.
private enum LibraryScrollRequest: Equatable {
    case reveal(UUID)
    case activeTrack(UUID)

    var targetId: UUID {
        switch self {
        case .reveal(let id):
            return id
        case .activeTrack(let id):
            return id
        }
    }
}

struct LibraryTracksView: View {

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let trackListViewModel: TrackListViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var sheetManager: SheetManager
    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500,debounceMs: 180)

    // MARK: -  Локальное состояние для скролла/подсветки
    
    @State private var scrollRequest: LibraryScrollRequest?
    @State private var revealedTrackID: UUID?
    @State private var revealedRequestId: UUID?
    @State private var pendingRevealRequest: LibraryRevealRequest?
    @State private var isShowingBatchFilenameRenameSheet = false

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
    
    // MARK: - Init
    
    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil)
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.trackListViewModel = trackListViewModel
        self.playerViewModel = playerViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
        self._pendingRevealRequest = State(initialValue: revealRequest)
        self._tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(folderURL: folder.url)
        )
    }

    // MARK: - Ui

    var body: some View {
        ZStack {

            ScrollViewReader { proxy in
                List {
                    LibraryTrackSectionsListView(
                        sections: tracksViewModel.trackSections,
                        allTracks: tracksViewModel.trackSections.flatMap(\.tracks),
                        trackListViewModel: trackListViewModel,
                        trackListNamesById: tracksViewModel.trackListNamesById,
                        metadataProvider: tracksViewModel,
                        playerViewModel: playerViewModel,
                        isScrollingFast: scrollSpeed.isFast,
                        revealedTrackID: revealedTrackID,
                        isSelecting: isSelecting,
                        selection: selectionBinding
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                .onAppear {
                    requestActiveTrackScrollIfNeeded()
                    updateSelectionActionBarConfig()
                }
                // Как только появилась цель — скроллим
                .onChange(of: scrollRequest) { _, request in
                    guard let request else { return }

                    let targetId = request.targetId

                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }

                    scrollRequest = nil
                }
                .onChange(of: tracksViewModel.trackSections) { _, _ in
                    revealTrackIfNeeded()
                }
                .onChange(of: playerViewModel.currentTrackDisplayable?.id) { _, _ in
                    requestActiveTrackScrollIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    requestActiveTrackScrollIfNeeded()
                }
            }

            // Скелетон / лоадер
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
        // Тулбар подключается снаружи списка, чтобы не влиять на строки.
        .libraryTracksToolbar(
            title: folder.name,
            isSelecting: isSelecting,
            isAllSelected: tracksViewModel.areAllVisibleTracksSelected,
            onTapSelect: {
                // Вход в выбор без заранее выбранного batch-действия.
                tracksViewModel.activateBulkSelection()
                updateSelectionActionBarConfig()
            },
            onToggleSelectAll: {
                // Массовое переключение выбора остаётся во ViewModel.
                tracksViewModel.toggleSelectAllVisibleTracks()
                updateSelectionActionBarConfig()
            },
            onSelectBatchAction: { action in
                // Делегируем выбор действия общей логике мультиселекта.
                handleBatchActionSelection(action)
            },
            onTapCancel: {
                // Отмена полностью сбрасывает режим и текущий выбор.
                resetMultiselect()
            }
        )
        .refreshable {
            await tracksViewModel.refresh()
        }
        .task {
            await tracksViewModel.loadTracksIfNeeded()
            revealTrackIfNeeded()
        }
        .onChange(of: revealRequest?.requestId) { _, _ in
            pendingRevealRequest = revealRequest
            revealTrackIfNeeded()
        }
        .onChange(of: sheetManager.dismissCounter) { _, _ in
            Task {
                if tracksViewModel.isLoading {return}
                await tracksViewModel.refresh()
            }
        }
        .onChange(of: tracksViewModel.bulkSelection.selectedCount) { _, _ in
            updateSelectionActionBarConfig()
        }
        .onChange(of: tracksViewModel.batchFilenameRenameFlow.isActive) { _, isActive in
            isShowingBatchFilenameRenameSheet = isActive
        }
        .onChange(of: isShowingBatchFilenameRenameSheet) { _, isShowing in
            guard !isShowing else { return }
            tracksViewModel.resetBatchFilenameRenameFlow()
        }
        .sheet(isPresented: $isShowingBatchFilenameRenameSheet) {
            BatchFilenameRenameContainer(
                viewModel: tracksViewModel,
                playerManager: playerViewModel.playerManager,
                onClose: {
                    isShowingBatchFilenameRenameSheet = false
                }
            )
                .appSheet(detents: [.large])
        }
        .onDisappear {
            selectionActionBarConfig = nil
        }
    }

    // MARK: - Вспомогательное

    /// Проверяем, есть ли трек с данным id в текущих секциях.
    private func containsTrack(id: UUID) -> Bool {
        tracksViewModel.trackSections.contains { section in
            section.tracks.contains { $0.id == id }
        }
    }

    /// Обновляет конфигурацию нижней панели подтверждения для родительского host.
    private func updateSelectionActionBarConfig() {
        guard let action = tracksViewModel.bulkSelection.pendingAction else {
            selectionActionBarConfig = nil
            return
        }

        selectionActionBarConfig = SelectionActionBarConfig(
            title: action.title,
            subtitle: "Выбрано: \(tracksViewModel.bulkSelection.selectedCount)",
            primaryTitle: "Применить",
            iconName: action.iconName,
            isPrimaryEnabled: tracksViewModel.bulkSelection.hasSelection,
            onPrimaryTap: applySelectedBatchAction
        )
    }

    /// Сбрасывает режим мультиселекта и очищает нижнюю панель.
    private func resetMultiselect() {
        tracksViewModel.resetBulkSelection()
        selectionActionBarConfig = nil
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

    /// Запрашивает прокрутку к активному треку, если она не конфликтует с reveal.
    private func requestActiveTrackScrollIfNeeded() {
        guard pendingRevealRequest == nil else { return }
        guard scrollRequest == nil else { return }
        guard playerViewModel.currentContext == .library else { return }
        guard let currentTrackId = playerViewModel.currentTrackDisplayable?.id else { return }
        guard containsTrack(id: currentTrackId) else { return }

        scrollRequest = .activeTrack(currentTrackId)
    }

    /// Показываем целевой трек только после появления строки в списке.
    private func revealTrackIfNeeded() {
        guard let request = pendingRevealRequest else { return }
        let targetTrackId = request.targetTrackId
        let revealRequestId = request.requestId

        guard containsTrack(id: targetTrackId) else {
            guard tracksViewModel.didLoad && !tracksViewModel.isLoading else { return }
            pendingRevealRequest = nil
            onRevealHandled(revealRequestId)
            return
        }

        pendingRevealRequest = nil
        revealedTrackID = targetTrackId
        revealedRequestId = revealRequestId

        Task { @MainActor in
            // Даём List один проход на создание строки перед scrollTo.
            await Task.yield()
            scrollRequest = .reveal(targetTrackId)
            onRevealHandled(revealRequestId)

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if revealedTrackID == targetTrackId && revealedRequestId == revealRequestId {
                revealedTrackID = nil
                revealedRequestId = nil
            }
        }
    }
}
