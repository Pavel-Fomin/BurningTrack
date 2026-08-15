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

    // MARK: - Входные данные

    let folder: LibraryFolder
    /// Собирает дочерние папки через feature-factory.
    let folderViewFactory: NewTrackListSelectionFolderViewFactory

    // MARK: - Состояние

    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel
    /// Store передаёт готовые selectable-строки и typed action ingress folder destination.
    @ObservedObject var screenStore: NewTrackListSelectionFolderScreenStore

    // MARK: - Инициализация

    init(
        folder: LibraryFolder,
        folderViewFactory: NewTrackListSelectionFolderViewFactory,
        selectionViewModel: NewTrackListSelectionViewModel,
        screenStore: NewTrackListSelectionFolderScreenStore
    ) {
        self.folder = folder
        self.folderViewFactory = folderViewFactory
        self.selectionViewModel = selectionViewModel
        self.screenStore = screenStore
    }

    // MARK: - Интерфейс

    var body: some View {
        let state = screenStore.state

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

                if state.hasVisibleTracks {
                    TrackSelectableSectionsView(
                        sections: state.sections,
                        onToggleSelection: { track in
                            selectionViewModel.handle(.toggleTrack(track))
                        },
                        onUnavailableTap: { track in
                            selectionViewModel.handle(.unavailableTrackTapped(track))
                        },
                        onRequestSnapshot: { trackId in
                            screenStore.send(.snapshotRequested(trackId))
                        }
                    )
                }

                if !state.isLoading
                    && !state.hasVisibleTracks
                    && folder.subfolders.isEmpty {
                    Section {
                        Text("No Tracks in This Folder")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if state.isLoading && !state.hasVisibleTracks {
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
                if state.hasVisibleTracks {
                    Button(
                        state.areAllVisibleTracksSelected
                            ? String(localized: "Deselect All")
                            : String(localized: "Select All")
                    ) {
                        if state.areAllVisibleTracksSelected {
                            selectionViewModel.handle(.deselectAll(state.visibleTracks))
                        } else {
                            selectionViewModel.handle(.selectAll(state.visibleTracks))
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            screenStore.send(.screenAppeared)
        }
    }
}
