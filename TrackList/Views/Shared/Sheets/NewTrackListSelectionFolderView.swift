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

    /// Общий обработчик переименования файлов треков.
    let renameActionHandler: TrackFileRenameActionHandler

    // MARK: - State

    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel
    /// Published-состояние «Избранного» используется только как вход state builder-а.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Локально опубликованный снимок сохраняет реактивное обновление готовых строк без PlayerViewModel.
    @State private var favoriteTrackIds: Set<UUID>

    /// ViewModel для загрузки треков папки
    @StateObject private var tracksViewModel: LibraryTracksViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        selectionViewModel: NewTrackListSelectionViewModel,
        renameActionHandler: TrackFileRenameActionHandler,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) {
        self.folder = folder
        self.selectionViewModel = selectionViewModel
        self.renameActionHandler = renameActionHandler
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self._favoriteTrackIds = State(
            initialValue: favoriteTrackIdsProvider.favoriteTrackIds
        )

        _tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(
                folderURL: folder.url,
                renameActionHandler: renameActionHandler,
                usesLibrarySortSettings: false
            )
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
            selectedTrackIds: Set(selectionViewModel.selectedTracksById.keys)
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
                                NewTrackListSelectionFolderView(
                                    folder: subfolder,
                                    selectionViewModel: selectionViewModel,
                                    renameActionHandler: renameActionHandler,
                                    favoriteTrackIdsProvider: favoriteTrackIdsProvider
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
                            selectionViewModel.toggle(track)
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
                            selectionViewModel.deselectAll(currentTracks)
                        } else {
                            selectionViewModel.selectAll(currentTracks)
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
