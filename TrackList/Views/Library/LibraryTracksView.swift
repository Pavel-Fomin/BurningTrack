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
    @State private var multiselectMode: MultiselectMode<LibraryBatchAction> = .inactive
    @State private var selection = OrderedSelection<UUID>()

    /// Показывает, активен ли локальный режим выбора фонотеки.
    private var isSelecting: Bool {
        multiselectMode.isSelecting
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
                        selection: $selection
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
            selectedCount: selection.count,
            onTapSelect: {
                // Вход в выбор без заранее выбранного batch-действия.
                multiselectMode = .selecting(action: nil)
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
        .onChange(of: selection.count) { _, _ in
            updateSelectionActionBarConfig()
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
        guard let action = multiselectMode.action else {
            selectionActionBarConfig = nil
            return
        }

        selectionActionBarConfig = SelectionActionBarConfig(
            title: action.title,
            subtitle: "Выбрано: \(selection.count)",
            primaryTitle: "Применить",
            iconName: action.iconName,
            isPrimaryEnabled: !selection.isEmpty,
            onPrimaryTap: applySelectedBatchAction
        )
    }

    /// Сбрасывает режим мультиселекта и очищает нижнюю панель.
    private func resetMultiselect() {
        multiselectMode = .inactive
        selection.clear()
        selectionActionBarConfig = nil
    }

    /// Обрабатывает выбор batch-действия с учётом текущего режима и выбора.
    private func handleBatchActionSelection(_ action: LibraryBatchAction) {
        if multiselectMode.isSelecting {
            guard !selection.isEmpty else {
                multiselectMode = .selecting(action: action)
                updateSelectionActionBarConfig()
                return
            }

            applyBatchAction(action)
            return
        }

        multiselectMode = .selecting(action: action)
        updateSelectionActionBarConfig()
    }

    /// Применяет batch-действие к текущему выбору через техническую заглушку.
    private func applyBatchAction(_ action: LibraryBatchAction) {
        guard !selection.isEmpty else { return }

        print("Batch action:", action)
        print("Selected IDs:", selection.ids)

        resetMultiselect()
    }

    /// Применяет заранее выбранное batch-действие из нижней панели.
    private func applySelectedBatchAction() {
        guard let action = multiselectMode.action else { return }
        applyBatchAction(action)
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
