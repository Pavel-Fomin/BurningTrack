//
//  NewTrackListSelectionFolderView.swift
//  TrackList
//
//  Экран папки внутри выбора треков для нового треклиста.
//
//  Created by Pavel Fomin on 29.04.2026.
//

import SwiftUI

struct NewTrackListSelectionFolderView: View {

    // MARK: - Input

    let folder: LibraryFolder
    /// Собирает дочерние папки через feature-factory.
    let folderViewFactory: NewTrackListSelectionFolderViewFactory

    // MARK: - State

    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel
    /// Published-состояние «Избранного» используется только как вход state builder-а.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Локально опубликованный снимок сохраняет реактивное обновление готовых строк без PlayerViewModel.
    @State private var favoriteTrackIds: Set<UUID>

    /// Готовая ViewModel Library Tracks, собранная отдельным container через factory.
    @ObservedObject var tracksViewModel: LibraryTracksViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        folderViewFactory: NewTrackListSelectionFolderViewFactory,
        selectionViewModel: NewTrackListSelectionViewModel,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        tracksViewModel: LibraryTracksViewModel
    ) {
        self.folder = folder
        self.folderViewFactory = folderViewFactory
        self.selectionViewModel = selectionViewModel
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.tracksViewModel = tracksViewModel
        _favoriteTrackIds = State(
            initialValue: favoriteTrackIdsProvider.favoriteTrackIds
        )
    }

    /// Все треки текущей папки
    private var currentTracks: [LibraryTrack] {
        tracksViewModel.trackSections.flatMap(\.tracks)
    }

    /// Готовые секции не оставляют View вычислять источник или принадлежность к «Избранному».
    private var selectableTrackSections: [TrackSelectableSectionState] {
        tracksViewModel.makeSelectableTrackSections(
            favoriteTrackIds: favoriteTrackIds,
            selectedTrackIds: selectionViewModel.selectedTrackIds
        )
    }

    // MARK: - UI

    var body: some View {
        ZStack {
            List {
                if !folder.subfolders.isEmpty {
                    Section {
                        ForEach(folder.subfolders) { subfolder in
                            NavigationLink {
                                folderViewFactory.makeFolderContainer(
                                    folder: subfolder,
                                    selectionViewModel: selectionViewModel
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)

                                    Text(subfolder.name)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if !tracksViewModel.trackSections.isEmpty {
                    TrackSelectableSectionsView(
                        sections: selectableTrackSections,
                        onToggleSelection: { track in
                            selectionViewModel.handle(.toggleTrack(track))
                        },
                        onUnavailableTap: { track in
                            selectionViewModel.handle(.unavailableTrackTapped(track))
                        },
                        onRequestSnapshot: { trackId in
                            tracksViewModel.requestSnapshotIfNeeded(for: trackId)
                        }
                    )
                }

                if !tracksViewModel.isLoading
                    && tracksViewModel.trackSections.isEmpty
                    && folder.subfolders.isEmpty {
                    Section {
                        Text("No Tracks in This Folder")
                            .foregroundColor(.secondary)
                    }
                }
            }

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
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !currentTracks.isEmpty {
                    Button(
                        selectionViewModel.areAllSelected(currentTracks)
                            ? String(localized: "Deselect All")
                            : String(localized: "Select All")
                    ) {
                        if selectionViewModel.areAllSelected(currentTracks) {
                            selectionViewModel.handle(.deselectAll(currentTracks))
                        } else {
                            selectionViewModel.handle(.selectAll(currentTracks))
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await tracksViewModel.refresh()
        }
        .onReceive(favoriteTrackIdsProvider.favoriteTrackIdsPublisher) { favoriteTrackIds in
            self.favoriteTrackIds = favoriteTrackIds
        }
    }
}
