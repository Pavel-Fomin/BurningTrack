//
//  LibraryFolderStateBuilder.swift
//  TrackList
//
//  Собирает состояние экрана папки фонотеки из доменной модели LibraryFolder.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

struct LibraryFolderStateBuilder {
    // MARK: - Build

    func build(
        folder: LibraryFolder,
        summary: TrackCollectionSummary? = nil
    ) -> LibraryFolderScreenState {
        LibraryFolderScreenState(
            title: folder.name,
            summary: summary,
            folder: folder,
            subfolders: folder.subfolders,
            displayMode: displayMode(for: folder)
        )
    }

    // MARK: - Private

    private func displayMode(for folder: LibraryFolder) -> LibraryFolderScreenState.DisplayMode {
        // Треки фонотеки загружаются отдельно через LibraryTracksViewModel / TrackRegistry.
        // Поэтому на этом уровне нельзя определять пустоту папки через folder.audioFiles.
        .content
    }
}
