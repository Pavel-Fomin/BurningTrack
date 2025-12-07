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
    let trackListViewModel: TrackListViewModel

    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var viewModel: LibraryFolderViewModel
    @EnvironmentObject var sheetManager: SheetManager
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500,debounceMs: 180)

    /// Локальное состояние для скролла/подсветки
    @State private var scrollTargetID: UUID?
    @State private var revealedTrackID: UUID?

    // MARK: - Основное тело View

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    LibraryTrackSectionsListView(
                        sections: viewModel.trackSections,
                        allTracks: viewModel.trackSections.flatMap(\.tracks),
                        trackListViewModel: trackListViewModel,
                        trackListNamesById: viewModel.trackListNamesById,
                        metadataByURL: viewModel.metadataByURL,
                        playerViewModel: playerViewModel,
                        isScrollingFast: scrollSpeed.isFast,
                        revealedTrackID: revealedTrackID,
                        folderViewModel: viewModel
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }

                // Когда секции обновились — пробуем отреагировать на pendingRevealTrackID
                .onReceive(viewModel.$trackSections) { sections in
                    guard
                        let targetId = viewModel.pendingRevealTrackID,
                        containsTrack(with: targetId, in: sections)
                    else { return }

                    // Ставим цель для скролла и подсветки
                    scrollTargetID = targetId
                    revealedTrackID = targetId
                    viewModel.pendingRevealTrackID = nil

                    // Снимаем подсветку через несколько секунд
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        if self.revealedTrackID == targetId {
                            self.revealedTrackID = nil
                        }
                    }
                }

                // Как только появилась цель — скроллим
                .onChange(of: scrollTargetID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    scrollTargetID = nil
                }
            }

            // Скелетон / лоадер
            if viewModel.isLoading && viewModel.trackSections.isEmpty {
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

        .refreshable {
            await viewModel.refresh()
        }

        .task(id: folder.url) {
            await viewModel.loadTracksIfNeeded()
            // pendingRevealTrackID уже установлен в ViewModel (из LibraryScreen)
        }
    }

    // MARK: - Вспомогательное

    /// Проверяем, есть ли трек с данным id в текущих секциях
    private func containsTrack(with id: UUID, in sections: [TrackSection]) -> Bool {
        for section in sections {
            if section.tracks.contains(where: { $0.id == id }) { return true }
        }
        return false
    }
}
