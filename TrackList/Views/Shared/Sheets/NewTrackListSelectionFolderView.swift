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

    /// ViewModel для загрузки треков папки
    @StateObject private var tracksViewModel: LibraryTracksViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        selectionViewModel: NewTrackListSelectionViewModel,
        renameActionHandler: TrackFileRenameActionHandler
    ) {
        self.folder = folder
        self.selectionViewModel = selectionViewModel
        self.renameActionHandler = renameActionHandler

        _tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(
                folderURL: folder.url,
                renameActionHandler: renameActionHandler
            )
        )
    }

    /// Все треки текущей папки
    private var currentTracks: [LibraryTrack] {
        tracksViewModel.trackSections.flatMap(\.tracks)
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
                                    renameActionHandler: renameActionHandler
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
                        sections: tracksViewModel.trackSections,
                        selection: Binding(
                            get: { Set(selectionViewModel.selectedTracksById.keys) },
                            set: { newValue in

                                let allTracks = tracksViewModel.trackSections.flatMap(\.tracks)

                                for track in allTracks {
                                    let isSelected = selectionViewModel.isSelected(track)
                                    let shouldBeSelected = newValue.contains(track.id)

                                    if shouldBeSelected && !isSelected {
                                        selectionViewModel.toggle(track)
                                    }

                                    if !shouldBeSelected && isSelected {
                                        selectionViewModel.toggle(track)
                                    }
                                }
                            }
                        ),
                        metadataProvider: tracksViewModel
                    )
                }

                if !tracksViewModel.isLoading
                    && tracksViewModel.trackSections.isEmpty
                    && folder.subfolders.isEmpty {
                    Section {
                        Text("В этой папке нет треков")
                            .foregroundColor(.secondary)
                    }
                }
            }

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
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !currentTracks.isEmpty {
                    Button(
                        selectionViewModel.areAllSelected(currentTracks)
                            ? "Снять выбор"
                            : "Выбрать все"
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
    }
}
