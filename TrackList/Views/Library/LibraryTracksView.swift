//
//  LibraryTracksView.swift
//  TrackList
//
//  Отображает список треков из папки, сгруппированных по дате.
//
//  Created by Pavel Fomin on 09.08.2025.
//


import SwiftUI

struct LibraryTracksView: View {

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let trackListViewModel: TrackListViewModel

    let playerViewModel: PlayerViewModel
    @EnvironmentObject var sheetManager: SheetManager
    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500,debounceMs: 180)

    // MARK: -  Локальное состояние для скролла/подсветки
    
    @State private var scrollTargetID: UUID?
    @State private var revealedTrackID: UUID?
    @State private var revealedRequestId: UUID?
    @State private var pendingRevealRequest: LibraryRevealRequest?
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    
    // MARK: - Init
    
    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.trackListViewModel = trackListViewModel
        self.playerViewModel = playerViewModel
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }

                // Как только появилась цель — скроллим
                .onChange(of: scrollTargetID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    scrollTargetID = nil
                }
                .onChange(of: tracksViewModel.trackSections) { _, _ in
                    revealTrackIfNeeded()
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
        // ⬇️ ТУЛБАР — ВОТ ЗДЕСЬ, СНАРУЖИ
        .libraryTracksToolbar(
            title: folder.name,
            isSelecting: $isSelecting,
            selectedCount: selection.count,
            onTapSelect: {
                isSelecting = true
            },
            onTapCancel: {
                isSelecting = false
                selection.removeAll()
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
    }

    // MARK: - Вспомогательное

    /// Проверяем, есть ли трек с данным id в текущих секциях.
    private func containsTrack(id: UUID) -> Bool {
        tracksViewModel.trackSections.contains { section in
            section.tracks.contains { $0.id == id }
        }
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
            scrollTargetID = targetTrackId
            onRevealHandled(revealRequestId)

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if revealedTrackID == targetTrackId && revealedRequestId == revealRequestId {
                revealedTrackID = nil
                revealedRequestId = nil
            }
        }
    }
}
